# No builder stage needed - just the final stage
FROM ghcr.io/linuxserver/baseimage-alpine:edge

# Create shairport-sync user (handle existing GID)
RUN if ! getent group 1000 > /dev/null; then \
  addgroup -g 1000 -S shairport-sync; \
  else \
  addgroup -S shairport-sync; \
  fi && \
  if ! getent passwd 1000 > /dev/null; then \
  adduser -u 1000 -S shairport-sync -G shairport-sync; \
  else \
  adduser -S shairport-sync -G shairport-sync; \
  fi

# set version label
ARG BUILD_DATE
ARG VERSION
ARG SNAPCAST_RELEASE
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
  avahi \
  avahi-tools \
  libconfig \
  libplist \
  libsndfile \
  soxr \
  popt \
  librespot@testing \
  shairport-sync@testing \
  snapcast@testing \
  snapweb@testing \
  && echo "**** cleanup ****" \
  && rm -rf \
  /tmp/*

# environment settings
ENV \
  START_SNAPCLIENT=false \
  START_AIRPLAY=true \
  SNAPCLIENT_OPTS="" \
  SNAPSERVER_OPTS=""

# copy local files
COPY root/ /

# ports and volumes
EXPOSE 1704
EXPOSE 1780

VOLUME /config /data