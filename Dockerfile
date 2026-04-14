FROM ghcr.io/linuxserver/baseimage-alpine:edge AS builder

# Install build dependencies for librespot
RUN apk add --no-cache \
  cargo \
  rust \
  alsa-lib-dev \
  protobuf-dev \
  openssl-dev

# Build librespot from source
ARG LIBRESPOT_RELEASE=0.8.0
RUN cargo install librespot --version ${LIBRESPOT_RELEASE} \
  --no-default-features \
  --features alsa-backend,rustls-tls-native-roots,with-libmdns

# Build shairport-sync
FROM builder AS shairport-builder
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
  libsoxr-dev \
  git

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

# Create shairport-sync user
RUN addgroup -g 1000 -S shairport-sync && \
  adduser -u 1000 -S shairport-sync -G shairport-sync

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
  avahi \
  avahi-tools \
  libconfig \
  libplist \
  libsndfile \
  libsoxr \
  popt \
  snapcast@testing \
  snapweb@testing \
  && echo "**** cleanup ****" \
  && rm -rf \
  /tmp/*

# Copy librespot binary from builder stage
COPY --from=builder /root/.cargo/bin/librespot /usr/bin/librespot
# Copy shairport-sync from builder
COPY --from=shairport-builder /tmp/shairport-install/usr/bin/shairport-sync /usr/bin/shairport-sync
COPY --from=shairport-builder /tmp/shairport-install/etc/dbus-1/system.d/shairport-sync-dbus.conf /etc/dbus-1/system.d/

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