# syntax=docker/dockerfile:1.7

FROM alpine:3.21

ARG TARGETARCH

RUN apk add --no-cache \
    bash \
    ca-certificates \
    coreutils \
    curl \
    docker-cli \
    docker-cli-compose \
    findutils \
    gawk \
    git \
    grep \
    iproute2 \
    less \
    nano \
    openssh-client \
    procps \
    sed \
    tar \
    tzdata \
    unzip \
    xz \
    zip

COPY app/bin/MDesk-${TARGETARCH} /usr/local/bin/mdesk

RUN chmod 0755 /usr/local/bin/mdesk \
    && ln -sf /usr/local/bin/mdesk /usr/local/bin/MDesk \
    && mkdir -p /data

ENV HOME=/data
WORKDIR /data

EXPOSE 19188
VOLUME ["/data"]

ENTRYPOINT ["/usr/local/bin/mdesk"]
CMD ["-data", "/data"]
