FROM alpine:3.3

COPY helm /

VOLUME /helm-home

ENV HELM_HOME /helm-home

ENTRYPOINT ["/helm"]