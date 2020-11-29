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
      libjemalloc-dev \
      libsystemd-dev \
      zlib1g-dev \
      ca-certificates \
      flex \
      bison \
      file

RUN mkdir -p /fluent-bit/bin /fluent-bit/etc /fluent-bit/log /tmp/src/
RUN curl -sSL https://github.com/fluent/fluent-bit/archive/v${FLB_VERSION}.tar.gz | \
    tar zx --strip=1 -C /tmp/src/


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

# Add dummy plugin
# RUN rm -rf /fluent-bit-plugin
# COPY fluent-bit-plugin /fluent-bit-plugin
# RUN mkdir -p /fluent-bit-plugin/build/
# WORKDIR /fluent-bit-plugin/build/
# RUN cmake -DFLB_SOURCE=/tmp/src -DPLUGIN_NAME=out_stdout2  ../
# RUN make MALLOC=libc  -j $(getconf _NPROCESSORS_ONLN)
# End dummy plugin

# Add sequentialhttp
RUN rm -rf /plugin
COPY plugin /plugin
RUN mkdir -p /plugin/build/
WORKDIR /plugin/build/
RUN cmake -DFLB_SOURCE=/tmp/src -DPLUGIN_NAME=out_sequentialhttp  ../
RUN make -j $(getconf _NPROCESSORS_ONLN)
# End sequentialhttp

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
# dummy plugin
# COPY --from=builder /fluent-bit-plugin /fluent-bit-plugin
COPY --from=builder /plugin /plugin
EXPOSE 2020

# DUMMY plugin
#CMD ["/fluent-bit/bin/fluent-bit", "-e", "/fluent-bit-plugin/build/flb-out_stdout2.so","-c", "/fluent-bit/etc/fluent-bit.conf"]
CMD ["/fluent-bit/bin/fluent-bit", "-e", "/plugin/build/flb-out_sequentialhttp.so","-c", "/fluent-bit/etc/fluent-bit.conf"]
