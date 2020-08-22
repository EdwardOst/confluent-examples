#!/usr/bin/env bash

[ "${QUICKSTART_FLAG:-0}" -gt 0 ] && return 0

quickstart_oldSetOptions=$(set +o)

set -euo pipefail

# shellcheck disable=SC2155
declare -r quickstart_script_path=$(readlink -e "${BASH_SOURCE[0]}")
# shellcheck disable=SC2034
declare -r quickstart_script_dir="${quickstart_script_path%/*}"

# assumes kafka has been started

declare -r kafka_host="localhost"
declare -r kafka_port="9092"
declare -r kafka_connect_protocol="http"
declare -r kafka_connect_host="localhost"
declare -r kafka_connect_port="8083"
declare -r kafka_connect_connector_path="connectors"
declare -r kafka_connect_base_url="${kafka_connect_protocol}://${kafka_connect_host}:${kafka_connect_port}"
declare -r kafka_connect_connectors_endpoint="${kafka_connect_base_url}/${kafka_connect_connector_path}"
declare -r sink_data_dir="${HOME}/connect/sink"
# assumes kafka-topics is on the path
declare -r kafka_topics_command="kafka-topics"
# assumes ksql is on the path
declare -r ksql_command="ksql"

function create_topic() {
  local topic="${1?: empty or not set}"
  local -r partitions="${2:-1}"

  "${kafka_topics_command}" --create --bootstrap-server "${kafka_host}:${kafka_port}" \
  --replication-factor 1 --partitions "${partitions}" --topic "${topic}"
}


function create_datagen_connector() {
  local -r topic="${1?: empty or not set}"
  local -r key_converter="${2:-org.apache.kafka.connect.storage.StringConverter}"
  local -r value_converter="${3:-org.apache.kafka.connect.json.JsonConverter}"

  local request
  request=$(cat <<EOF-REQUEST
{
  "name": "datagen-${topic}",
  "config": {
    "connector.class": "io.confluent.kafka.connect.datagen.DatagenConnector",
    "key.converter": "${key_converter}",
    "value.converter": "${value_converter}",
    "kafka.topic": "${topic}",
    "quickstart": "${topic}",
    "max.interval": 1000,
    "iterations": 10000000,
    "tasks.max": "1",
    "errors.log.enable": true,
    "errors.log.include.messages": true
  }
}
EOF-REQUEST
)
  echo "${request}" >&2
  curl -X POST "${kafka_connect_connectors_endpoint}" \
       -H "Content-Type: application/json" \
       --data-binary "${request}"
#       --trace-ascii "create_datagen_connector-${topic}.log" \

}


function create_file_sink_connector() {
  local -r topic="${1?: empty or not set}"
  local -r key_converter="${2:-org.apache.kafka.connect.storage.StringConverter}"
  local -r value_converter="${3:-org.apache.kafka.connect.json.JsonConverter}"

  local request
  request=$(cat <<EOF-REQUEST
{
  "name": "sink-${topic}",
  "config": {
    "connector.class": "FileStreamSink",
    "key.converter": "${key_converter}",
    "value.converter": "${value_converter}",
    "topics": "${topic}",
    "tasks.max": "1",
    "file": "${sink_data_dir}/${topic}.data"
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


function create_camel_file_sink_connector() {
  local -r topic="${1?: empty or not set}"
  local -r key_converter="${2:-org.apache.kafka.connect.storage.StringConverter}"
  local -r value_converter="${3:-org.apache.kafka.connect.storage.StringConverter}"

  local request
  request=$(cat <<EOF-REQUEST
{
  "name": "camel-file-sink-${topic}",
  "config": {
    "connector.class": "org.apache.camel.kafkaconnector.file.CamelFileSinkConnector",
    "key.converter": "${key_converter}",
    "value.converter": "${value_converter}",
    "topics": "${topic}",
    "tasks.max": "1",
    "camel.sink.path.directoryName": "${sink_data_dir}/",
    "camel.sink.endpoint.fileName": "camel-file-${topic}.data",
    "camel.sink.endpoint.fileExist": "Append"
  }
}
EOF-REQUEST
)
  echo "${request}" >&2
  curl -X POST "${kafka_connect_connectors_endpoint}" \
       -H "Content-Type: application/json" \
       --data-binary "${request}"
#       --trace-ascii "create_camel_file_sink_connector-${topic}.log" \

}


function create_camel_log_sink_connector() {
  local -r topic="${1?: empty or not set}"
  local -r key_converter="${2:-org.apache.kafka.connect.storage.StringConverter}"
  local -r value_converter="${3:-org.apache.kafka.connect.storage.StringConverter}"

  local request
  request=$(cat <<EOF-REQUEST
{
  "name": "camel-log-sink-${topic}",
  "config": {
    "connector.class": "org.apache.camel.kafkaconnector.log.CamelLogSinkConnector",
    "key.converter": "${key_converter}",
    "value.converter": "${value_converter}",
    "topics": "${topic}",
    "tasks.max": "1",
    "camel.sink.path.loggerName": "camel-log-${topic}"
  }
}
EOF-REQUEST
)
  echo "${request}" >&2
  curl -X POST "${kafka_connect_connectors_endpoint}" \
       -H "Content-Type: application/json" \
       --data-binary "${request}"
#       --trace-ascii "create_camel_log_sink_connector-${topic}.log" \

}


function ksql_script() {

  LOG_DIR="./ksql_logs" "${ksql_command}" <<EOF-KSQL

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

#  ksql_script

  create_file_sink_connector "users"
  create_file_sink_connector "pageviews"

  create_camel_file_sink_connector "users"
  create_camel_log_sink_connector "users"

  local confluent_current_dir
  confluent_current_dir="$(confluent local current)"
  echo "view camel_file_sink_connector results in the '${sink_data_dir}' directory"
  echo "view camel_log_sink_connector results in the '${confluent_current_dir}/connect/logs' directory"

}


quickstart_main


eval "${quickstart_oldSetOptions}" 2> /dev/null
