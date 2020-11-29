FROM debian:testing-20201012-slim as builder

# Fluent Bit version
ENV FLB_VERSION 1.5.7
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && \
    apt-get -y dist-upgrade && \
    apt-get install -y --no-install-recommends \
      build-essential \
      cmake \
      make \
      curl \
      unzip \
      libssl-dev \
      libasl-dev \
      libsasl2-dev \
      pkg-config \
      libsystemd-dev \
      zlib1g-dev \
      ca-certificates \
      flex \
      bison \
      file

RUN mkdir -p /fluent-bit/bin /fluent-bit/etc /fluent-bit/log /tmp/src/
RUN curl -sSL https://github.com/fluent/fluent-bit/archive/v${FLB_VERSION}.tar.gz | \
    tar zx --strip=1 -C /tmp/src/

# Single http post patch
RUN rm -rf /tmp/src/plugins/out_http
COPY patch/out_http /patch/out_http
RUN mv /patch/out_http /tmp/src/plugins/out_http
# End single http post patch

# RUN rm -rf /tmp/src/build/*

WORKDIR /tmp/src/build/
RUN cmake -DFLB_DEBUG=Off \
          -DFLB_TRACE=Off \
          -DFLB_JEMALLOC=On \
          -DFLB_BUFFERING=On \
          -DFLB_TLS=On \
          -DFLB_SHARED_LIB=Off \
          -DFLB_EXAMPLES=Off \
          -DFLB_HTTP_SERVER=On \
          -DFLB_IN_SYSTEMD=On \
          -DFLB_OUT_KAFKA=On ..

RUN make -j $(getconf _NPROCESSORS_ONLN)
RUN install bin/fluent-bit /fluent-bit/bin/

# Configuration files
WORKDIR /tmp/src/
RUN mkdir /fluent-bit/lib
RUN cp conf/fluent-bit.conf \
       conf/parsers.conf \
       conf/parsers_java.conf \
       conf/parsers_extra.conf \
       conf/parsers_openstack.conf \
       conf/parsers_cinder.conf \
       conf/plugins.conf \
       /fluent-bit/etc/


FROM debian:testing-20201012-slim

RUN apt-get update && \
    apt-get -y dist-upgrade && \
    apt-get install -y --no-install-recommends \
        libsasl2-2 \
        libssl1.1 \
        ca-certificates && \
    rm -rf /var/lib/apt/lists

COPY --from=builder /fluent-bit /fluent-bit

EXPOSE 2020


CMD ["/fluent-bit/bin/fluent-bit","-c", "/fluent-bit/etc/fluent-bit.conf"]
