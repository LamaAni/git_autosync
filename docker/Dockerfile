from ubuntu:20.10

ARG GIT_AUTOSYNC_VERSION="latest"
ENV GIT_AUTOSYNC_VERSION="$GIT_AUTOSYNC_VERSION"

RUN apt-get update && \
    apt-get install -yqq git curl && \
    apt-get clean

RUN curl -Ls "https://raw.githubusercontent.com/LamaAni/git_autosync/master/install?ts_$(date +%s)=$RANDOM" | bash

ARG GIT_AUTOSYNC_REPO_LOCAL_PATH="/sync"
ARG GIT_AUTOSYNC_REPO_URL="https://github.com/LamaAni/git_autosync.git"

ENV GIT_AUTOSYNC_REPO_LOCAL_PATH="${GIT_AUTOSYNC_REPO_LOCAL_PATH}"\
    GIT_AUTOSYNC_REPO_URL="${GIT_AUTOSYNC_REPO_URL}"

CMD [ "git_autosync" ]
