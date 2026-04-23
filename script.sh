#!/usr/bin/env bash
set -euo pipefail

script_version="0.1"
script_dir="$(dirname "$(realpath "$0")")"

# Run all commands by default
script_command=fetch

# Global flags (set by argument parser)
verbose=""
no_build=""
no_push=""
failed_builds=""

# Clean up temp file on exit
trap 'rm -f "${script_dir}/.data.json"' EXIT

# COLORS — initialize all vars so set -u is satisfied
CLEAR="" BOLD=""
BLACK="" RED="" GREEN="" YELLOW="" BLUE="" MAGENTA="" CYAN="" GREY=""
BLACK_I="" RED_I="" GREEN_I="" YELLOW_I="" BLUE_I="" MAGENTA_I="" CYAN_I="" WHITE=""
TERMCOLS=80

if command -v tput >/dev/null 2>&1 && [[ -z ${NO_COLOR:-} ]]; then
  ncolors=$(tput colors 2>/dev/null || echo 0)
  TERMCOLS=$(tput cols 2>/dev/null || echo 80)
  CLEAR="$(tput sgr0)"
  BOLD="$(tput bold)"

  if [[ $ncolors -ge 8 ]]; then
    BLACK="$(tput setaf 0)"
    RED="$(tput setaf 1)"
    GREEN="$(tput setaf 2)"
    YELLOW="$(tput setaf 3)"
    BLUE="$(tput setaf 4)"
    MAGENTA="$(tput setaf 5)"
    CYAN="$(tput setaf 6)"
    GREY="$(tput setaf 7)"
  fi

  if [[ $ncolors -gt 8 ]]; then
    BLACK_I="$(tput setaf 8)"
    RED_I="$(tput setaf 9)"
    GREEN_I="$(tput setaf 10)"
    YELLOW_I="$(tput setaf 11)"
    BLUE_I="$(tput setaf 12)"
    MAGENTA_I="$(tput setaf 13)"
    CYAN_I="$(tput setaf 14)"
    WHITE="$(tput setaf 15)"
  else
    BLACK_I=$BLACK
    RED_I=$RED
    GREEN_I=$GREEN
    YELLOW_I=$YELLOW
    BLUE_I=$BLUE
    MAGENTA_I=$MAGENTA
    CYAN_I=$CYAN
    WHITE=$GREY
  fi
fi

function error_msg() {
  echo -e "${RED}${BOLD}[X] ${1}${CLEAR}"
  [[ -n ${2:-} ]] && exit "$2"
}

function warning_msg() {
  echo -e "${YELLOW}${BOLD}[!] ${*}${CLEAR}"
}

function success_msg() {
  echo -e "${GREEN}${BOLD}[✓] ${*}${CLEAR}"
}

function info_msg() {
  [[ -n "$verbose" ]] && echo -e "${CYAN}[i] ${*}${CLEAR}"
}

# Display Help
help() {
  echo -e "${CYAN}${BOLD}Docker GOST multi script v${script_version}${CLEAR}"
  echo
  echo -e "${YELLOW}ABOUT${CLEAR}"
  echo -e "Script for managing Docker GOST CI/Build process"
  echo
  echo -e "${YELLOW}SYNTAX${CLEAR}"
  echo -e "./script.sh [build|fetch|all] [-h|v|n] [-p] [ARG]"
  echo
  echo -e "${YELLOW}EXAMPLE${CLEAR}"
  echo -e "Build all docker images without pushing with verbose output"
  echo -e "./script.sh build --no-push -v"
  echo
  echo -e "${YELLOW}COMMANDS${CLEAR}"
  echo -e "build               Build docker images."
  echo -e "fetch               Fetch latest versions."
  echo -e "fetch-openssl       Fetch latest openssl version and print to console."
  echo -e "fetch-nginx         Fetch latest nginx version and print to console."
  echo
  echo -e "${YELLOW}OPTIONS${CLEAR}"
  echo -e "-h --help           Print this Help."
  echo -e "-v --verbose        Verbose output"
  echo -e "-b --no-build       Don't trigger build if new version is available"
  echo -e "-n --no-push        Don't push images, only build"
  echo
  echo -e "${GREEN}${TERMCOLS} colors${CLEAR}"
}

# ARG parser
if [[ $# -eq 0 ]]; then
  help
else
  while [[ $# -gt 0 ]]; do
    case $1 in
    build)
      script_command=build
      shift
      ;;
    fetch)
      script_command=fetch
      shift
      ;;
    fetch-openssl)
      script_command=fetch-openssl
      shift
      ;;
    fetch-nginx)
      script_command=fetch-nginx
      shift
      ;;
    --help | -h)
      help
      exit 0
      ;;
    --verbose | -v)
      verbose=true
      shift
      ;;
    --no-build | -b)
      no_build=true
      shift
      ;;
    --no-push | -n)
      no_push=true
      shift
      ;;
    -*)
      error_msg "Unknown option $1" 22
      ;;
    *)
      error_msg "Unknown argument $1"
      echo 'If you want to pass an argument with spaces, quote it: "my argument"'
      exit 1
      ;;
    esac
  done
fi

function build_images {
  command -v jq >/dev/null || error_msg "Please install jq JSON parser package" 1

  local OPENSSL_VERSION NGINX_VERSION docker_repo
  OPENSSL_VERSION=$(jq -r '.versions.openssl' data.json)
  NGINX_VERSION=$(jq -r '.versions.nginx' data.json)

  info_msg "Preparing substituted build config"
  cp "${script_dir}/data.json" "${script_dir}/.data.json"
  sed -i "s/%%openssl%%/${OPENSSL_VERSION}/g" "${script_dir}/.data.json"
  sed -i "s/%%nginx%%/${NGINX_VERSION}/g" "${script_dir}/.data.json"

  info_msg ".data.json diff:\n $(diff --color data.json .data.json || true)"

  docker_repo=$(jq -r '.docker.repository' .data.json)

  local images=()
  mapfile -t images < <(jq -r '.images[]|.name' .data.json)

  for image in "${images[@]}"; do
    info_msg "Building $image for $docker_repo"

    local tags=() dockerfile tag_args=()
    mapfile -t tags < <(jq -r ".images[] | select(.name == \"${image}\") | .tags[]" .data.json)
    dockerfile=$(jq -r ".images[] | select(.name == \"${image}\") | .dockerfile" .data.json)

    for tag in "${tags[@]}"; do
      tag_args+=(--tag "${docker_repo}:${tag}")
    done

    local push_args=()
    if [[ -z "${no_push}" ]]; then
      push_args=(--push)
    else
      warning_msg "Not pushing $image (--no-push flag was passed)"
    fi

    docker buildx build --progress plain \
      "${push_args[@]+"${push_args[@]}"}" \
      "${tag_args[@]}" \
      --build-arg="OPENSSL_VERSION=openssl-${OPENSSL_VERSION}" \
      --build-arg="NGINX_VERSION=${NGINX_VERSION}" \
      -f "${dockerfile}" \
      . &&
      success_msg "Image ${image} built${push_args:+ and pushed}" ||
      failed_builds="${failed_builds} ${image}"
  done

  success_msg "Build procedure finished"
}

function fetch_version_openssl {
  curl -s "https://api.github.com/repos/openssl/openssl/tags" |
    jq -r '.[]|.name' |
    grep -P -m 1 'openssl-3\.[0-9]+\.[0-9]+$' |
    cut -d "-" -f2
}

function fetch_version_nginx {
  curl -s "https://api.github.com/repos/nginx/nginx/tags" |
    jq -r '.[]|.name' |
    grep -P -m 1 'release-[0-9]+\.[0-9]+\.[0-9]+$' |
    cut -d "-" -f2
}

function fetch_versions {
  command -v jq >/dev/null || error_msg "Please install jq JSON parser package" 1
  command -v curl >/dev/null || error_msg "Please install curl" 1

  info_msg "Fetching versions"

  local openssl_version nginx_version version_trigger=""

  openssl_version=$(fetch_version_openssl)
  nginx_version=$(fetch_version_nginx)

  info_msg "Fetched latest versions:"
  info_msg "OpenSSL $openssl_version"
  info_msg "Nginx $nginx_version"

  if [[ "$nginx_version" != "$(jq -r '.versions.nginx' data.json)" ]]; then
    warning_msg "New Nginx version: $nginx_version"
    version_trigger=1
  else
    success_msg "Nginx version unchanged"
  fi

  if [[ "$openssl_version" != "$(jq -r '.versions.openssl' data.json)" ]]; then
    warning_msg "New OpenSSL version: $openssl_version"
    version_trigger=1
  else
    success_msg "OpenSSL version unchanged"
  fi

  [[ -n "$version_trigger" ]] && warning_msg "New version detected"

  # Save both version updates atomically
  local tmp
  tmp=$(mktemp)
  jq --arg openssl "$openssl_version" --arg nginx "$nginx_version" \
    '.versions.openssl=$openssl | .versions.nginx=$nginx' \
    data.json >"$tmp" && mv "$tmp" data.json

  success_msg "Versions saved to data.json"

  if [[ -z "$no_build" && -n "$version_trigger" ]]; then
    warning_msg "Build triggered"
    build_images
  elif [[ -n "$version_trigger" ]]; then
    warning_msg "Version change detected but build not triggered"
  else
    success_msg "Build not triggered"
  fi
}

# Run Command parser
case $script_command in
build)
  build_images
  ;;
fetch)
  fetch_versions
  ;;
fetch-openssl)
  fetch_version_openssl
  ;;
fetch-nginx)
  fetch_version_nginx
  ;;
*)
  error_msg "Unknown command '$script_command'"
  error_msg "Please see list of commands in help"
  exit 1
  ;;
esac

if [[ -n "$failed_builds" ]]; then
  error_msg "Some builds were not successful:${YELLOW}${failed_builds}" 1
fi

exit 0
