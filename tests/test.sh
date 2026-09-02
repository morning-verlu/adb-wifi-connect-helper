#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT="$ROOT_DIR/adb-wifi-connect.command"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local output="$1"
  local expected="$2"

  printf '%s\n' "$output" | grep -Fq -- "$expected" ||
    fail "expected output to contain: $expected"
}

test_syntax() {
  bash -n "$SCRIPT"
}

test_help() {
  local output

  output=$("$SCRIPT" --help)
  assert_contains "$output" 'ADB Wi-Fi connect helper'
  assert_contains "$output" '--seconds N'
}

test_invalid_seconds() {
  local value="$1"
  local output

  if output=$("$SCRIPT" --seconds "$value" --skip-pair --yes 2>&1); then
    fail "--seconds $value unexpectedly succeeded"
  fi

  assert_contains "$output" '--seconds must be a positive integer.'
}

test_syntax
test_help
test_invalid_seconds 0
test_invalid_seconds -1
test_invalid_seconds abc

printf 'All tests passed.\n'
