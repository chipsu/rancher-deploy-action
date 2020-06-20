FROM chipu/rancher-cli
COPY entrypoint.sh /entrypoint.sh
RUN apk add docker-compose
RUN docker-compose --help
ENTRYPOINT ["/entrypoint.sh"]
