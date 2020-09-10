#!/usr/bin/env bash

declare CONFLUENT_HOME_PARENT_DIR="${HOME}"
declare CONFLUENT_FULL_VERSION=5.5.1-2.12
declare CONFLUENT_CLI_VERSION="v1.7.0"


function install_confluent() {

  local -r confluent_version="${1:-${CONFLUENT_FULL_VERSION}}"
# shellcheck disable=SC2034
  local -r confluent_scala_version="${confluent_version##*-}"
  local -r confluent_platform_version="${confluent_version%-*}"
  local -r confluent_platform_minor_version="${confluent_platform_version%.*}"
  local -r confluent_zip_path="${CONFLUENT_HOME_PARENT_DIR}/confluent-${confluent_version}.zip"
  local -r confluent_download_url="http://packages.confluent.io/archive/${confluent_platform_minor_version}/confluent-${confluent_version}.zip"

  # download Confluent
  curl -s -L -R -z "${confluent_zip_path}" -o "${confluent_zip_path}" "${confluent_download_url}"

  unzip -q -d "${CONFLUENT_HOME_PARENT_DIR}" "${confluent_zip_path}"

  # set Confluent environment variables in /etc/profile.d/confluent.sh
  echo "export CONFLUENT_HOME=${CONFLUENT_HOME_PARENT_DIR}/confluent-${confluent_platform_version}" | sudo tee "/etc/profile.d/confluent.sh" > /dev/null
  echo "export PATH=\"\${CONFLUENT_HOME}/bin:\${PATH}\"" | sudo tee -a "/etc/profile.d/confluent.sh" > /dev/null

}


function install_confluent_cli() {

  local confluent_cli_version="${1:-latest}"

  local confluent_cli_dir
  confluent_cli_dir=$(mktemp -p "${CONFLUENT_HOME_PARENT_DIR}" -d confluent_cli.XXX)
  echo "confluent_cli_dir=${confluent_cli_dir}" >&2

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

  echo "backing up confluent cli from '${CONFLUENT_HOME}/libexec/cli/${confluent_env}/confluent' to '${CONFLUENT_HOME}/libexec/cli/${confluent_env}/confluent.bak'" >&2
  cp -f "${CONFLUENT_HOME}/libexec/cli/${confluent_env}/confluent" "${CONFLUENT_HOME}/libexec/cli/${confluent_env}/confluent.bak"
  echo "copying platform specific confluent cli to confluent directory" >&2
  cp -f "${confluent_cli_dir}/confluent" "${CONFLUENT_HOME}/libexec/cli/${confluent_env}"
  echo "confluent CLI copied to ${CONFLUENT_HOME}/libexec/cli/${confluent_env}" >&2

  rm -rf "${confluent_cli_dir}"

}


function install_datagen() {
  confluent-hub install --no-prompt confluentinc/kafka-connect-datagen:latest
}


function install_confluent_main() {

  mkdir -p "${CONFLUENT_HOME_PARENT_DIR}"

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


# wrap function invocation with bash shell options in subshell
function test_install_confluent_main() (
  set -euo pipefail

  install_confluent_main
)
