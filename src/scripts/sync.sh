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
FLAGS:
    -a --async      If flag exists, syncs in background after first successful sync
    -h --help       Show this help menu.
    --no-clone      Do not clone the repo if dose not exist.
    --check-hosts   Disable to auto allow all hosts. Removes man in the middle vonrability,
                    but will require you to update the known_hosts.
ENVS:
    GIT_AUTOSYNC_LOGPREFEX  The git sync log prefex, (apperas before the log),
                            Allowes for stack tracing.
"

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
    GIT_AUTOSYNC_LAST_WORKING_DIR="$PWD"
    cd "$GIT_AUTOSYNC_REPO_LOCAL_PATH"
    assert $? "Failed to enter directory $GIT_AUTOSYNC_REPO_LOCAL_PATH" || return $?
}

function back_to_working_dir() {
    cd "$GIT_AUTOSYNC_LAST_WORKING_DIR"
    assert $? "Failed to enter directory $GIT_AUTOSYNC_LAST_WORKING_DIR" || return $?
}

function prepare() {
    if [ -n "$GIT_AUTOSYNC_SSH_KEY" ] && [ -z "$GIT_AUTOSYNC_SSH_KEY_PATH" ]; then
        export GIT_AUTOSYNC_SSH_KEY_PATH="$(mktemp /tmp/git_autosync_ssh_key-XXXXXXXX)"
        assert $? "Faild to create ssh key tempfile"
        TEMP_FILES+=("$GIT_AUTOSYNC_SSH_KEY_PATH")
    fi
    : "${GIT_SSH_COMMAND:="ssh"}"
    if [ -n "$GIT_AUTOSYNC_SSH_KEY_PATH" ]; then
        GIT_SSH_COMMAND="$GIT_SSH_COMMAND -i '$GIT_AUTOSYNC_SSH_KEY_PATH'"
    fi

    if [ "$GIT_AUTOSYNC_CHECK_HOSTS" -eq 0 ]; then
        GIT_SSH_COMMAND="$GIT_SSH_COMMAND -o StrictHostKeyChecking=no"
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

    if [ -z "$GIT_AUTOSYNC_REPO_BRANCH" ]; then
        GIT_AUTOSYNC_REPO_BRANCH="$(git 2>/dev/null rev-parse --abbrev-ref HEAD)"
        if [ -z "$GIT_AUTOSYNC_REPO_BRANCH" ]; then
            GIT_AUTOSYNC_REPO_BRANCH="master"
        fi
    fi

    back_to_working_dir || return $?

    export GIT_AUTOSYNC_REPO_BRANCH
    export GIT_AUTOSYNC_REPO_URL
    export GIT_SSH_COMMAND
    export GIT_AUTOSYNC_REPO_LOCAL_PATH
}

function check_and_clone() {
    to_sync_dir || return $?
    git 2>/dev/null 1>&2 rev-parse --abbrev-ref
    local is_git_repo="$?"
    if [ $is_git_repo -ne 0 ] && [ "$GIT_AUTOSYNC_RUN_DO_CLONE" -eq 1 ]; then
        log "cloning into $GIT_AUTOSYNC_REPO_URL $GIT_AUTOSYNC_REPO_BRANCH -> $GIT_AUTOSYNC_REPO_LOCAL_PATH"
        git clone -b "$GIT_AUTOSYNC_REPO_BRANCH" "$GIT_AUTOSYNC_REPO_URL" "$GIT_AUTOSYNC_REPO_LOCAL_PATH"
        assert $? "Failed to clone" || return $?
    elif [ $is_git_repo -ne 0 ]; then
        assert 2 "Cannot initialize, location is not a repository and cannot clone" || return $?
    fi
    back_to_working_dir || return $?
}

# Script to auto sync a git repo dag.
function sync() {

    # this may be changed at each iteration.
    local GIT_AUTOSYNC_LAST_WORKING_DIR="$PWD"

    function sync() {
        to_sync_dir || return $?
        log "Invoking sync with '$GIT_AUTOSYNC_SYNC_COMMAND'..."
        eval "$GIT_AUTOSYNC_SYNC_COMMAND"
        local last_error=$?

        back_to_working_dir || return $?
        assert $last_error "Failed sync from remote using command '$GIT_AUTOSYNC_SYNC_COMMAND'" || return $?
        return 0
    }

    function get_change_list() {
        to_sync_dir || return $?

        function __internal() {
            remote_update_log="$(git remote update)"
            newline=$'\n'
            assert "$?" "Failed to update from remote: $newline$remote_update_log $newline Proceed to next attempt" || return 0

            file_difs="$(git diff "$GIT_AUTOSYNC_REPO_BRANCH" "origin/$GIT_AUTOSYNC_REPO_BRANCH" --name-only)"
            assert $? "Field to execute git diff: $file_difs" || return $?

            if [ -n "$file_difs" ]; then
                echo "$file_difs"
            fi

            return 0
        }

        __internal
        local last_error="$?"
        back_to_working_dir || return $?
        assert $last_error "Failed to get change list." || return $?

        return 0
    }

    # first attempt to pull
    get_change_list
    assert $? "Failed to initialize remote repo autosync @ $GIT_AUTOSYNC_REPO_URL $GIT_AUTOSYNC_REPO_BRANCH to $GIT_AUTOSYNC_REPO_LOCAL_PATH" || return $?

    local last_error=0

    function sync_loop() {
        log "Starting sync: $GIT_AUTOSYNC_REPO_URL/$GIT_AUTOSYNC_REPO_BRANCH -> $GIT_AUTOSYNC_REPO_LOCAL_PATH"
        local sync_count=0
        while true; do
            change_list="$(get_change_list)"
            last_error=$?

            if [ $last_error -ne 0 ]; then
                log "ERROR: could not get change list. Re-attempting in $GIT_AUTOSYNC_INTERVAL [sec]."
                sleep "$GIT_AUTOSYNC_INTERVAL"
                continue
            fi

            if [ -n "$change_list" ]; then
                log "Repo has changed:"
                echo "$change_list"
                sync
                assert $? "Failed to sync. Re-attempt in $GIT_AUTOSYNC_INTERVAL seconds" || continue
                log "Sync complete @ $(date)"
            fi

            if [ $GIT_AUTOSYNC_MAX_SYNC_RUN_COUNT -gt 0 ] && [ $GIT_AUTOSYNC_MAX_SYNC_RUN_COUNT -gt $sync_count ]; then
                break
            fi
            sync_count=$((sync_count + 1))
            sleep "$GIT_AUTOSYNC_INTERVAL"
        done

        log "Sync stopped"
    }

    # start loop.
    if [ $GIT_AUTOSYNC_RUN_ASYNC -eq 1 ]; then
        sync_loop &
    else
        sync_loop
    fi
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
prepare && check_and_clone && sync && cleanup $?
