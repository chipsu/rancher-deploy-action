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

if [[ "$DOCKER_IMAGE" = "" ]]; then
    DOCKER_IMAGE=${GITHUB_REPOSITORY}-${GITHUB_BRANCH}
fi

if [[ "$COMPOSE_FILE" = "" ]]; then
    COMPOSE_FILE=docker-compose.yml

    if [[ -f "docker-compose-${GITHUB_BRANCH}.yml" ]]; then
        COMPOSE_FILE="docker-compose-${GITHUB_BRANCH}.yml"
    fi

    if [[ "$RANCHER_STACK" = "" ]]; then
        RANCHER_STACK=$COMPOSE_FILE
        RANCHER_STACK=${RANCHER_STACK/docker-compose/$DOCKER_IMAGE}
        RANCHER_STACK=${RANCHER_STACK/.yml/}
    fi
fi

if [[ "$DOCKER_CONTEXT" = "" ]]; then
    DOCKER_CONTEXT=.
fi

DOCKER_FILE=$DOCKER_CONTEXT/Dockerfile

check_var "GITHUB_SHA"
check_var "GITHUB_REPOSITORY"
check_var "GITHUB_BRANCH"
check_var "RANCHER_URL"
check_var "RANCHER_ACCESS_KEY"
check_var "RANCHER_SECRET_KEY"
check_var "RANCHER_STACK"
check_var "COMPOSE_FILE"
check_file_var "COMPOSE_FILE"

if [[ -f "$DOCKER_FILE" ]]; then
    check_var "DOCKER_USERNAME"
    check_var "DOCKER_PASSWORD"
    check_var "DOCKER_REGISTRY"
    check_var "DOCKER_IMAGE"
fi

if [[ $failed -gt 0 ]]; then
    echo "Requirements check failed ($failed)" 1>&2
    ls -lha
    tree
    exit 1
fi

if [[ -f "$DOCKER_FILE" ]]; then
    echo Building Docker image...
    echo DOCKER_IMAGE=$DOCKER_IMAGE
    echo GITHUB_SHA=$GITHUB_SHA
    echo GITHUB_BRANCH=$GITHUB_BRANCH

    docker build -t $DOCKER_IMAGE --build-arg version=$GITHUB_SHA $DOCKER_CONTEXT || exit 1
    docker tag $DOCKER_IMAGE $DOCKER_REGISTRY/$DOCKER_USERNAME/$DOCKER_IMAGE:$GITHUB_SHA || exit 1
    docker tag $DOCKER_IMAGE $DOCKER_REGISTRY/$DOCKER_USERNAME/$DOCKER_IMAGE:$GITHUB_BRANCH || exit 1
    echo $DOCKER_PASSWORD | docker login -u="$DOCKER_USERNAME" --password-stdin $DOCKER_REGISTRY || exit 1
    docker push $DOCKER_REGISTRY/$DOCKER_USERNAME/$DOCKER_IMAGE || exit 1
fi

echo Deploying to Rancher...
echo GITHUB_SHA=$GITHUB_SHA
echo COMPOSE_FILE=$COMPOSE_FILE
echo RANCHER_STACK=$RANCHER_STACK

rancher up -s $RANCHER_STACK -f $COMPOSE_FILE --pull --upgrade --prune -d || exit 1
rancher up -s $RANCHER_STACK -f $COMPOSE_FILE --confirm-upgrade -d || exit 1

echo todo lb?
echo todo healthcheck and rollback?
