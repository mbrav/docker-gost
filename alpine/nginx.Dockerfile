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

# Install build requirements for nginx
RUN apk add --upgrade --latest pcre-dev zlib-dev

# Download nginx
RUN cd /usr/local/src \
  && curl -L -o "nginx-${NGINX_VERSION}.tar.gz" "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" \
  && tar -zxvf "nginx-${NGINX_VERSION}.tar.gz" \
  && rm "nginx-${NGINX_VERSION}.tar.gz"

# Build nginx 
RUN cd "/usr/local/src/nginx-${NGINX_VERSION}" \
  && ./configure \
  --prefix=/etc/nginx \
  --sbin-path=/usr/sbin/nginx \
  --modules-path=/usr/lib/nginx/modules \
  --conf-path=/etc/nginx/nginx.conf \
  --error-log-path=/var/log/nginx/error.log \
  --http-log-path=/var/log/nginx/access.log \
  --pid-path=/var/run/nginx.pid \
  --lock-path=/var/run/nginx.lock \
  --http-client-body-temp-path=/var/cache/nginx/client_temp \
  --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
  --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
  --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
  --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
  --user=www-data \
  --group=www-data \
  --with-compat \
  --with-file-aio \
  --with-threads \
  --with-http_addition_module \
  --with-http_auth_request_module \
  --with-http_dav_module \
  --with-http_flv_module \
  --with-http_gunzip_module \
  --with-http_gzip_static_module \
  --with-http_mp4_module \
  --with-http_random_index_module \
  --with-http_realip_module \
  --with-http_secure_link_module \
  --with-http_slice_module \
  --with-http_ssl_module \
  --with-http_stub_status_module \
  --with-http_sub_module \
  --with-http_v2_module \
  --with-mail \
  --with-mail_ssl_module \
  --with-stream \
  --with-stream_realip_module \
  --with-stream_ssl_module \
  --with-stream_ssl_preread_module \
  --with-openssl="/usr/local/src/${OPENSSL_VERSION}" \
  && make -j "$(nproc)" \
  && make install \
  && mkdir -p \
  /var/cache/nginx/client_temp \
  /var/cache/nginx/proxy_temp \
  /var/cache/nginx/fastcgi_temp \
  /var/cache/nginx/uwsgi_temp \
  /var/cache/nginx/scgi_temp \
  # Forward request and error logs to docker log collector
  && touch /var/log/nginx/access.log /var/log/nginx/error.log \
  && ln -sf /dev/stdout /var/log/nginx/access.log \
  && ln -sf /dev/stderr /var/log/nginx/error.log

# Clean 
RUN apk del alpine-sdk unzip perl --purge \
  && apk cache clean \
  && rm -rf /usr/local/src/*

# Create a squashed image
FROM scratch

COPY --from=builder / /

STOPSIGNAL SIGTERM

CMD ["nginx", "-g", "daemon off;"]
