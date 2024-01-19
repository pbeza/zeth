FROM rust:1.75.0 as builder

ENV DEBIAN_FRONTEND=noninteractive
ARG BUILD_FLAGS=""
WORKDIR /opt/raiko
COPY . .
RUN apt-get update && \
    apt-get install -y \
        cmake \
        libclang-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
RUN cargo build --release ${BUILD_FLAGS}

FROM gramineproject/gramine:1.6-jammy as runtime
WORKDIR /opt/raiko

RUN apt-get update && \
    apt-get install -y sudo && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p \
    ./bin \
    ./guests/sgx \
    /root/.config/raiko/config \
    /root/.config/raiko/secrets \
    /tmp/sgx \
    /var/log/raiko

COPY --from=builder /opt/raiko/target/release/raiko-guest ./guests/sgx
COPY --from=builder /opt/raiko/raiko-guest/config/raiko-guest.manifest.template ./guests/sgx
COPY --from=builder /opt/raiko/target/release/raiko-host ./bin
COPY --from=builder /opt/raiko/raiko-host/config/config.toml /root/.config/raiko/config
COPY --from=builder /opt/raiko/docker/entrypoint.sh ./bin
COPY ./sgx-ra/src/*.so /usr/lib/

RUN cd ./guests/sgx && \
    gramine-manifest -Dlog_level=error -Darch_libdir=/lib/x86_64-linux-gnu/ raiko-guest.manifest.template raiko-guest.manifest && \
    gramine-sgx-gen-private-key && \
    gramine-sgx-sign --manifest raiko-guest.manifest --output raiko-guest.manifest.sgx && \
    cd -

ENTRYPOINT [ "/opt/raiko/bin/entrypoint.sh" ]
