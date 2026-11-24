ARG ALPINE_VERSION=latest
FROM alpine:${ALPINE_VERSION} AS builder

RUN mkdir -p /app

WORKDIR /app

COPY . /app/fb_src
RUN rm -rf \
        /app/fb_src/.editorconfig \
        /app/fb_src/.git \
        /app/fb_src/.git* \
        /app/fb_src/docker \
        /app/fb_src/extras \
        /app/fb_src/git-hooks \
        /app/fb_src/scripts/*.sh \
        /app/fb_src/scripts/*.js \
        /app/fb_src/doc \
        /app/fb_src/data \
        /app/fb_src/Dockerfile \
        /app/fb_src/COPYING \
        /app/fb_src/NEWS \
        /app/fb_src/INSTALL \
        /app/fb_src/composer.* \
        /app/fb_src/license.txt \
        /app/fb_src/crontab \
        /app/fb_src/*.sh \
        /app/fb_src/*.md \
        /app/fb_src/check_deps.php && \
    mkdir /app/fb_src/data && \
    cd /app/fb_src/data && \
    ln -sf ../public_html/data/client && \
    ln -sf ../public_html/data/css && \
    ln -sf ../public_html/data/fonts && \
    ln -sf ../public_html/data/img && \
    ln -sf ../public_html/data/js

FROM alpine:${ALPINE_VERSION}
COPY --from=builder /app/fb_src /var/www

LABEL description="filebin" \
    org.opencontainers.image.title="filebin" \
    org.opencontainers.image.description="filebin" \
    org.opencontainers.image.base.name="alpine:3"

ENV RECONFIGURE=true \
    MIGRATE=true \
    PHP_MEMORY_LIMIT=512M \
    MAX_UPLOAD=1024M \
    PHP_MAX_FILE_UPLOAD=100 \
    PHP_MAX_POST=1024M \
    DB_DSN='' \
    DB_HOST=localhost \
    DB_PORT=5432 \
    DB_DRIVER=postgre \
    DB_NAME=fb \
    DB_USER=fb \
    DB_PASS=fb \
    DB_PREFIX='' \
    DB_PCONNECT='0' \
    DB_DEBUG='1' \
    DB_CHAR_SET=utf8 \
    DB_COLLAT=utf8_bin \
    DB_SWAP_PRE='' \
    DB_ENCRYPT='0' \
    DB_COMPRESS='0' \
    DB_STRICTON='0' \
    DB_SAVE_QUERIES='0' \
    BASE_URL='' \
    INDEX_PAGE='' \
    ENCRYPTION_KEY='' \
    CACHE_BACKEND=dummy \
    EMAIL_FROM='' \
    UPLOAD_MAX_SIZE=1073741824 \
    UPLOAD_MAX_TEXT_SIZE=2097152 \
    UPLOAD_MAX_AGE=432000 \
    ACTIONS_MAX_AGE=86400 \
    SMALL_UPLOAD_SIZE=5120 \
    TARBALL_MAX_SIZE=1073741824 \
    TARBALL_CACHE_TIME=300 \
    MAX_INVITATION_KEYS=3 \
    SMTP_ENABLED=false \
    SMTP_PROTOCOL='smtp' \
    SMTP_HOST='' \
    SMTP_PORT=587 \
    SMTP_CRYPTO='tls' \
    SMTP_USER='' \
    SMTP_PASS=''

COPY docker/src/wait-for.sh /wait-for.sh

# install dependencies
RUN chmod -x /wait-for.sh && \
    echo https://dl-cdn.alpinelinux.org/alpine/edge/testing >> /etc/apk/repositories && \
    apk add --update --no-cache \
        nginx \
        s6 \
        curl \
        python3 \
        py-pygments \
        py3-ansi2html \
        imagemagick \
        ghostscript \
        msmtp \
        composer \
        php86 \
        php86-fpm \
        php86-intl \
        php86-curl \
        php86-dom \
        php86-pcntl \
        php86-posix \
        php86-session \
        php86-gd \
        php86-exif \
        php86-phar \
        php86-pdo \
        php86-pgsql \
        php86-pdo_pgsql \
        php86-pdo_mysql \
        php86-mysqli \
        php86-fileinfo \
        php86-mbstring \
        php86-ctype \
        php86-ldap \
        php86-pecl-memcached \
        memcached \
        ca-certificates && \
    rm -rf /var/cache/apk/* && \
    apk add gnu-libiconv --update-cache --repository https://dl-cdn.alpinelinux.org/alpine/edge/community/ --allow-untrusted && \
    cp -r /var/www/application/config/example/* /var/www/application/config && \
    sed -i "s|;*memory_limit =.*|memory_limit = ${PHP_MEMORY_LIMIT}|i" /etc/php86/php.ini && \
    sed -i "s|;*upload_max_filesize =.*|upload_max_filesize = ${MAX_UPLOAD}|i" /etc/php86/php.ini && \
    sed -i "s|;*max_file_uploads =.*|max_file_uploads = ${PHP_MAX_FILE_UPLOAD}|i" /etc/php86/php.ini && \
    sed -i "s|;*post_max_size =.*|post_max_size = ${PHP_MAX_POST}|i" /etc/php86/php.ini && \
    sed -i "s|;*session.upload_progress.enabled = .*|session.upload_progress.enabled = Off|i" /etc/php86/php.ini && \
    sed -i 's+.*sendmail_path =.*+sendmail_path = "/usr/bin/msmtp -C /var/www/msmtprc --logfile /var/www/msmtp.log -a filebinmail -t"+' /etc/php86/php.ini && \
    rm -rf /var/cache/apk/* && \
    chown nobody:nginx -R /var/www && \
    rm /usr/bin/php && \
    ln -s /usr/bin/php86 /usr/bin/php && \
    ln -s /usr/sbin/php-fpm86 /usr/sbin/php-fpm

# Add nginx config
COPY docker/src/filebin.nginx.conf /etc/nginx/nginx.conf

EXPOSE 80

# add templates for replace env variables in the application
COPY docker/src/config/database.php.tpl /var/www/application/config/database.php.tpl
COPY docker/src/config/config-local.php.tpl /var/www/application/config/config-local.php.tpl
COPY docker/src/config/email.php.tpl /var/www/application/config/email.php.tpl
COPY docker/src/crontab /etc/periodic/15min/crontab
COPY docker/src/configure.php /configure.php
COPY docker/src/configure-mail.sh /var/www/configure-mail.sh

# add overlay
COPY docker/src/s6/ /etc/s6/

# expose start
CMD ["sh", "-c", "/usr/bin/php /configure.php && exec s6-svscan /etc/s6/"]
