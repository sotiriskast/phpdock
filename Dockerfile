# ARGs for versions
ARG PHP_VERSION="8.4"
ARG COMPOSER_VERSION=2.8
ARG NGINX_VERSION=1.27
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
ARG PHP_EXTENSIONS
ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/
RUN chmod +x /usr/local/bin/install-php-extensions && \
    install-php-extensions ${PHP_EXTENSIONS}

# ------------------------------------------------- Install Node.js and npm --------------------------------------------
RUN apk add --no-cache \
    --repository=http://dl-cdn.alpinelinux.org/alpine/v3.20/community \
    nodejs npm

# ------------------------------------------------- Permissions --------------------------------------------------------
RUN deluser --remove-home www-data && adduser -u1000 -D www-data && rm -rf /var/www /usr/local/etc/php-fpm.d/* && \
    mkdir -p /var/www/.composer /webdata && chown -R www-data:www-data /webdata /var/www/.composer

# ------------------------------------------------ PHP Configuration ---------------------------------------------------
RUN mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"
COPY php/base-php.ini $PHP_INI_DIR/conf.d

# ---------------------------------------------- PHP FPM Configuration -------------------------------------------------
COPY php/fpm.conf /usr/local/etc/php-fpm.d/

# --------------------------------------------------- Scripts ----------------------------------------------------------
COPY php/scripts/*-base \
     php/scripts/php-fpm-healthcheck \
     php/scripts/command-loop \
     /usr/local/bin/

RUN chmod +x /usr/local/bin/*-base /usr/local/bin/php-fpm-healthcheck /usr/local/bin/command-loop

# ---------------------------------------------------- Composer --------------------------------------------------------
COPY --from=composer /usr/bin/composer /usr/bin/composer

# ----------------------------------------------------- MISC -----------------------------------------------------------
WORKDIR /webdata
USER www-data

# Common PHP Frameworks Env Variables
ENV APP_ENV dev
ENV APP_DEBUG 1

RUN php-fpm -t

# ---------------------------------------------------- HEALTH ----------------------------------------------------------
HEALTHCHECK CMD ["php-fpm-healthcheck"]

# -------------------------------------------------- ENTRYPOINT --------------------------------------------------------
ENTRYPOINT ["entrypoint-base"]
CMD ["php-fpm"]

# ======================================================================================================================
# ==============================================  DEVELOPMENT IMAGE  ===================================================
# ======================================================================================================================

FROM base as php-dev

USER root

# Install development tools
RUN apk add git openssh vim github-cli;

# Install Xdebug
ENV XDEBUG_CLIENT_HOST=172.17.0.1
ENV XDEBUG_IDE_KEY=myide
ENV PHP_IDE_CONFIG="serverName=${XDEBUG_IDE_KEY}"
RUN install-php-extensions xdebug

COPY php/scripts/*-dev /usr/local/bin/
RUN chmod +x /usr/local/bin/*-dev
COPY php/dev-* $PHP_INI_DIR/conf.d/

USER www-data
ENTRYPOINT ["entrypoint-dev"]
CMD ["php-fpm"]

# ======================================================================================================================
# ================================================ --- NGINX --- =======================================================
# ======================================================================================================================
FROM nginx:${NGINX_VERSION}-alpine AS nginx-dev

EXPOSE 80 443
RUN rm -rf /var/www/* /etc/nginx/conf.d/* && adduser -u 1000 -D -S -G www-data www-data
COPY nginx/nginx-* /usr/local/bin/
COPY nginx/ /etc/nginx/
RUN chown -R www-data /etc/nginx/ && chmod +x /usr/local/bin/nginx-*

ENV PHP_FPM_HOST "localhost"
ENV PHP_FPM_PORT "9000"
ENV NGINX_LOG_FORMAT "json"
ENV NGINX_LOG_FORMAT "combined"

USER www-data

HEALTHCHECK CMD ["nginx-healthcheck"]

ENTRYPOINT ["nginx-entrypoint"]

COPY --chown=www-data:www-data nginx/dev/*.conf /etc/nginx/conf.d/
COPY --chown=www-data:www-data nginx/dev/certs/ /etc/nginx/certs/
