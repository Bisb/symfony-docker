ARG PHP_VERSION=8.0

# php
FROM php:${PHP_VERSION}-fpm-alpine

COPY docker/php/php.ini $PHP_INI_DIR/conf.d/

RUN apk add --no-cache \
        acl \
        fcgi \
        file \
        gettext \
        git \
        jq \
        bash \
    ;

RUN set -eux; \
	apk add --no-cache --virtual .build-deps \
	    $PHPIZE_DEPS \
	    icu-dev \
	    libzip-dev \
	    zlib-dev \
	; \
	\
	docker-php-ext-configure zip; \
	docker-php-ext-install -j$(nproc) \
	    intl \
	    zip \
	    mysqli \
	    pdo \
	    pdo_mysql \
	; \
	pecl install \
	    apcu \
	    xdebug \
	; \
	pecl clear-cache; \
	docker-php-ext-enable \
	    apcu \
	    opcache \
	    xdebug \
	; \
	\
	runDeps="$( \
	    scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
	        | tr ',' '\n' \
	        | sort -u \
	        | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	)"; \
	apk add --no-cache --virtual .phpexts-rundeps $runDeps; \
	\
	apk del .build-deps

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
ENV COMPOSER_ALLOW_SUPERUSER=1
ENV PATH="${PATH}:/root/.composer/vendor/bin"

WORKDIR /root
RUN curl -L https://github.com/symfony-cli/symfony-cli/releases/download/v5.4.13/symfony-cli_5.4.13_x86_64.apk -o symfony.apk \
    && apk add --allow-untrusted symfony.apk \
    && rm symfony.apk

WORKDIR /var/www/html

COPY docker/php/entrypoint.sh /usr/local/bin/docker-entrypoint
RUN chmod +x /usr/local/bin/docker-entrypoint

ENTRYPOINT ["/usr/local/bin/docker-entrypoint"]
CMD ["php-fpm"]
