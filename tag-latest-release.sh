#!/usr/bin/env bash

######################################################################################
##                               tag-latest-release                                 ##
######################################################################################
# A bash script to tag a repository with the latest release tag of an upstream repo.
# - To be used in a cron job (e.g. K8s CronJob) to trigger CICD pipelines in
#   repositories that build on 'tag' events.
# - For people who maintain their own docker images based off upstream images and want
#   to automate the build process.

# Environment variables
# REPO_URL              : Docker image repository URL
# UPSTREAM_URL          : Upstream repository URL
# SSH_PRIVATE_KEY_FILE  : Path to SSH private key with push access

set -e

# SSH variables
KNOWN_HOSTS_FILE=${KNOWN_HOSTS_FILE:-'./known_hosts'}
SSH_PRIVATE_KEY_FILE=${SSH_PRIVATE_KEY_FILE:-}
SSH_PATH="$HOME/.ssh"

# Repository variables
REPO_URL=${REPO_URL:-}
UPSTREAM_URL=${UPSTREAM_URL:-}
APP_ROOT='/repos'

# Check environment variables
if [[ -z "$REPO_URL" ]]; then
    echo 'Missing REPO_URL'
    exit 1
elif [[ -z "$UPSTREAM_URL" ]]; then
    echo 'Missing UPSTREAM_URL'
    exit 1
elif [[ -z $SSH_PRIVATE_KEY_FILE ]]; then
    echo 'Missing SSH_PRIVATE_KEY_FILE'
    exit 1
elif ! [[ -f "$SSH_PRIVATE_KEY_FILE" ]]; then
    echo "SSH key not found at: $SSH_PRIVATE_KEY_FILE"
    exit 1
elif ! [[ -f "$KNOWN_HOSTS_FILE" ]]; then
    echo "known_hosts not found at: $KNOWN_HOSTS_FILE"
    echo "Using default known_hosts..."
    KNOWN_HOSTS_FILE='./known_hosts'
fi
[[ $REPO_URL == *.git ]] || REPO_URL+=.git
[[ $UPSTREAM_URL == *.git ]] || UPSTREAM_URL+=.git

# Set dependent constants
UPSTREAM_USER=$(echo $UPSTREAM_URL | sed -n 's/^.*github.com[:/]\(.*\)\/\(.*\).git/\1/p')
UPSTREAM_REPO_NAME=$(echo $UPSTREAM_URL | sed -n 's/^.*github.com[:/]\(.*\)\/\(.*\).git/\2/p')
ORIGIN_REPO_NAME=$(echo $REPO_URL | sed -n 's/^.*github.com[:/]\(.*\)\/\(.*\).git/\2/p')
REPO_PATH=$APP_ROOT/$ORIGIN_REPO_NAME

configure_ssh() {
    mkdir -p $SSH_PATH
    cp $KNOWN_HOSTS_FILE $SSH_PATH/
    cp $SSH_PRIVATE_KEY_FILE $SSH_PATH/id_rsa
    chmod 600 $SSH_PATH/id_rsa
}

check_repo_url() {
    local REPO_HTTPS_URL=$(echo $REPO_URL | sed -En 's#.*(https://[^[:space:]]*).*#\1#p')
    if [[ -z "$REPO_HTTPS_URL" ]]; then
        echo "Repo URL is using SSH"
    else
        echo "WARNING: Repo URL is using HTTPS, attemping conversion to SSH..."
        local USER=$(echo $REPO_HTTPS_URL | sed -En 's#https://github.com/([^/]*)/(.*).git#\1#p')
        if [[ -z "$USER" ]]; then
            echo "-- ERROR:  Could not identify User."
            exit 1
        fi

        local REPO=$(echo $REPO_HTTPS_URL | sed -En 's#https://github.com/([^/]*)/(.*).git#\2#p')
        if [[ -z "$REPO" ]]; then
            echo "-- ERROR:  Could not identify Repo."
            exit 1
        fi

        local NEW_URL="git@github.com:$USER/$REPO.git"
        echo "Changing repo url from "
        echo "  '$REPO_HTTPS_URL'"
        echo "      to "
        echo "  '$NEW_URL'"
        echo ""

        REPO_URL=$NEW_URL
    fi
}

check_if_pull_needed() {
    local LOCAL=$(git -C $REPO_PATH rev-parse @)
    local REMOTE=$(git -C $REPO_PATH rev-parse @{u})
    local BASE=$(git merge-base @ @{u})
    if [[ $LOCAL = $REMOTE ]]; then
        echo "Up-to-date"
        return 0
    elif [[ $LOCAL = $BASE ]]; then
        echo "New commits available"
        return 1
    fi
}

fetch_tags_or_clone_repo() {
    if [[ -d $REPO_PATH ]]; then
        echo "Local repo exists"
        check_if_pull_needed
        local PULL_NEEDED=$?
        if [[ $PULL_NEEDED -eq 1 ]]; then
            echo "Pulling latest commit"
            git -C $REPO_PATH pull
        fi
        echo "Fetching repository tags..."
        git -C $REPO_PATH fetch --tags
    else 
        echo "Local repo not cloned yet"
        echo "Cloning repository..."
        git clone $REPO_URL $REPO_PATH
    fi
}

get_latest_release() {
    curl --silent "https://api.github.com/repos/$1/releases/latest" |
    grep '"tag_name":' |
    sed -E 's/.*"([^"]+)".*/\1/'
}

check_and_push_tags() {
    if ! git -C $REPO_PATH tag | grep -q $LATEST_RELEASE; then
        echo "Tag does not currently exist"
        echo "Pushing tag: $LATEST_RELEASE"
        git -C $REPO_PATH tag $LATEST_RELEASE
        git -C $REPO_PATH push origin $LATEST_RELEASE
    else
        echo "Tag already exists. Skipping..."
    fi
}

echo "Configuring SSH..."
configure_ssh

echo "Checking repo URL..."
check_repo_url

echo "Fetch tags or clone repository..."
fetch_tags_or_clone_repo

echo "Fetching latest release..."
LATEST_RELEASE=$(get_latest_release $UPSTREAM_USER/$UPSTREAM_REPO_NAME)
echo "Latest release for $UPSTREAM_USER/$UPSTREAM_REPO_NAME: $LATEST_RELEASE"

echo "Checking existing tags..."
check_and_push_tags

echo "Done"