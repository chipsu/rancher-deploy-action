FROM chipu/rancher-cli
COPY entrypoint.sh /entrypoint.sh
RUN apk add docker-compose gettext
RUN docker-compose --help
ENTRYPOINT ["/entrypoint.sh"]
