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

# add release.yaml from previous successful nightly build to re-synced release-next as a backup
git fetch ${OPENSHIFT_REMOTE} release-next

git checkout FETCH_HEAD openshift/release/tektoncd-triggers-nightly.yaml

git add openshift/release/tektoncd-triggers-nightly.yaml
git commit -m ":robot: Add previous days release.yaml as back up"

git push -f ${OPENSHIFT_REMOTE} release-next

# Trigger CI
git checkout release-next -B release-next-ci

./openshift/release/generate-release.sh nightly

date > ci
git add ci openshift/release/tektoncd-triggers-nightly.yaml
git commit -m ":robot: Triggering CI on branch 'release-next' after synching to upstream/master"

git push -f ${OPENSHIFT_REMOTE} release-next-ci

# removing upstream remote so that hub points origin for hub pr list command due to this issue https://github.com/github/hub/issues/1973
git remote remove upstream
already_open_github_issue_id=$(hub pr list -s open -f "%I %l%n"|grep ${LABEL}| awk '{print $1}'|head -1)
[[ -n ${already_open_github_issue_id} ]]  && {
    echo "PR for nightly is already open on #${already_open_github_issue_id}"
    #hub api repos/${OPENSHIFT_ORG}/${REPO_NAME}/issues/${already_open_github_issue_id}/comments -f body='/retest'
    exit 0
}

hub pull-request -m "🛑🔥 Triggering Nightly CI for ${REPO_NAME} 🔥🛑" -m "/hold" -m "Nightly CI do not merge :stop_sign:" \
    --no-edit -l "${LABEL}" -b ${OPENSHIFT_REMOTE}/${REPO_NAME}:release-next -h ${OPENSHIFT_REMOTE}/${REPO_NAME}:release-next-ci
