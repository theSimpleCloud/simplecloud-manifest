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

# Detect platform
detect_platform() {
    OS=$(uname -s)
    ARCH=$(uname -m)

    case $OS in
        "Darwin")
            case $ARCH in
                "x86_64") PLATFORM="cli-mac-intel" ;;
                "arm64") PLATFORM="cli-mac-arm" ;;
                *) abort "Unsupported architecture: $ARCH" ;;
            esac
            ;;
        "Linux")
            case $ARCH in
                "x86_64") PLATFORM="cli-linux-amd64" ;;
                "aarch64") PLATFORM="cli-linux-arm" ;;
                "armhf"|"armv6l"|"armv7l") PLATFORM="cli-linux-arm" ;;
                *) abort "Unsupported architecture: $ARCH" ;;
            esac
            ;;
        *)
            abort "Unsupported operating system: $OS"
            ;;
    esac
    ohai "Detected platform: $PLATFORM"
}

# Set installation paths
SIMPLECLOUD_PREFIX="/usr/local"
SIMPLECLOUD_REPOSITORY="${SIMPLECLOUD_PREFIX}/bin"
GITHUB_REPO="theSimpleCloud/simplecloud-manifest"

# Find the correct path for chown
CHOWN_PATH=$(which chown)
if [ -z "$CHOWN_PATH" ]; then
    abort "Could not find chown command"
fi

# Detect platform
detect_platform

# Get the latest release URL
get_latest_release() {
  curl --silent "https://api.github.com/repos/$1/releases/latest" |
  grep '"browser_download_url":' |
  grep "$PLATFORM" |
  sed -E 's/.*"([^"]+)".*/\1/'
}

DOWNLOAD_URL=$(get_latest_release $GITHUB_REPO)

if [ -z "$DOWNLOAD_URL" ]; then
    abort "Failed to get the download URL for the latest release."
fi

ohai "This script will install:"
echo "${SIMPLECLOUD_REPOSITORY}/sc"
echo "${SIMPLECLOUD_REPOSITORY}/simplecloud"

# Create necessary directories
execute_sudo "/bin/mkdir" "-p" "${SIMPLECLOUD_REPOSITORY}"
execute_sudo "$CHOWN_PATH" "-R" "$(id -un):$(id -gn)" "${SIMPLECLOUD_REPOSITORY}"

ohai "Downloading and installing SimpleCloud..."
(
  cd "${SIMPLECLOUD_REPOSITORY}" >/dev/null || exit 1

  # Download the correct binary
  execute "curl" "-fsSL" "-o" "${PLATFORM}" "${DOWNLOAD_URL}"

  if [[ ! -f "${PLATFORM}" ]]
  then
    abort "Failed to download SimpleCloud."
  fi

  execute_sudo "/bin/chmod" "+x" "${PLATFORM}"
  execute_sudo "/bin/ln" "-sf" "${PLATFORM}" "sc"
  execute_sudo "/bin/ln" "-sf" "${PLATFORM}" "simplecloud"
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

echo "For more information, see: ${tty_underline}https://simplecloud.app${tty_reset}"
