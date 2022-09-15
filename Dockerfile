FROM golang:stretch

ARG RELEASE=v0.0.1
ARG PODMAN_VERSION=v4.2.1
ARG RUNC_VERSION=v1.1.4
ARG CONMON_VERSION=v2.1.4
ARG CNI_VERSION=v1.1.1

# Set buildtags for runc and podman
ENV BUILDTAGS="exclude_graphdriver_devicemapper exclude_graphdriver_btrfs seccomp containers_image_openpgp systemd"

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

# Create folders
RUN mkdir -p /build \
    && mkdir -p /tmp/release \
    && mkdir -p /tmp/release/etc/cni/net.d \
    && mkdir -p /tmp/release/etc/containers \
    && mkdir -p /tmp/release/usr/bin \
    && mkdir -p /tmp/release/usr/libexec/podman \
    && mkdir -p /tmp/release/usr/share/containers \
    && mkdir -p /tmp/release/opt/cni/bin

# Checkout projects
WORKDIR /build
RUN git clone --branch ${CONMON_VERSION} https://github.com/containers/conmon.git \
    && git clone --branch ${RUNC_VERSION} https://github.com/opencontainers/runc.git \
    && git clone --branch ${PODMAN_VERSION} https://github.com/containers/podman.git

# Build conmon
RUN cd conmon \
    && make \
    && cp bin/conmon /tmp/release/usr/libexec/podman/conmon \
    && cd ..


# Build runc
RUN cd runc \
    && make \
    && cp ./runc /tmp/release/usr/bin/runc \
    && cd ..

# Build podman
RUN cd podman \
    && make \
    && cp ./bin/* /tmp/release/usr/bin/ \
    && cp vendor/github.com/containers/common/pkg/seccomp/seccomp.json /tmp/release/usr/share/containers/seccomp.json \
    && cp cni/87-podman-bridge.conflist /tmp/release/etc/cni/net.d/87-podman-bridge.conflist \
    && cp vendor/github.com/containers/storage/storage.conf /tmp/release/etc/containers/storage.conf \
    && cp test/registries.conf /tmp/release/etc/containers/registries.conf \
    && cp test/policy.json /tmp/release/etc/containers/policy.json \
    && cd ..

# Download cni plugins
RUN curl -fsSLO https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-linux-arm64-${CNI_VERSION}.tgz \ 
    && tar zxvf cni-plugins-linux-arm64-${CNI_VERSION}.tgz -C /tmp/release/opt/cni/bin

RUN tar czvf /tmp/podman-${RELEASE}.tar.gz -C /tmp/release .
