# git_autosync script

A bash script for autosync of a git repo to a local machine.

The scripts allows for the continues update of a git repo, to a local folder, with a
minimal time delay of 1 second. This script dose not require the use of a git repo plugin
or app, and is based on bash and git commands alone.

#### Contributors are welcome :)

# Requirements
1. [bash shell](https://en.wikipedia.org/wiki/Bash_(Unix_shell))
2. [git](https://git-scm.com/)
3. A cloned git repo.

# Use as a script
```shell
bash> git_autosync [args] ...
```

# Use as a source library
```shell
#!/usr/bin/env bash
# notice no arguments passed.
source "[somepath]/git_autosync" --as-lib
```

# Usage and arguments

argument name | description | default value
---|---|---
[sync-path]     | The path to the repo. | current folder
-r, --repo-url   | The repo url, example: `git@github.com:LamaAni/git_autosync.git`  | the repo in the sync-path
-b, --branch     | The name of the branch | the active branch in the sync-path
-n, --max-times  | Max Number of sync times. -1 for infinity. | -1
-i, --interval   | The time interval to use in seconds | 5 seconds
-a, --async      | Syncs in background after validating the repo connection | true if flag exists
--sync-command  | The git sync command to use. | git pull
--as-lib        | Load the current file as a library function. Dose not allow any other arguments. | true if flag exists
-h, --help       | Help menu

Env name | description | default value
---|---|---
GIT_AUTOSYNC_LOGPREFEX | The log prefex for git_autosync. Will be printed before and sync logs. | GIT_AUTOSYNC:

# Notes

Mostly, I use this script to sync my repo to remote machines, when deploying a web service of 
some sorts. There are more agile and better solutions, but I find that this simple approach is very powerful.

If there is more interest in this script I will add installs, releases and requested functionality.

# Rights

All rights under the....