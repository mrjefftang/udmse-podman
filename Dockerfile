FROM golang:stretch

ARG RELEASE=v0.0.1
ARG PODMAN_VERSION=v4.2.1
ARG RUNC_VERSION=v1.1.4
ARG CONMON_VERSION=v2.1.4
ARG CNI_VERSION=v1.1.1

# Install backports
RUN echo "deb http://deb.debian.org/debian stretch-backports main contrib non-free" >> /etc/apt/sources.list.d/backports.list

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        git \
        golang-go \
        go-md2man \
        iptables \
        libassuan-dev \
        libc6-dev \
        libdevmapper-dev \
        libglib2.0-dev \
        libprotobuf-dev \
        libprotobuf-c-dev \
        libseccomp-dev \
        libselinux1-dev \
        libsystemd-dev \
        pkg-config \
        runc \
        uidmap \
    && rm -rf /var/lib/apt/lists/*

# Set build environment
ENV CGO_ENABLED=1 \
    GOOS="linux" \
    GOARCH="arm64" \
    DESTDIR="/build/release" \
    PREFIX="/usr/local" \
    BINDIR="/usr/local/bin" \
    LIBDIR="/usr/local/lib" \
    SYSTEMDDIR="/etc/systemd/system" \
    USERSYSTEMDDIR="../../tmp" \
    USERTMPFILESDIR="../../tmp" \
    TMPFILESDIR="../../tmp" \
    ETCDIR="/etc" \
    BUILDTAGS="exclude_graphdriver_devicemapper exclude_graphdriver_btrfs seccomp containers_image_openpgp systemd"

# Create folders
RUN mkdir -p /build \
    && mkdir -p ${DESTDIR} \
    && mkdir -p ${DESTDIR}/etc/cni/net.d \
    && mkdir -p ${DESTDIR}/etc/containers \
    && mkdir -p ${DESTDIR}${BINDIR} \
    && mkdir -p ${DESTDIR}${LIBDIR}/cni \
    && mkdir -p ${DESTDIR}/usr/share/containers \
    && mkdir -p ${DESTDIR}/ssd1/podman/run/containers/storage \
    && mkdir -p ${DESTDIR}/ssd1/podman/containers/storage

# Checkout projects
WORKDIR /build
RUN git clone --branch ${CONMON_VERSION} https://github.com/containers/conmon.git \
    && git clone --branch ${RUNC_VERSION} https://github.com/opencontainers/runc.git \
    && git clone --branch ${PODMAN_VERSION} https://github.com/containers/podman.git

# Build conmon
RUN cd conmon \
    && make bin/conmon install.podman \
    && cd ..

# Build runc
RUN cd runc \
    && make runc install \
    && cd ..

# Build podman
RUN cd podman \
    && make podman rootlessport install.bin install.systemd \
    && cp vendor/github.com/containers/common/pkg/seccomp/seccomp.json ${DESTDIR}/usr/share/containers/seccomp.json \
    && cp cni/87-podman-bridge.conflist ${DESTDIR}${ETCDIR}/cni/net.d/87-podman-bridge.conflist \
    && cp test/policy.json ${DESTDIR}${ETCDIR}/containers/policy.json \
    && cd ..

COPY registries.conf ${DESTDIR}${ETCDIR}/containers/registries.conf 
COPY storage.conf ${DESTDIR}${ETCDIR}/containers/storage.conf 

# Download cni plugins
RUN curl -fsSLO https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-linux-arm64-${CNI_VERSION}.tgz \ 
    && tar zxf cni-plugins-linux-arm64-${CNI_VERSION}.tgz -C ${DESTDIR}${LIBDIR}/cni

# Cleanup

# Build tarball
RUN tar czf udmse-podman-${RELEASE}.tar.gz -C ${DESTDIR} .
