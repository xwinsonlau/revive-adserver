FROM php:8.1-apache

RUN apt-get update && apt-get install -y --no-install-recommends \
        libicu-dev \
        libzip-dev \
        libpng-dev \
        libjpeg-dev \
        libfreetype6-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" intl zip mysqli gd opcache \
    && docker-php-ext-enable opcache \
    && a2enmod rewrite headers \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY apache-vhost.conf /etc/apache2/sites-available/000-default.conf

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY maintenance-loop.sh /usr/local/bin/maintenance-loop.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/maintenance-loop.sh

ENTRYPOINT ["entrypoint.sh"]
CMD ["apache2-foreground"]
