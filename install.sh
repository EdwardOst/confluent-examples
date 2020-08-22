#!/usr/bin/env bash

declare -r CONFLUENT_FULL_VERSION=5.5.1-2.12
declare -r CONFLUENT_SCALA_VERSION="${CONFLUENT_FULL_VERSION##*-}"
declare -r CONFLUENT_PLATFORM_VERSION="${CONFLUENT_FULL_VERSION%-*}"
declare -r CONFLUENT_PLATFORM_MINOR_VERSION="${CONFLUENT_PLATFORM_VERSION%.*}"
declare -r CONFLUENT_DOWNLOAD_URL="http://packages.confluent.io/archive/${CONFLUENT_PLATFORM_MINOR_VERSION}/confluent-${CONFLUENT_FULL_VERSION}.zip"

function install_confluent() {

  # download Confluent
  curl -O "${CONFLUENT_DOWNLOAD_URL}"
  unzip "confluent-${CONFLUENT_FULL_VERSION}.zip"

  # set Confluent environment variables in /etc/profile.d/confluent.sh
  echo "export CONFLUENT_HOME=${PWD}/confluent-${CONFLUENT_PLATFORM_VERSION}" | sudo tee "/etc/profile.d/confluent.sh"
  echo "export PATH=\"\${CONFLUENT_HOME}/bin:\${PATH}\"" | sudo tee -a "/etc/profile.d/confluent.sh"

}


function install_confluent_cli() {

  local confluent_cli_dir
  confluent_cli_dir=$(mktemp -d confluent_cli.XXX)

  local confluent_cli
  confluent_cli=$(curl -L --http1.1 https://cnfl.io/cli | sh -s -- -b "${confluent_cli_dir}" -d v1.7.0 2>&1)

  declare confluent_env
  # remove prior lines
  confluent_env="${confluent_cli##*confluentinc/cli info found version: }"
  # remove subsequent lines
  confluent_env="${confluent_env%%confluentinc*}"
  # remove version
  confluent_env="${confluent_env#*/}"
  # replace slash with underscore
  confluent_env="${confluent_env/\//_}"
  # trim trailing whitespace
  confluent_env="${confluent_env%""${confluent_env##*[![:space:]]}""}"

  mv -f "${confluent_cli_dir}/confluent" "${CONFLUENT_HOME}/libexec/cli/${confluent_env}"

  rmdir "${confluent_cli_dir}"

}


install_confluent

source "/etc/profile.d/confluent.sh"

install_confluent_cli

# confluent CLI version
confluent --version

# confluent version
confluent local version

