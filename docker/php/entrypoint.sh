#!/bin/bash
set -e

# first arg is `-f` or `--some-option`
if [ "${1#-}" != "$1" ]; then
	set -- php-fpm "$@"
fi

if [ "true" == "$XDEBUG_DISABLE" ]; then
	if [ -e /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini ]; then
		rm -f /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini
	fi
fi

exec docker-php-entrypoint "$@"
