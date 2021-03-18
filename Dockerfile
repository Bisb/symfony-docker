ARG PHP_VERSION=8.0
ARG NGINX_VERSION=1.17

# php
FROM php:${PHP_VERSION}-fpm-alpine AS symfony_php
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
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

RUN set -eux; \
	composer global require "symfony/flex" --prefer-dist --no-progress --no-suggest --classmap-authoritative; \
	composer clear-cache
ENV PATH="${PATH}:/root/.composer/vendor/bin"

WORKDIR /root
RUN curl https://get.symfony.com/cli/installer | bash \
	&& mv /root/.symfony/bin/symfony /usr/local/bin/symfony

WORKDIR /var/www/html

# nginx
FROM nginx:${NGINX_VERSION}-alpine AS symfony_nginx
COPY docker/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf
