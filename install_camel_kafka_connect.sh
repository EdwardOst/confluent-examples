#!/usr/bin/env bash

[ "${INSTALL_CAMEL_KAFKA_CONNECT_FLAG:-0}" -gt 0 ] && return 0

# save shell option settings
install_camel_kafka_connect_oldSetOptions=$(set +o)

set -euo pipefail

declare -r CAMEL_KAFKA_CONNECT_LOCAL_HOME="${HOME}/camel-kafka-connect"
declare -r CAMEL_KAFKA_CONNECT_HOST="repo.maven.apache.org"
declare -r CAMEL_KAFKA_CONNECT_VERSION="0.4.0"

function install_camel_kafka_connector() {

  local -r camel_component="${1?: misisng camel_component argument}"
  local -r camel_kafka_connector="camel-${camel_component}-kafka-connector"
  local -r camel_kafka_connect_file="${camel_kafka_connector}-${CAMEL_KAFKA_CONNECT_VERSION}-package.zip"
  local -r camel_kafka_connect_path="maven2/org/apache/camel/kafkaconnector/${camel_kafka_connector}/${CAMEL_KAFKA_CONNECT_VERSION}"
  local -r camel_kafka_connect_url="https://${CAMEL_KAFKA_CONNECT_HOST}/${camel_kafka_connect_path}/${camel_kafka_connect_file}"

  curl -O "${camel_kafka_connect_url}"

  unzip -f "${camel_kafka_connect_file}"
  rm "${camel_kafka_connect_file}"

  ln -sf  "${CAMEL_KAFKA_CONNECT_LOCAL_HOME}/${camel_kafka_connector}" "${CONFLUENT_HOME}/share/java/"
}


function install_kafka_connect_main() {
  mkdir -p "${CAMEL_KAFKA_CONNECT_LOCAL_HOME}"
  cd "${CAMEL_KAFKA_CONNECT_LOCAL_HOME}"

  install_camel_kafka_connector "file"
  install_camel_kafka_connector "log"
}


install_kafka_connect_main

# restore shell option settings
eval "${install_camel_kafka_connect_oldSetOptions}" 2> /dev/null
