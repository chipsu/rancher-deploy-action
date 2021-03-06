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

if [[ "$COMPOSE_FILE" = "" ]]; then
    COMPOSE_FILE=docker-compose.yml

    if [[ "$GITHUB_BRANCH" = "" ]]; then
        GITHUB_BRANCH=${GITHUB_REF#refs/*/}
    fi

    check_var "GITHUB_BRANCH"

    if [[ -f "docker-compose-${GITHUB_BRANCH}.yml" ]]; then
        COMPOSE_FILE="docker-compose-${GITHUB_BRANCH}.yml"
    fi

    if [[ "$RANCHER_STACK" = "" ]]; then
        check_var "GITHUB_REPOSITORY"
        RANCHER_STACK=$COMPOSE_FILE
        RANCHER_STACK=${RANCHER_STACK/docker-compose/$GITHUB_REPOSITORY}
        RANCHER_STACK=${RANCHER_STACK/.yml/}
        RANCHER_STACK=${RANCHER_STACK/\/-/}
    fi
fi

check_var "RANCHER_URL"
check_var "RANCHER_ACCESS_KEY"
check_var "RANCHER_SECRET_KEY"
check_var "RANCHER_STACK"
check_var "RANCHER_ACTION"
check_var "COMPOSE_FILE"
check_file_var "COMPOSE_FILE"

if [[ $failed -gt 0 ]]; then
    echo "Requirements check failed ($failed)" 1>&2
    ls -lha
    exit 1
fi

if [[ "$VALIDATE_COMPOSE_FILE" == "true" ]]; then
    docker-compose -f "$COMPOSE_FILE" config > /dev/null || exit 1
fi

if [[ "$USE_ENVSUBST" == "true" ]]; then
    ORIG_COMPOSE_FILE=$COMPOSE_FILE
    COMPOSE_FILE=$(mktemp)
    cat "$ORIG_COMPOSE_FILE" | envsubst > "$COMPOSE_FILE"
fi

echo Config:
cat "$COMPOSE_FILE"
echo

echo Deploying to Rancher...
echo COMPOSE_FILE=$COMPOSE_FILE
echo RANCHER_STACK=$RANCHER_STACK
echo RANCHER_ACTION=$RANCHER_ACTION

if echo "$RANCHER_ACTION" | grep -q "deploy"; then
    rancher up -s "$RANCHER_STACK" -f "$COMPOSE_FILE" --pull --upgrade --prune -d || exit 1
fi

if echo "$RANCHER_ACTION" | grep -q "confirm"; then
    rancher up -s "$RANCHER_STACK" -f "$COMPOSE_FILE" --confirm-upgrade -d || exit 1
fi

if echo  "$RANCHER_ACTION" | grep -q "rollback"; then
    rancher up -s "$RANCHER_STACK" -f "$COMPOSE_FILE" --rollback -d || exit 1
fi
