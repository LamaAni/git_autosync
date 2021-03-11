#!/usr/bin/env bash

HELP="
 
Start an autosync proecss, with a folder and an autosync path.
 
USAGE: git_autosync [sync-path]
INPUTS:
    [sync-path] The path to the repo. (Defualts to current folder)
ARGS:
    -r | --repo-url     The repo url (defaults to folder git repo if exists)
    -b | --branch       The name of the branch (defaults to folder git branch if exists)
    -n | --max-times    Max Number of sync times. -1 for infinity. (default -1)
    -i | --interval     The time GIT_AUTOSYNC_INTERVAL to use in seconds (defaults to 5)
    --ssh-key           The ssh key to use when connecting to the server.
    --ssh-key-path      The path to the ssh key file.
    --sync-command      The git sync command to use. (defaults to 'git pull')
    --git-arg           Add a git argument.
FLAGS:
    -a --async        If flag exists, syncs in background after first successful sync
    -h --help         Show this help menu.
    --fail-no-branch  Fail if this is not a branch (detached head or tag)
    --no-clone        Do not clone the repo if dose not exist.
    --check-hosts     Disable to auto allow all hosts. Removes man in the middle vonrability,
                      but will require you to update the known_hosts.
ENVS:
    GIT_AUTOSYNC_LOGPREFEX  The git sync log prefex, (apperas before the log),
                            Allowes for stack tracing.
"

: "${LOG_DISPLAY_EXTRA:="[git_autosync]"}"

: "${GIT_AUTOSYNC_REPO_LOCAL_PATH:=""}"
: "${GIT_AUTOSYNC_REPO_URL:=""}"
: "${GIT_AUTOSYNC_SSH_KEY:=""}"
: "${GIT_AUTOSYNC_SSH_KEY_PATH:=""}"
: "${GIT_AUTOSYNC_REPO_BRANCH:=""}"
: "${GIT_AUTOSYNC_MAX_SYNC_RUN_COUNT:=-1}"
: "${GIT_AUTOSYNC_INTERVAL:=5}"
: "${GIT_AUTOSYNC_SYNC_COMMAND:="git pull"}"
: "${GIT_AUTOSYNC_RUN_ASYNC:=0}"
: "${GIT_AUTOSYNC_CHECK_HOSTS:=0}"
: "${GIT_AUTOSYNC_RUN_DO_CLONE:=1}"
: "${GIT_AUTOSYNC_FAIL_ON_NO_BRANCH:=0}"
: "${GIT_AUTOSYNC_ARGS:=""}"

# loading varaibles.
while [ $# -gt 0 ]; do
  case "$1" in
  -h | --help)
    log:help "$HELP"
    exit 0
    ;;
  -r | --repo-url)
    shift
    GIT_AUTOSYNC_REPO_URL="$1"
    ;;
  -b | --branch)
    shift
    GIT_AUTOSYNC_REPO_BRANCH="$1"
    ;;
  -n | --max-times)
    shift
    GIT_AUTOSYNC_MAX_SYNC_RUN_COUNT=$1
    ;;
  -i | --GIT_AUTOSYNC_INTERVAL)
    shift
    GIT_AUTOSYNC_INTERVAL="$1"
    ;;
  -a | --async)
    GIT_AUTOSYNC_RUN_ASYNC=1
    ;;
  --no-clone)
    GIT_AUTOSYNC_RUN_DO_CLONE=0
    ;;
  --sync-command)
    shift
    GIT_AUTOSYNC_SYNC_COMMAND="$1"
    ;;
  --ssh-key)
    shift
    GIT_AUTOSYNC_SSH_KEY="$1"
    ;;
  --ssh-key-path)
    shift
    GIT_AUTOSYNC_SSH_KEY_PATH="$1"
    ;;
  --git-arg)
    shift
    GIT_AUTOSYNC_ARGS+=($1)
    ;;
  --fail-no-branch)
    GIT_AUTOSYNC_FAIL_ON_NO_BRANCH=1
    ;;
  -*)
    assert 2 "Unknown identifier $1" || return $?
    ;;
  *)
    if [ -z "$GIT_AUTOSYNC_REPO_LOCAL_PATH" ]; then
      GIT_AUTOSYNC_REPO_LOCAL_PATH="$1"
    else
      assert 2 "Unknown positional parameter (or command) $1" || return $?
    fi
    ;;
  esac
  shift
done

TEMP_FILES=()

function to_sync_dir() {
  export GIT_AUTOSYNC_LAST_WORKING_DIR="$PWD"
  cd "$GIT_AUTOSYNC_REPO_LOCAL_PATH"
  assert $? "Failed to enter directory $GIT_AUTOSYNC_REPO_LOCAL_PATH" || return $?
  return $code
}

# shellcheck disable=SC2120
function back_to_working_dir() {
  local code="$1"
  : "${code:=0}"
  cd "$GIT_AUTOSYNC_LAST_WORKING_DIR"
  assert $? "Failed to enter directory $GIT_AUTOSYNC_LAST_WORKING_DIR" || return $?
  return $code
}

function prepare() {
  if [ -n "$GIT_AUTOSYNC_SSH_KEY" ] && [ -z "$GIT_AUTOSYNC_SSH_KEY_PATH" ]; then
    GIT_AUTOSYNC_SSH_KEY_PATH="$(mktemp /tmp/git_autosync_ssh_key-XXXXXXXX)" &&
      echo "$GIT_AUTOSYNC_SSH_KEY" >|"$GIT_AUTOSYNC_SSH_KEY_PATH"
    assert $? "Faild to create ssh key tempfile"
    log:info "Created ssh key file from env @ $GIT_AUTOSYNC_SSH_KEY_PATH"
    if [ $GIT_AUTOSYNC_RUN_ASYNC -ne 1 ]; then
      TEMP_FILES+=("$GIT_AUTOSYNC_SSH_KEY_PATH")
    fi
  fi
  local git_ssh_command_args=""
  if [ -n "$GIT_AUTOSYNC_SSH_KEY_PATH" ]; then
    git_ssh_command_args="$git_ssh_command_args -i '$GIT_AUTOSYNC_SSH_KEY_PATH'"
  fi

  if [ "$GIT_AUTOSYNC_CHECK_HOSTS" -eq 0 ]; then
    git_ssh_command_args="$git_ssh_command_args -o StrictHostKeyChecking=no"
  fi

  if [ -n "$git_ssh_command_args" ]; then
    GIT_SSH_COMMAND="ssh $git_ssh_command_args"
  fi

  if [ -z "$GIT_AUTOSYNC_REPO_LOCAL_PATH" ]; then
    GIT_AUTOSYNC_REPO_LOCAL_PATH="."
  fi

  GIT_AUTOSYNC_REPO_LOCAL_PATH="$(realpath "$GIT_AUTOSYNC_REPO_LOCAL_PATH")"
  assert $? "Failed to resolve local path: $GIT_AUTOSYNC_REPO_LOCAL_PATH" || return $?

  mkdir -p "$GIT_AUTOSYNC_REPO_LOCAL_PATH"
  assert $? "Fialed to validate target directory" || return $?

  to_sync_dir || return $?

  # adding default params.
  if [ -z "$GIT_AUTOSYNC_REPO_URL" ]; then
    GIT_AUTOSYNC_REPO_URL="$(git config --get remote.origin.url)"
    if [ -z "$GIT_AUTOSYNC_REPO_URL" ]; then
      assert 2 "Failed to retrive git origin url" || return $?
    fi
  fi

  function get_git_current_branch() {
    git rev-parse --abbrev-ref HEAD 2>/dev/null
  }

  if [ -z "$GIT_AUTOSYNC_REPO_BRANCH" ]; then
    GIT_AUTOSYNC_REPO_BRANCH="$(get_git_current_branch)"
    if [ -z "$GIT_AUTOSYNC_REPO_BRANCH" ]; then
      GIT_AUTOSYNC_REPO_BRANCH="master"
    fi
  fi

  back_to_working_dir || return $?

  log:debug "Git ssh command: $GIT_SSH_COMMAND"
  export GIT_AUTOSYNC_REPO_BRANCH
  export GIT_AUTOSYNC_REPO_URL
  export GIT_SSH_COMMAND
  export GIT_AUTOSYNC_SSH_KEY_PATH
  export GIT_AUTOSYNC_REPO_LOCAL_PATH
}

function check_and_clone() {
  to_sync_dir || return $?
  git 2>/dev/null 1>&2 rev-parse --abbrev-ref
  local is_git_repo="$?"
  if [ $is_git_repo -ne 0 ] && [ "$GIT_AUTOSYNC_RUN_DO_CLONE" -eq 1 ]; then
    log "Cloning $GIT_AUTOSYNC_REPO_URL $GIT_AUTOSYNC_REPO_BRANCH -> $GIT_AUTOSYNC_REPO_LOCAL_PATH"
    git clone --single-branch -b "$GIT_AUTOSYNC_REPO_BRANCH" "$GIT_AUTOSYNC_REPO_URL" "$GIT_AUTOSYNC_REPO_LOCAL_PATH"
    assert $? "Failed to clone" || return $?
  elif [ $is_git_repo -ne 0 ]; then
    assert 2 "Cannot initialize, location is not a repository and cannot clone" || return $?
  fi
  back_to_working_dir || return $?
}

function get_change_list() {
  to_sync_dir || return $?

  newline=$'\n'
  remote_update_log="$(git remote update)"
  assert "$?" "Failed to update from remote: $newline$remote_update_log $newline (ignored) Proceeding to next attempt" || return 0

  file_difs="$(git diff "$GIT_AUTOSYNC_REPO_BRANCH" "origin/$GIT_AUTOSYNC_REPO_BRANCH" --name-only)"
  assert $? "Field to execute git diff when retriving change list: $file_difs" || return $?

  if [ -n "$file_difs" ]; then
    echo "$file_difs"
  fi

  return 0
}

function do_sync() {
  to_sync_dir
  assert $? "Failed to move into sync dir"

  log "Invoking sync with '$GIT_AUTOSYNC_SYNC_COMMAND'..."
  eval "$GIT_AUTOSYNC_SYNC_COMMAND"
  back_to_working_dir $?
  assert $? "Failed sync from remote using command '$GIT_AUTOSYNC_SYNC_COMMAND'" || return $?
  return 0
}

function sync_loop() {
  if [ "$GIT_AUTOSYNC_MAX_SYNC_RUN_COUNT" -eq 0 ]; then
    log "Not starting sync loop since GIT_AUTOSYNC_MAX_SYNC_RUN_COUNT=0."
    return 0
  fi

  log:info "starting sync: $GIT_AUTOSYNC_REPO_URL/$GIT_AUTOSYNC_REPO_BRANCH -> $GIT_AUTOSYNC_REPO_LOCAL_PATH"
  local sync_count=0
  local last_error=0
  while true; do
    change_list="$(get_change_list)"
    last_error=$?

    if [ $last_error -eq 0 ]; then
      if [ -n "$change_list" ]; then
        log "Repo has changed:"
        echo "$change_list"
        do_sync
        warn $? "Failed to sync repo. Re-attempt in $GIT_AUTOSYNC_INTERVAL seconds" &&
          log "Sync complete @ $(date)"
      fi

      if [ "$GIT_AUTOSYNC_MAX_SYNC_RUN_COUNT" -gt -1 ] && [ "$GIT_AUTOSYNC_MAX_SYNC_RUN_COUNT" -gt $sync_count ]; then
        break
      fi
      sync_count=$((sync_count + 1))
    else
      log:warn "git_autosync could not get change list. Re-attempting in $GIT_AUTOSYNC_INTERVAL [sec]."
    fi
    sleep "$GIT_AUTOSYNC_INTERVAL"
  done

  log "Sync stopped"
}

# Script to auto sync a git repo dag.
function start_sync() {
  to_sync_dir || return $?

  local current_branch="$(get_git_current_branch)"
  assert $? "Failed to retrive current branch" || return $?

  [ "$current_branch" != "HEAD" ]
  local code=$?

  if [ "$GIT_AUTOSYNC_FAIL_ON_NO_BRANCH" -eq 1 ]; then
    assert $code "No active sync availeable. $current_branch is not a branch. Autosync exited." || return 0
  else
    warn $code "No active sync availeable. $current_branch is not a branch." || return 0
  fi

  # first attempt to pull
  get_change_list
  assert $? "Failed to initialize remote repo autosync @ $GIT_AUTOSYNC_REPO_URL $GIT_AUTOSYNC_REPO_BRANCH to $GIT_AUTOSYNC_REPO_LOCAL_PATH" || return $?

  # start loop.
  if [ $GIT_AUTOSYNC_RUN_ASYNC -eq 1 ]; then
    sync_loop &
  else
    sync_loop
    assert $? "Sync loop failed" || return $?
  fi

  return 0
}

function cleanup() {
  local code="$?"
  if [ $GIT_AUTOSYNC_RUN_ASYNC -ne 1 ]; then
    for file in "${TEMP_FILES[@]}"; do
      rm -rf "$file"
      warn $? "Failed to remove temp @ $file"
    done
  fi

  return "$code"
}

# if not as library then use invoke the function.
prepare && check_and_clone && start_sync && cleanup $?
