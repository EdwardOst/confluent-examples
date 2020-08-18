#!/usr/bin/env bash

set -euo pipefail

# assumes kafka has been started
# assumes kafka-topics is on the path

declare kafka_host="localhost"
declare kafka_port="9092"
declare kafka_connect_protocol="http"
declare kafka_connect_host="localhost"
declare kafka_connect_port="8083"
declare kafka_connect_connector_path="connectors"
declare kafka_connect_base_url="${kafka_connect_protocol}://${kafka_connect_host}:${kafka_connect_port}"
declare kafka_connect_connectors_endpoint="${kafka_connect_base_url}/${kafka_connect_connector_path}"


function create_topic() {
  local topic="${1?: empty or not set}"
  local partitions="${2:-1}"

  kafka-topics --create --bootstrap-server "${kafka_host}:${kafka_port}" \
  --replication-factor 1 --partitions "${partitions}" --topic "${topic}"
}


function create_datagen_connector() {
  local topic="${1?: empty or not set}"

  local request=$(cat <<EOF-REQUEST
{
  "name": "datagen-${topic}",
  "config": {
    "connector.class": "io.confluent.kafka.connect.datagen.DatagenConnector",
    "key.converter": "org.apache.kafka.connect.storage.StringConverter",
    "kafka.topic": "${topic}",
    "quickstart": "${topic}",
    "max.interval": 1000,
    "iterations": 10000000,
    "tasks.max": "1"
  }
}
EOF-REQUEST
)
  echo "${request}" >&2
  curl -X POST "${kafka_connect_connectors_endpoint}" \
       -H "Content-Type: application/json" \
       --trace-ascii "create_datagen_connector-${topic}.log" \
       --data-binary "${request}"

}


function ksql() {

LOG_DIR=./ksql_logs ksql <<EOF-KSQL

CREATE STREAM pageviews (viewtime BIGINT, userid VARCHAR, pageid VARCHAR) \
WITH (KAFKA_TOPIC='pageviews', VALUE_FORMAT='AVRO');
show streams;

CREATE TABLE users (registertime BIGINT, gender VARCHAR, regionid VARCHAR,  \
userid VARCHAR) \
WITH (KAFKA_TOPIC='users', VALUE_FORMAT='AVRO', KEY = 'userid');
show tables;

SET 'auto.offset.reset'='earliest';

# non-persistent QUERY returns data from a pageviews STREAM with the results limited to three rows
SELECT pageid FROM pageviews EMIT CHANGES LIMIT 3;

# persistent query that enriches the pageviews STREAM with the users TABLE and then filters for female users.
CREATE STREAM pageviews_female AS SELECT users.userid AS userid, pageid, \
regionid, gender FROM pageviews LEFT JOIN users ON pageviews.userid = users.userid \
WHERE gender = 'FEMALE';

# persistent OUTPUT STREAM QUERY to topic pageviews_enriched_r8_r9 where a condition (regionid) is met using LIKE.
CREATE STREAM pageviews_female_like_89 WITH (kafka_topic='pageviews_enriched_r8_r9', \
value_format='AVRO') AS SELECT * FROM pageviews_female WHERE regionid LIKE '%_8' OR regionid LIKE '%_9';

# persistent OUTPUT TABLE QUERY to pageviews_regions topic that counts pageviews for each region and gender combination
# in a tumbling window of 30 seconds when the count is greater than 1.
# Because the procedure is grouping and counting, the result is now a table, rather than a stream.
CREATE TABLE pageviews_regions AS SELECT gender, regionid , \
COUNT(*) AS numusers FROM pageviews_female WINDOW TUMBLING (size 30 second) \
GROUP BY gender, regionid HAVING COUNT(*) > 1;

DESCRIBE EXTENDED pageviews_female_like_89;

SHOW QUERIES;

# need to identify correct query name
#EXPLAIN CTAS_PAGEVIEWS_REGIONS_5;

EOF-KSQL
}


function quickstart_main() {
  create_topic users
  create_topic pageviews
  create_datagen_connector "users"
  create_datagen_connector "pageviews"
}


if [[ ${TEST:+x} != x ]]; then
  quickstart_main "$@"
fi
