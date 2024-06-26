FROM debian:bookworm-slim as builder

# Install build requirements
RUN apt-get update \
  && apt-get install build-essential cmake curl unzip ca-certificates git --no-install-recommends -y

ARG OPENSSL_VERSION="openssl-${OPENSSL_VERSION:-3.3.0}"
ARG NGINX_VERSION="${NGINX_VERSION:-1.25.4}"
ENV OPENSSL_DIR="/usr/local/ssl"
ENV OPENSSL_LIB="/usr/local/lib64"
ENV OPENSSL_ENGINES="/usr/local/lib64/engines-3"
ENV OPENSSL_INCLUDES="/usr/local/include/openssl"

# Download OpenSSL with GOST TLS git module 
RUN mkdir -p /usr/local/src \
  && cd /usr/local/src \
  && git clone -b "${OPENSSL_VERSION}" --depth 1 https://github.com/openssl/openssl.git "${OPENSSL_VERSION}" \
  && cd "${OPENSSL_VERSION}" \
  && git checkout "${OPENSSL_VERSION}" \
  && git submodule update --init --recursive gost-engine

# Build OpenSSL With GOST engine
RUN cd "/usr/local/src/${OPENSSL_VERSION}" \
  && ./Configure --openssldir="${OPENSSL_DIR}" \
  && make -j "$(nproc)" \
  && make install \
  && cd "/usr/local/src/${OPENSSL_VERSION}/gost-engine" \
  && mkdir build \
  && cd build \
  && cmake \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_FLAGS="-I${OPENSSL_INCLUDES} -L${OPENSSL_LIB}" \
  -DOPENSSL_ROOT_DIR="${OPENSSL_DIR}" \
  -DOPENSSL_LIBRARIES="${OPENSSL_LIB}" \
  -DOPENSSL_ENGINES_DIR="${OPENSSL_ENGINES}" .. \
  && cmake --build . --config Release \
  && cmake .. \
  && make install

# Copy some built objects
RUN cp -rv "/usr/local/src/${OPENSSL_VERSION}/crypto" "${OPENSSL_DIR}/" \
  # Link fix
  && rm -v /lib/x86_64-linux-gnu/libcrypto.so.3 \
  && rm -v /lib/x86_64-linux-gnu/libssl.so.3 \
  && ln -s /usr/local/lib64/libcrypto.so.3 /lib/x86_64-linux-gnu/ \
  && ln -s /usr/local/lib64/libssl.so.3 /lib/x86_64-linux-gnu/

# Modify OpenSSL conf for GOST engine
RUN touch "${OPENSSL_DIR}/openssl.cnf" \
  && sed -i 's/openssl_conf = openssl_init/openssl_conf = openssl_def/g' "${OPENSSL_DIR}/openssl.cnf" \
  && echo "# GOST TLS Engine Config" >> "${OPENSSL_DIR}/openssl.cnf" \
  && echo "# OpenSSL default section" >> "${OPENSSL_DIR}/openssl.cnf" \
  && echo "[ openssl_def ]" >> "${OPENSSL_DIR}/openssl.cnf" \
  && echo "engines = engine_section" >> "${OPENSSL_DIR}/openssl.cnf" \
  && echo "" >> "${OPENSSL_DIR}/openssl.cnf" \
  && echo "# Engine section" >> "${OPENSSL_DIR}/openssl.cnf" \
  && echo "[ engine_section ]" >> "${OPENSSL_DIR}/openssl.cnf" \
  && echo "gost = gost_section" >> "${OPENSSL_DIR}/openssl.cnf" \
  && echo "" >> "${OPENSSL_DIR}/openssl.cnf" \
  && echo "# GOST TLS Engine section" >> "${OPENSSL_DIR}/openssl.cnf" \
  && echo "[ gost_section ]" >> "${OPENSSL_DIR}/openssl.cnf" \
  && echo "engine_id = gost" >> "${OPENSSL_DIR}/openssl.cnf" \
  && echo "dynamic_path = ${OPENSSL_ENGINES}/gost.so" >> "${OPENSSL_DIR}/openssl.cnf" \
  && echo "default_algorithms = ALL" >> "${OPENSSL_DIR}/openssl.cnf" \
  && echo "" >> "${OPENSSL_DIR}/openssl.cnf" \
  && cp "${OPENSSL_DIR}/openssl.cnf" /etc/ssl/openssl.cnf

# Clean
RUN apt-get remove build-essential cmake curl unzip git --purge --auto-remove -y \
  && rm -rf /var/lib/apt/lists/* \
  && rm -rf /usr/local/src/*

# Create a squashed image
FROM scratch

WORKDIR /root

COPY --from=builder / /

