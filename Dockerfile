FROM ghcr.io/linuxserver/baseimage-alpine:edge AS builder

# Install build dependencies for shairport-sync and nqptp
RUN apk add --no-cache \
    git autoconf automake libtool g++ make pkgconfig \
    avahi-dev openssl-dev libconfig-dev popt-dev soxr-dev \
    libplist libplist-dev libsodium-dev alsa-lib-dev dbus-dev

# Build nqptp — required by shairport-sync for AirPlay 2 timing
RUN git clone --depth=1 https://github.com/mikebrady/nqptp.git /tmp/nqptp \
  && cd /tmp/nqptp \
  && autoreconf -fi \
  && ./configure \
  && make \
  && strip nqptp

# Build shairport-sync from source with AirPlay 2 support
# The Alpine package omits --with-airplay-2; we build it ourselves
RUN git clone --depth=1 https://github.com/mikebrady/shairport-sync.git /tmp/shairport-sync \
  && cd /tmp/shairport-sync \
  && autoreconf -fi \
  && ./configure \
      --with-avahi \
      --with-ssl=openssl \
      --with-airplay-2 \
      --with-soxr \
      --with-metadata \
      --with-dbus-interface \
      --with-mpris-interface \
      --with-stdout \
      --with-pipe \
      --sysconfdir=/etc \
  && make \
  && strip shairport-sync

# ── runtime image ────────────────────────────────────────────────────────────
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
  libsodium \
  librespot@testing \
  snapcast@testing \
  snapweb@testing \
  && echo "**** cleanup ****" \
  && rm -rf \
  /tmp/*

# Copy custom-built binaries (with AirPlay 2) over the Alpine package versions
COPY --from=builder /tmp/shairport-sync/shairport-sync /usr/bin/shairport-sync
COPY --from=builder /tmp/nqptp/nqptp /usr/bin/nqptp

# environment settings
ENV \
  START_SNAPCLIENT=false \
  START_AIRPLAY=true \
  SNAPCLIENT_OPTS="" \
  SNAPSERVER_OPTS=""

# copy local files
COPY root/ /
RUN chmod +x /etc/s6-overlay/s6-rc.d/svc-nqptp/run

# ports and volumes
EXPOSE 1704
EXPOSE 1780

VOLUME /config /data
