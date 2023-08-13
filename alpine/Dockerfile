FROM alpine:3 as builder

# Install build requirements
RUN apk add --upgrade --latest alpine-sdk cmake linux-headers unzip perl

ARG OPENSSL_VERSION="openssl-${OPENSSL_VERSION:-3.1.2}"
ARG NGINX_VERSION="${NGINX_VERSION:-1.25.1}"
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
  && make install \
  && cp -rv "/usr/local/src/${OPENSSL_VERSION}/crypto" "${OPENSSL_DIR}/"

# Modify OpenSSL conf for GOST engine
RUN sed -i 's/openssl_conf = openssl_init/openssl_conf = openssl_def/g' "${OPENSSL_DIR}/openssl.cnf" \
  && echo "# GOST TLS Engine Config" >> "${OPENSSL_DIR}/openssl.cnf" \
  && echo "# OpenSSL default section" >> y \
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
RUN apk del alpine-sdk unzip perl --purge \
  && apk cache clean \
  && rm -rf /usr/local/src/*

# Create a squashed image
FROM scratch

COPY --from=builder / /

