#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC1091
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/net.sh"

assert_eq() {
  local expected="$1"; shift
  local actual
  actual="$($@)"
  if [[ "$actual" != "$expected" ]]; then
    echo "Expected '$expected' got '$actual' for $*" >&2
    exit 1
  fi
}

assert_fail() {
  if "$@"; then
    echo "Expected failure for $*" >&2
    exit 1
  fi
}

assert_eq 24 mask2prefix 255.255.255.0
assert_eq 20 mask2prefix 255.255.240.0
assert_eq 8 mask2prefix 255.0.0.0
assert_fail mask2prefix 255.255.255.1

echo "mask2prefix tests passed"

