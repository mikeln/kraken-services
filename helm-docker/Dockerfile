FROM alpine:3.3

ENV KUBERNETES_VERSION=v1.3.2

# socat
RUN apk update \
    && apk add socat \
    && apk add ca-certificates \
    && update-ca-certificates

# kubectl
RUN wget https://storage.googleapis.com/kubernetes-release/release/${KUBERNETES_VERSION}/bin/linux/amd64/kubectl \
    && mv kubectl /usr/bin \
    && chmod +x /usr/bin/kubectl

COPY helm /

VOLUME /helm-home

ENV HELM_HOME /helm-home

ENTRYPOINT ["/helm"]