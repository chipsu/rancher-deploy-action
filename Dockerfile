FROM chipu/rancher-cli
COPY entrypoint.sh /entrypoint.sh
RUN apk update && apk add docker-cli
ENTRYPOINT ["/entrypoint.sh"]
