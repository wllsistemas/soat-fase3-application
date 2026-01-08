FROM php:8.4-fpm-alpine3.22

WORKDIR /var/www/html

RUN apk update && apk upgrade

RUN apk add --no-cache \
    ca-certificates \
    curl \
    zip \
    git \
    unzip \
    libpq-dev \
    bash \
    libstdc++

# Dependências de build (mantém até terminar tudo)
RUN apk add --no-cache --virtual .build-deps \
    autoconf \
    g++ \
    make \
    linux-headers

RUN apk add --no-cache \
    && pecl install xdebug \
    && docker-php-ext-enable xdebug \
    && echo "xdebug.mode=coverage,develop" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    && rm -rf /var/lib/apk/lists/* 

# Datadog PHP tracer (ddtrace)
RUN curl -fsSL https://github.com/DataDog/dd-trace-php/releases/latest/download/datadog-setup.php -o /tmp/datadog-setup.php \
    && php /tmp/datadog-setup.php --php-bin=all --enable-profiling=0 \
    && rm -f /tmp/datadog-setup.php \
    && php --ri ddtrace | head -n 3

RUN docker-php-ext-install pdo_pgsql && docker-php-ext-enable pdo_pgsql

# Limpa deps de build no final
RUN apk del .build-deps \
    && rm -rf /var/cache/apk/*


RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

COPY ./build/backend/startup.sh /usr/local/bin/startup.sh
RUN chmod +x /usr/local/bin/startup.sh

RUN sed -i 's/\r$//' /usr/local/bin/startup.sh

COPY ./backend .

# RUN chown -R www-data:www-data /var/www/html/storage \
#     && chmod -R 775 /var/www/html/storage

ENTRYPOINT ["/usr/local/bin/startup.sh"]
