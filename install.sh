#!/bin/bash

set -u

# String formatters
if [[ -t 1 ]]
then
  tty_escape() { printf "\033[%sm" "$1"; }
else
  tty_escape() { :; }
fi
tty_mkbold() { tty_escape "1;$1"; }
tty_underline="$(tty_escape "4;39")"
tty_blue="$(tty_mkbold 34)"
tty_red="$(tty_mkbold 31)"
tty_bold="$(tty_mkbold 39)"
tty_reset="$(tty_escape 0)"

# Output helpers
ohai() {
  printf "${tty_blue}==>${tty_bold} %s${tty_reset}\n" "$*"
}

warn() {
  printf "${tty_red}Warning${tty_reset}: %s\n" "$1"
}

error() {
  printf "${tty_red}Error${tty_reset}: %s\n" "$1"
}

abort() {
  printf "%s\n" "$@" >&2
  exit 1
}

execute() {
  if ! "$@"
  then
    abort "Failed during: $*"
  fi
}

execute_sudo() {
  local -a args=("$@")
  ohai "/usr/bin/sudo" "${args[@]}"
  execute "/usr/bin/sudo" "${args[@]}"
}

# Function to handle API errors
handle_api_error() {
  local http_code=$1
  local error_message=$2

  case $http_code in
    400)
      error "Bad request: $error_message"
      ;;
    404)
      error "Not found: $error_message"
      ;;
    500)
      error "Server error: $error_message"
      ;;
    *)
      error "HTTP $http_code: $error_message"
      ;;
  esac
  exit 1
}

# Detect platform and set download parameters
detect_platform() {
    OS=$(uname -s)
    ARCH=$(uname -m)

    case $OS in
        "Darwin")
            PLATFORM="darwin"
            case $ARCH in
                "x86_64") ARCH_PARAM="amd64" ;;
                "arm64") ARCH_PARAM="arm64" ;;
                *) abort "Unsupported architecture: $ARCH" ;;
            esac
            ;;
        "Linux")
            PLATFORM="linux"
            case $ARCH in
                "x86_64") ARCH_PARAM="amd64" ;;
                "aarch64") ARCH_PARAM="arm64" ;;
                "armhf"|"armv6l"|"armv7l") ARCH_PARAM="arm" ;;
                *) abort "Unsupported architecture: $ARCH" ;;
            esac
            ;;
        *)
            abort "Unsupported operating system: $OS"
            ;;
    esac
    ohai "Detected platform: $PLATFORM, architecture: $ARCH_PARAM"
}

# Set installation paths
SIMPLECLOUD_PREFIX="/usr/local"
SIMPLECLOUD_REPOSITORY="${SIMPLECLOUD_PREFIX}/bin"
REGISTRY_URL="https://registry.simplecloud.app"
APP_SLUG="cli"

# Find the correct path for chown
CHOWN_PATH=$(which chown)
if [ -z "$CHOWN_PATH" ]; then
    abort "Could not find chown command"
fi

# Detect platform
detect_platform

# Construct download URL with platform and architecture parameters
DOWNLOAD_URL="${REGISTRY_URL}/v1/applications/${APP_SLUG}/download/latest?platform=${PLATFORM}&arch=${ARCH_PARAM}"

ohai "This script will install:"
echo "${SIMPLECLOUD_REPOSITORY}/sc"
echo "${SIMPLECLOUD_REPOSITORY}/simplecloud"

# Create necessary directories
execute_sudo "/bin/mkdir" "-p" "${SIMPLECLOUD_REPOSITORY}"
execute_sudo "$CHOWN_PATH" "-R" "$(id -un):$(id -gn)" "${SIMPLECLOUD_REPOSITORY}"

ohai "Downloading and installing SimpleCloud..."
(
  cd "${SIMPLECLOUD_REPOSITORY}" >/dev/null || exit 1

  # Download the binary with error handling
  HTTP_RESPONSE=$(curl -s -w "%{http_code}" -L \
    -o simplecloud-binary.tmp \
    "${DOWNLOAD_URL}")

  HTTP_STATUS="${HTTP_RESPONSE}"

  if [ $HTTP_STATUS -eq 200 ]; then
    mv simplecloud-binary.tmp simplecloud-binary
  else
    ERROR_MESSAGE=$(cat simplecloud-binary.tmp)
    rm -f simplecloud-binary.tmp
    handle_api_error $HTTP_STATUS "$ERROR_MESSAGE"
  fi

  if [[ ! -f "simplecloud-binary" ]]
  then
    abort "Failed to download SimpleCloud."
  fi

  execute_sudo "/bin/chmod" "+x" "simplecloud-binary"
  execute_sudo "/bin/mv" "simplecloud-binary" "simplecloud"
  execute_sudo "/bin/ln" "-sf" "simplecloud" "sc"
) || exit 1

ohai "Installation successful!"
echo

echo "SimpleCloud was installed to: ${SIMPLECLOUD_REPOSITORY}"
echo "You can now use 'sc' or 'simplecloud' commands."

if [[ ":${PATH}:" != *":${SIMPLECLOUD_REPOSITORY}:"* ]]
then
  warn "${SIMPLECLOUD_REPOSITORY} is not in your PATH.
  Instructions on how to configure your shell for SimpleCloud
  can be found in the 'Next steps' section below."

  cat <<EOS

Next steps:
- Run this command in your terminal to add SimpleCloud to your ${tty_bold}PATH${tty_reset}:
    echo 'export PATH="${SIMPLECLOUD_REPOSITORY}:$PATH"' >> ~/.bash_profile
- Close and reopen your terminal to start using SimpleCloud.
EOS
fi

echo "For more information, see: ${tty_underline}https://docs.simplecloud.app${tty_reset}"
