#!/bin/sh -l

failed=0

check_var() {
    val=$(eval echo \$$1)
    if [[ "$val" = "" ]]; then
        echo "$1 not set" 1>&2
        failed=$((failed+1))
    fi
}

check_file_var() {
    val=$(eval echo \$$1)
    if [[ ! -f "$val" ]]; then
        echo "$1 '$val' file not found" 1>&2
        failed=$((failed+1))
    fi
}

cd "$GITHUB_WORKSPACE" || exit 1

if [[ "$GITHUB_BRANCH" = "" ]]; then
    GITHUB_BRANCH=${GITHUB_REF#refs/*/}
fi

if [[ "$COMPOSE_FILE" = "" ]]; then
    COMPOSE_FILE=docker-compose.yml

    if [[ -f "docker-compose-${GITHUB_BRANCH}.yml" ]]; then
        COMPOSE_FILE="docker-compose-${GITHUB_BRANCH}.yml"
    fi

    if [[ "$RANCHER_STACK" = "" ]]; then
        RANCHER_STACK=$COMPOSE_FILE
        RANCHER_STACK=${RANCHER_STACK/docker-compose/$GITHUB_REPOSITORY}
        RANCHER_STACK=${RANCHER_STACK/.yml/}
    fi
fi

check_var "GITHUB_SHA"
check_var "GITHUB_REPOSITORY"
check_var "GITHUB_BRANCH"
check_var "RANCHER_URL"
check_var "RANCHER_ACCESS_KEY"
check_var "RANCHER_SECRET_KEY"
check_var "RANCHER_STACK"
check_var "COMPOSE_FILE"
check_file_var "COMPOSE_FILE"

if [[ $failed -gt 0 ]]; then
    echo "Requirements check failed ($failed)" 1>&2
    ls -lha
    exit 1
fi

echo Deploying to Rancher...
echo GITHUB_SHA=$GITHUB_SHA
echo COMPOSE_FILE=$COMPOSE_FILE
echo RANCHER_STACK=$RANCHER_STACK

rancher up -s $RANCHER_STACK -f $COMPOSE_FILE --pull --upgrade --prune -d || exit 1
rancher up -s $RANCHER_STACK -f $COMPOSE_FILE --confirm-upgrade -d || exit 1

#echo todo lb?
#echo todo healthcheck and rollback?
