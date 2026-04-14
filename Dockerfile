FROM ghcr.io/linuxserver/shairport-sync:latest AS shairport-source

FROM ghcr.io/linuxserver/baseimage-alpine:edge AS nqptp-builder

RUN apk add --no-cache \
    git autoconf automake libtool g++ make pkgconfig

RUN git clone --depth=1 https://github.com/mikebrady/nqptp.git /tmp/nqptp \
  && cd /tmp/nqptp \
  && autoreconf -fi \
  && ./configure \
  && make \
  && strip nqptp

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
  libgcrypt \
  ffmpeg \
  librespot@testing \
  snapcast@testing \
  snapweb@testing \
  && echo "**** cleanup ****" \
  && rm -rf /tmp/*

# Copy shairport-sync binary from official linuxserver image (has AirPlay 2)
COPY --from=shairport-source /usr/bin/shairport-sync /usr/bin/shairport-sync

# Copy nqptp built from source
COPY --from=nqptp-builder /tmp/nqptp/nqptp /usr/bin/nqptp

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
