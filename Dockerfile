# ARGs for versions
ARG PHP_VERSION="8.5"
ARG COMPOSER_VERSION=2
ARG COMPOSER_AUTH
ARG NGINX_VERSION=1.25
ARG APP_CODE_PATH="."

# -------------------------------------------------- Composer Image ----------------------------------------------------
FROM composer:${COMPOSER_VERSION} as composer

# ======================================================================================================================
#                                                   --- Base ---
# ======================================================================================================================
FROM php:${PHP_VERSION}-fpm-alpine AS base

# Maintainer label
LABEL maintainer="soteris100@gmail.com"

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

# ------------------------------------- Install Packages Needed Inside Base Image --------------------------------------
RUN apk add --no-cache tini zip fcgi

# ---------------------------------------- Install / Enable PHP Extensions ---------------------------------------------
# Note: As of PHP 8.5, PECL is deprecated in favor of PIE (PHP Installer for Extensions)
# The install-php-extensions script handles this transition automatically
# See: https://github.com/php/pie for more information about PIE
ARG PHP_EXTENSIONS
ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/
RUN chmod +x /usr/local/bin/install-php-extensions && \
    install-php-extensions ${PHP_EXTENSIONS}

# ------------------------------------------------- Install Node.js and npm --------------------------------------------
RUN apk add --no-cache nodejs npm

# ------------------------------------------------- Permissions --------------------------------------------------------
RUN deluser --remove-home www-data && adduser -u1000 -D www-data && rm -rf /var/www /usr/local/etc/php-fpm.d/* && \
    mkdir -p /var/www/.composer /webdata && chown -R www-data:www-data /webdata /var/www/.composer

# ------------------------------------------------ PHP Configuration ---------------------------------------------------
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

COPY phpdock/php/base-php.ini $PHP_INI_DIR/conf.d

# ---------------------------------------------- PHP FPM Configuration -------------------------------------------------
COPY phpdock/php/fpm.conf /usr/local/etc/php-fpm.d/

# --------------------------------------------------- Scripts ----------------------------------------------------------
COPY phpdock/php/scripts/*-base \
     phpdock/php/scripts/php-fpm-healthcheck \
     phpdock/php/scripts/command-loop \
     /usr/local/bin/

RUN chmod +x /usr/local/bin/*-base /usr/local/bin/php-fpm-healthcheck /usr/local/bin/command-loop

# ---------------------------------------------------- Composer --------------------------------------------------------
COPY --from=composer /usr/bin/composer /usr/bin/composer

# ----------------------------------------------------- MISC -----------------------------------------------------------
WORKDIR /webdata
USER www-data

# Common PHP Frameworks Env Variables
ENV APP_ENV prod
ENV APP_DEBUG 0

RUN php-fpm -t

# ---------------------------------------------------- HEALTH ----------------------------------------------------------
HEALTHCHECK CMD ["php-fpm-healthcheck"]

# -------------------------------------------------- ENTRYPOINT --------------------------------------------------------
ENTRYPOINT ["entrypoint-base"]
CMD ["php-fpm"]

## ======================================================================================================================
## ==============================================  PRODUCTION IMAGE  ====================================================
## ======================================================================================================================

FROM composer as vendor

ARG PHP_VERSION
ARG COMPOSER_AUTH
ARG APP_CODE_PATH
ENV COMPOSER_AUTH $COMPOSER_AUTH

WORKDIR /webdata

COPY $APP_CODE_PATH/composer.json composer.json
COPY $APP_CODE_PATH/composer.lock composer.lock

RUN composer config platform.php ${PHP_VERSION}
RUN composer install -n --no-progress --ignore-platform-reqs --no-dev --prefer-dist --no-scripts --no-autoloader

FROM base AS php-prod

ARG APP_CODE_PATH
USER root

COPY phpdock/php/scripts/*-prod /usr/local/bin/
RUN chmod +x /usr/local/bin/*-prod
COPY phpdock/php/prod-* $PHP_INI_DIR/conf.d/

USER www-data
COPY --chown=www-data:www-data --from=vendor /webdata/vendor /webdata/vendor
COPY --chown=www-data:www-data $APP_CODE_PATH .

RUN post-build-prod
ENTRYPOINT ["entrypoint-prod"]
CMD ["php-fpm"]

## ======================================================================================================================
## ==============================================  DEVELOPMENT IMAGE  ===================================================
## ======================================================================================================================

FROM base as php-dev

ENV APP_ENV dev
ENV APP_DEBUG 1

USER root

# Install development tools
RUN apk add git openssh vim github-cli;

# Install Xdebug
# Note: Ensure xdebug is compatible with PHP 8.5 - check https://xdebug.org/docs/compat
ENV XDEBUG_CLIENT_HOST=172.17.0.1
ENV XDEBUG_IDE_KEY=myide
ENV PHP_IDE_CONFIG="serverName=${XDEBUG_IDE_KEY}"
RUN install-php-extensions xdebug


# Install Laravel installer with all dependencies
#RUN mkdir -p /opt/laravel-installer && \
#    cd /opt/laravel-installer && \
#    echo '{"require": {"laravel/installer": "^5.2"}}' > composer.json && \
#    composer install && \
#    ln -s /opt/laravel-installer/vendor/bin/laravel /usr/local/bin/laravel

COPY phpdock/php/scripts/*-dev /usr/local/bin/
RUN chmod +x /usr/local/bin/*-dev
RUN mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"
COPY phpdock/php/dev-* $PHP_INI_DIR/conf.d/

USER www-data
ENTRYPOINT ["entrypoint-dev"]
CMD ["php-fpm"]

# ======================================================================================================================
# ======================================================================================================================
#                                                  --- NGINX ---
# ======================================================================================================================
# ======================================================================================================================
FROM nginx:${NGINX_VERSION}-alpine AS nginx

RUN rm -rf /var/www/* /etc/nginx/conf.d/* && adduser -u 1000 -D -S -G www-data www-data
COPY phpdock/nginx/nginx-* /usr/local/bin/
COPY phpdock/nginx/ /etc/nginx/
RUN chown -R www-data /etc/nginx/ && chmod +x /usr/local/bin/nginx-*

ENV PHP_FPM_HOST "localhost"
ENV PHP_FPM_PORT "9000"
ENV NGINX_LOG_FORMAT "json"

USER www-data

HEALTHCHECK CMD ["nginx-healthcheck"]

ENTRYPOINT ["nginx-entrypoint"]

# ======================================================================================================================
#                                                 --- NGINX PROD ---
# ======================================================================================================================
FROM nginx AS nginx-prod

EXPOSE 8080

USER root

RUN SECURITY_UPGRADES="curl"; \
    apk add --no-cache --upgrade ${SECURITY_UPGRADES}

USER www-data

COPY --chown=www-data:www-data --from=php-prod /webdata/public /webdata/public

# ======================================================================================================================
#                                                 --- NGINX DEV ---
# ======================================================================================================================
FROM nginx AS nginx-dev

EXPOSE 80 443

ENV NGINX_LOG_FORMAT "combined"

COPY --chown=www-data:www-data phpdock/nginx/dev/*.conf /etc/nginx/conf.d/
COPY --chown=www-data:www-data phpdock/nginx/dev/certs/ /etc/nginx/certs/