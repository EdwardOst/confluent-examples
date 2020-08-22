#!/usr/bin/env bash

[ "${INSTALL_CONFLUENT_FLAG:-0}" -gt 0 ] && return 0

# save shell option settings
install_confluent_oldSetOptions=$(set +o)

set -euo pipefail

declare -r CONFLUENT_HOME_PARENT_DIR="${HOME}"
declare -r CONFLUENT_FULL_VERSION=5.5.1-2.12
#declare -r CONFLUENT_CLI_VERSION="latest"
declare -r CONFLUENT_CLI_VERSION="v1.7.0"


function install_confluent() {

  local -r confluent_version="${1:-${CONFLUENT_FULL_VERSION}}"
# shellcheck disable=SC2034
  local -r confluent_scala_version="${confluent_version##*-}"
  local -r confluent_platform_version="${confluent_version%-*}"
  local -r confluent_platform_minor_version="${confluent_platform_version%.*}"
  local -r confluent_download_url="http://packages.confluent.io/archive/${confluent_platform_minor_version}/confluent-${confluent_version}.zip"

  # download Confluent
  curl -O "${confluent_download_url}"
  unzip -f "confluent-${confluent_version}.zip"

  # set Confluent environment variables in /etc/profile.d/confluent.sh
  echo "export CONFLUENT_HOME=${PWD}/confluent-${confluent_platform_version}" | sudo tee "/etc/profile.d/confluent.sh"
  echo "export PATH=\"\${CONFLUENT_HOME}/bin:\${PATH}\"" | sudo tee -a "/etc/profile.d/confluent.sh"

}


function install_confluent_cli() {

  local confluent_cli_version="${1:-latest}"

  local confluent_cli_dir
  confluent_cli_dir=$(mktemp -d confluent_cli.XXX)

  local confluent_cli
  confluent_cli=$(curl -L --http1.1 https://cnfl.io/cli | sh -s -- -b "${confluent_cli_dir}" -d "${confluent_cli_version}" 2>&1)

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
  # shellcheck disable=SC2027
  confluent_env="${confluent_env%""${confluent_env##*[![:space:]]}""}"

  cp -f "${CONFLUENT_HOME}/libexec/cli/${confluent_env}/confluent" "${CONFLUENT_HOME}/libexec/cli/${confluent_env}/confluent.bak"
  cp -f "${confluent_cli_dir}/confluent" "${CONFLUENT_HOME}/libexec/cli/${confluent_env}"

  rmdir "${confluent_cli_dir}"

}


function install_datagen() {
  confluent-hub install --no-prompt confluentinc/kafka-connect-datagen:latest
}


function install_confluent_main() {

  mkdir -p "${CONFLUENT_HOME_PARENT_DIR}"
  cd "${CONFLUENT_HOME_PARENT_DIR}"

  install_confluent "${CONFLUENT_FULL_VERSION}"

  # shellcheck disable=SC1091
  source "/etc/profile.d/confluent.sh"

  install_datagen

  install_confluent_cli "${CONFLUENT_CLI_VERSION}"

  # confluent CLI version
  confluent --version

  # confluent version
  confluent local version
}


install_confluent_main


# restore shell option settings
eval "${install_confluent_oldSetOptions}" 2> /dev/null
