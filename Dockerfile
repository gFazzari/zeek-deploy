ARG BASE_IMAGE_RELEASE
FROM docker.elmec.com/dmilog/rafiki-base:${BASE_IMAGE_RELEASE}
LABEL MAINTAINER soc@elmec.it

COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]