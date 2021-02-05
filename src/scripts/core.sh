#!/bin/bash
type zbash_commons
if [ "$?" -eq 0 ]; then
  # in case zbash_commons is installed.
  source zbash_commons
else
  : "${LOG_DISPLAY_DATE_TIME="%Y-%m-%dT%H:%M:%S%z"}"
  : "${LOG_LEVEL:="INFO"}"
  : "${LOG_DISPLAY_PREFIX_PAD="5"}"

  function log_core() {
    local prefix="$1"
    shift
    if [ -n "$prefix" ]; then
      prefix="[$prefix]"
    fi
    if [ -n "$LOG_DISPLAY_DATE_TIME" ]; then
      prefix="[$(date +"$LOG_DISPLAY_DATE_TIME")]$prefix"
    fi
    echo "${prefix}" "$@"
  }

  function log_level_name_to_number() {
    case "$1" in
    0 | TRACE)
      return 0
      ;;
    1 | DEBUG)
      return 1
      ;;
    2 | INFO)
      return 2
      ;;
    3 | WARN | WARNING)
      return 3
      ;;
    4 | ERROR)
      return 4
      ;;
    5 | CRITICAL)
      return 5
      ;;
    esac

    return 2
  }

  function log_with_level() {
    local level="$1"
    shift

    log_level_name_to_number "$LOG_LEVEL"
    local display_log_level="$?"

    log_level_name_to_number "$level"
    level=$?

    local color="$gray"
    local prefix="UNKNOWN"
    case "$level" in
    0)
      prefix="TRACE"
      color="$dark_gray"
      ;;
    1)
      prefix="DEBUG"
      color="$light_blue"
      ;;
    2)
      prefix="INFO"
      color="$green"
      ;;
    3)
      prefix="WARN"
      color="$yellow"
      ;;
    4)
      prefix="ERROR"
      color="$red"
      ;;
    5)
      prefix="CRITICAL"
      color="$magenta"
      ;;
    esac

    if [ $display_log_level -gt $level ]; then
      return 0
    fi

    prefix="${color}$(printf "%${LOG_DISPLAY_PREFIX_PAD}s" "$prefix")${end_color}"
    log_core "$prefix" "$@"
  }

  # ------------------

  function assert() {
    : "
Assert an code, if > 0, then log:error, returns the code.
USAGE: assert [code|\$?] [message...] -> code
"
    local code="$1"
    shift
    : "${code:=0}"
    if [ "$code" -ne 0 ]; then
      log:error "$@"
      return $code
    fi
  }

  # deprecated
  function assert_warning() {
    local err="$1"
    shift
    : "${err:=0}"
    if [ "$err" -ne 0 ]; then
      log:warn "$@"
      return $err
    fi
  }

  function warn() {
    : "
Assert an code, if > 0, then log:warn the message, returns the code.
USAGE: assert [code|\$?] [message...] -> code
"
    assert_warning "$@"
    return $?
  }

  # ------------------

  export LINE_SEPARATOR='------------------------------------'

  function log:debug() {
    : "
Log a message to level: DEBUG
USAGE: log:debug [message...]
"
    log_with_level "DEBUG" "$@"
  }

  function log:trace() {
    : "
Log a message to level: TRACE
USAGE: log:trace [message...]
"
    log_with_level "TRACE" "$@"
  }

  function log:info() {
    : "
Log a message to level: INFO
USAGE: log:info [message...]
"
    log_with_level "INFO" "$@"
  }

  function log:warn() {
    : "
Log a message to level: WARN
USAGE: log:warn [message...]
"
    log_with_level "WARN" "$@"
  }

  function log:error() {
    : "
Log a message to level: ERROR
USAGE: log:error [message...]
"
    log_with_level "ERROR" "$@"
  }

  function log:critical() {
    : "
Log a message to level: ERROR
USAGE: log:critical [message...]
"
    log_with_level "CRITICAL" "$@"
  }

  function log() {
    : "
Log a message to level: INFO
USAGE: log:info [message...]
"
    log:info "$@"
  }

  # (DEPRECATED)
  function log:warning() {
    log:warn "$@"
  }

  : "${LINE_SEPARATOR:="----------------------------"}"

  function log:sep() {
    : "
Output a seperator for nicer logging. (Dose not have)
USAGE: log:sep [message...]
"
    echo "$green$LINE_SEPARATOR$end_color"
    if [ "$#" -gt 0 ]; then
      echo "${magenta}->${end_color}" "$@"
    fi
  }
fi
