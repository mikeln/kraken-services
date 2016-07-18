FROM alpine:3.3

ENV KUBERNETES_VERSION=v1.2.5

# socat
RUN apk update \
    && apk add socat \
    && apk add ca-certificates \
    && update-ca-certificates 

# kubectl
RUN wget https://github.com/GoogleCloudPlatform/kubernetes/releases/download/${KUBERNETES_VERSION}/kubernetes.tar.gz \
    && tar -xvzf kubernetes.tar.gz \
    && cp kubernetes/platforms/linux/amd64/kubectl /usr/bin \
    && rm kubernetes.tar.gz

COPY helm /

VOLUME /helm-home

ENV HELM_HOME /helm-home

ENTRYPOINT ["/helm"]