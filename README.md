# GitAutosync

A bash script for autosync of a git repo to a local machine. Has internal folders.

The scripts allows for the continues update of a git repo, to a local folder, with a
minimal time delay of 1 second. This script dose not require the use of a git repo plugin
or app, and is based on bash and git commands alone.

# Requirements
1. [bash shell](https://en.wikipedia.org/wiki/Bash_(Unix_shell))
2. [git](https://git-scm.com/)

# Use as a script
```shell
bash> git_auto_sync [args] ...
```

# use as a source library
```shell
#!/usr/bin/env bash
# notice no arguments passed.
source [path to git autosync]
# example:
source "/lama/git_auto_sync
```


