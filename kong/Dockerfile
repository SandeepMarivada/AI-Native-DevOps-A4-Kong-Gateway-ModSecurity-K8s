FROM kong:3.4
USER root
RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    libpcre2-dev \
    libxml2 libxml2-dev \
    libcurl4-openssl-dev \
    liblua5.1-0-dev \
    libssl-dev \
    wget \
    autoconf \
    automake \
    libtool \
    && rm -rf /var/lib/apt/lists/*

# Install ModSecurity v3
WORKDIR /tmp
RUN git clone --depth 1 -b v3/master --single-branch https://github.com/SpiderLabs/ModSecurity /tmp/ModSecurity && \
    cd /tmp/ModSecurity && \
    git submodule update --init --recursive && \
    sh build.sh && \
    ./configure && \
    make && \
    make install

# Get NGINX version from Kong
RUN nginx -V 2>&1 | grep "nginx version" | cut -d'/' -f2 > /tmp/nginx_version.txt && \
    NGINX_VERSION=$(cat /tmp/nginx_version.txt) && \
    echo "NGINX Version: $NGINX_VERSION"

# Clone ModSecurity-nginx connector
RUN git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git /tmp/ModSecurity-nginx

# Download PCRE for OpenResty compilation
RUN wget https://sourceforge.net/projects/pcre/files/pcre/8.45/pcre-8.45.tar.gz && \
    tar -xzf pcre-8.45.tar.gz

# Get OpenResty version and compile ModSecurity module
RUN OPENRESTY_VERSION=$(nginx -V 2>&1 | grep -oP 'openresty/\K[0-9.]+') && \
    wget https://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz && \
    tar -xzf openresty-${OPENRESTY_VERSION}.tar.gz && \
    cd openresty-${OPENRESTY_VERSION} && \
    ./configure --with-compat --with-pcre=/tmp/pcre-8.45 --add-dynamic-module=/tmp/ModSecurity-nginx && \
    gmake && \
    find . -name "ngx_http_modsecurity_module.so" -exec cp {} /usr/local/lib/ \;

# Download OWASP Core Rule Set
RUN wget https://github.com/coreruleset/coreruleset/archive/v3.3.4.tar.gz && \
    tar -xvzf v3.3.4.tar.gz && \
    mv coreruleset-3.3.4 /usr/local/owasp-modsecurity-crs && \
    cp /usr/local/owasp-modsecurity-crs/crs-setup.conf.example /usr/local/owasp-modsecurity-crs/crs-setup.conf

# Configure ModSecurity
RUN mkdir -p /etc/modsecurity && \
    cp /tmp/ModSecurity/modsecurity.conf-recommended /etc/modsecurity/modsecurity.conf && \
    cp /tmp/ModSecurity/unicode.mapping /etc/modsecurity/ && \
    sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine On/' /etc/modsecurity/modsecurity.conf

# Create ModSecurity main config (excluding GeoIP rules)
RUN echo "Include /etc/modsecurity/modsecurity.conf" > /etc/modsecurity/main.conf && \
    echo "Include /usr/local/owasp-modsecurity-crs/crs-setup.conf" >> /etc/modsecurity/main.conf && \
    for rule in /usr/local/owasp-modsecurity-crs/rules/*.conf; do \
        if [ "$(basename $rule)" != "REQUEST-910-IP-REPUTATION.conf" ]; then \
            echo "Include $rule" >> /etc/modsecurity/main.conf; \
        fi; \
    done

# Add ModSecurity module to Kong's nginx config template
RUN mkdir -p /usr/local/kong/nginx-includes && \
    echo "load_module /usr/local/lib/ngx_http_modsecurity_module.so;" > /usr/local/kong/nginx-includes/modsec_load.conf && \
    chown -R kong:kong /usr/local/kong/nginx-includes

# Copy custom Kong plugins
COPY --chown=kong:kong kong/plugins/request-enrichment /usr/local/share/lua/5.1/kong/plugins/request-enrichment

# Enable custom plugins in Kong
ENV KONG_PLUGINS=bundled,request-enrichment

USER kong
