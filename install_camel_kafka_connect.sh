#!/usr/bin/env bash

declare CAMEL_KAFKA_CONNECT_LOCAL_HOME="${HOME}/camel-kafka-connect"
declare CAMEL_KAFKA_CONNECT_HOST="repo.maven.apache.org"
declare CAMEL_KAFKA_CONNECT_VERSION="0.4.0"

function install_camel_kafka_connector() {

  local -r camel_component="${1?: misisng camel_component argument}"
  local -r camel_kafka_connector="camel-${camel_component}-kafka-connector"
  local -r camel_kafka_connect_file="${camel_kafka_connector}-${CAMEL_KAFKA_CONNECT_VERSION}-package.zip"
  local -r camel_kafka_connect_path="maven2/org/apache/camel/kafkaconnector/${camel_kafka_connector}/${CAMEL_KAFKA_CONNECT_VERSION}"
  local -r camel_kafka_connect_zip_path="${CAMEL_KAFKA_CONNECT_LOCAL_HOME}/${camel_kafka_connect_file}"
  local -r camel_kafka_connect_url="https://${CAMEL_KAFKA_CONNECT_HOST}/${camel_kafka_connect_path}/${camel_kafka_connect_file}"

  echo "camel_kafka_connect_zip_path=${camel_kafka_connect_zip_path}" >&2
  curl -s -L -R -z "${camel_kafka_connect_zip_path}" -o "${camel_kafka_connect_zip_path}" "${camel_kafka_connect_url}"

  unzip -q -d "${CAMEL_KAFKA_CONNECT_LOCAL_HOME}" "${camel_kafka_connect_zip_path}"
  rm "${camel_kafka_connect_zip_path}"

  ln -sf  "${CAMEL_KAFKA_CONNECT_LOCAL_HOME}/${camel_kafka_connector}" "${CONFLUENT_HOME}/share/java/"
}


function install_camel_kafka_connect_main() {
  mkdir -p "${CAMEL_KAFKA_CONNECT_LOCAL_HOME}"

  install_camel_kafka_connector "file"
  install_camel_kafka_connector "log"
}



# wrap function invocation with bash shell options in subshell
function test_install_camel_kafka_connect_main() (

  set -euo pipefail

  install_camel_kafka_connect_main
)
