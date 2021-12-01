#!/usr/bin/env bash

# Synchs the release-next branch to master and then triggers CI
# Usage: update-to-head.sh

set -ex
REPO_NAME=${REPO_NAME:-tektoncd-triggers}
OPENSHIFT_REMOTE=${OPENSHIFT_REMOTE:-openshift}
TODAY=`date "+%Y%m%d"`
LABEL=nightly-ci

# Reset release-next to upstream/main.
git fetch upstream main
git checkout upstream/main --no-track -B release-next

# Update openshift's master and take all needed files from there.
git fetch ${OPENSHIFT_REMOTE} master
git checkout ${OPENSHIFT_REMOTE}/master openshift Makefile OWNERS_ALIASES OWNERS
make generate-dockerfiles

git add openshift OWNERS_ALIASES OWNERS Makefile
git commit -m ":open_file_folder: Update openshift specific files."

if [[ -d openshift/patches ]];then
    for f in openshift/patches/*.patch;do
        [[ -f ${f} ]] || continue
        git am ${f}
    done
fi

git push -f ${OPENSHIFT_REMOTE} release-next
