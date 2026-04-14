FROM ghcr.io/linuxserver/baseimage-alpine:edge AS builder

# Install build dependencies for shairport-sync only (librespot will use Alpine package)
RUN apk add --no-cache \
  alpine-sdk \
  autoconf \
  automake \
  libtool \
  dbus-dev \
  popt-dev \
  openssl-dev \
  libconfig-dev \
  avahi-dev \
  libplist-dev \
  libsndfile-dev \
  git

# Build shairport-sync from source
RUN git clone https://github.com/mikebrady/shairport-sync.git /tmp/shairport-sync && \
  cd /tmp/shairport-sync && \
  git checkout 4.3.5 && \
  autoreconf -fi && \
  ./configure \
  --prefix=/usr \
  --sysconfdir=/etc \
  --with-alsa \
  --with-avahi \
  --with-ssl=openssl \
  --with-metadata \
  --with-dbus-interface \
  --with-mpris-interface \
  --with-pipe \
  --with-stdout && \
  make -j$(nproc) && \
  make install DESTDIR=/tmp/shairport-install

# Final stage
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
  snapcast@testing \
  snapweb@testing \
  && echo "**** cleanup ****" \
  && rm -rf \
  /tmp/*

# Copy shairport-sync from builder
COPY --from=builder /tmp/shairport-install/usr/bin/shairport-sync /usr/bin/shairport-sync
COPY --from=builder /tmp/shairport-install/etc/dbus-1/system.d/shairport-sync-dbus.conf /etc/dbus-1/system.d/

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