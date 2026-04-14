FROM ghcr.io/linuxserver/baseimage-alpine:edge AS builder

# Install build dependencies for librespot
RUN apk add --no-cache \
    cargo \
    rust \
    alsa-lib-dev \
    protobuf-dev

# Build librespot from source
ARG LIBRESPOT_RELEASE=0.8.0
#RUN cargo install librespot --version ${LIBRESPOT_RELEASE} \
#    --no-default-features \
#    --features alsa-backend,rustls-tls-native-roots
RUN cargo install librespot --version ${LIBRESPOT_RELEASE} \
    --no-default-features \
    --features alsa-backend,rustls-tls-native-roots,with-libmdns

# Final stage
FROM ghcr.io/linuxserver/baseimage-alpine:edge

# set version label
ARG BUILD_DATE
ARG VERSION
ARG SNAPCAST_RELEASE
ARG LIBRESPOT_RELEASE
LABEL build_version="version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="sweisgerber"

RUN set -ex \
  && echo "**** setup apk testing mirror ****" \
  && echo "@testing https://nl.alpinelinux.org/alpine/edge/testing/" >> /etc/apk/repositories \
  && cat /etc/apk/repositories \
  && echo "**** install runtime packages ****" \
  && apk add --no-cache -U --upgrade \
    alsa-utils \
    alsa-lib \
    dbus \
    shairport-sync@testing \
    snapcast@testing \
    snapweb@testing \
  && echo "**** cleanup ****" \
  && rm -rf \
    /tmp/*

# Copy librespot binary from builder stage
COPY --from=builder /root/.cargo/bin/librespot /usr/bin/librespot

# environment settings
ENV \
START_SNAPCLIENT=false \
START_AIRPLAY=false \
SNAPCLIENT_OPTS="" \
SNAPSERVER_OPTS=""

# copy local files
COPY root/ /

# ports and volumes
EXPOSE 1704
EXPOSE 1780

VOLUME /config /data
