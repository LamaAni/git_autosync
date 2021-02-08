# git_autosync script

A bash script and docker image for auto-syncing of a git repo.

The scripts allows for the continues update of a git repo, to folder, with a
minimal time delay of 1 second.

#### Remember, if you like it, star it, so other people would also use it.

# BETA

#### Contributors are welcome :)

# Requirements

1. [bash shell](<https://en.wikipedia.org/wiki/Bash_(Unix_shell)>)
2. [git](https://git-scm.com/)

# TL;DR

For inline help use,

```shell
git_autosync --help
```

Sync the git_autosync repo itself into /tmp/sync

```shell
./src/run /tmp/sync -r  git@github.com:LamaAni/git_autosync.git
```

For an example of how to use in kubernetes see [kubernetes_website_sidecar_autosync.yaml](examples/kubernetes_website_sidecar_autosync.yaml)

# Install

Downloads and installs from latest release,

```shell
curl -Ls "https://raw.githubusercontent.com/LamaAni/git_autosync/master/install?ts_$(date +%s)=$RANDOM" | sudo bash
```

# Environment variables

name | description | default value
---|---|---
GIT_AUTOSYNC_REPO_LOCAL_PATH | The local path to the repo | `required!` or inline
GIT_AUTOSYNC_REPO_URL | The remote repo, will use the repo in the local path if not found.
GIT_AUTOSYNC_SSH_KEY | The ssh key to use. (private key) | empty
GIT_AUTOSYNC_SSH_KEY_PATH | The path to the ssh key to use. (private key) | empty
GIT_AUTOSYNC_REPO_BRANCH | The repo branch to use | master
GIT_AUTOSYNC_MAX_SYNC_RUN_COUNT | How many times to sync | -1 = infinity, 0 = just clone
GIT_AUTOSYNC_INTERVAL | The sync interval (seconds) | 5
GIT_AUTOSYNC_SYNC_COMMAND | The sync command to use | `git pull`
GIT_AUTOSYNC_RUN_ASYNC | If 1 then run the sync_loop in a different thread, will exist the process | 0
GIT_AUTOSYNC_CHECK_HOSTS | If 1 then the git host must be listed in the known_hosts | 0
GIT_AUTOSYNC_RUN_DO_CLONE | If 1, then try clone if dose not exist | 1
GIT_AUTOSYNC_ARGS | Extra args, space/newline delimited | empty

# Licence

Copyright ©
`Zav Shotan` and other [contributors](https://github.com/LamaAni/git_autosync/graphs/contributors).
It is free software, released under the MIT licence, and may be redistributed under the terms specified in `LICENSE`.
