FROM php:5.6-apache

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC

# Redirigir repositorios Debian Stretch a archive.debian.org
RUN sed -i 's/deb.debian.org/archive.debian.org/g' /etc/apt/sources.list && \
    sed -i 's/security.debian.org/archive.debian.org/g' /etc/apt/sources.list && \
    sed -i '/stretch-updates/d' /etc/apt/sources.list && \
    echo "Acquire::Check-Valid-Until \"false\";" > /etc/apt/apt.conf.d/90ignore-release-date

# Instalar dependencias base y extensiones PHP
RUN apt-get update --allow-unauthenticated && \
    apt-get install -y --allow-unauthenticated \
        git \
        unzip \
        curl \
        wget \
        libpng-dev \
        libjpeg-dev \
        libfreetype6-dev \
        libzip-dev \
        libxml2-dev \
        libmysqlclient-dev \
        default-mysql-client && \
    docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ && \
    docker-php-ext-install -j$(nproc) \
        mysqli \
        pdo \
        pdo_mysql \
        gd \
        mbstring \
        xml \
        zip \
        opcache && \
    rm -rf /var/lib/apt/lists/*

# Configuración PHP para código legacy
RUN { \
    echo 'short_open_tag = On'; \
    echo 'display_errors = On'; \
    echo 'error_reporting = E_ALL'; \
    echo 'memory_limit = 512M'; \
    echo 'upload_max_filesize = 64M'; \
    echo 'post_max_size = 64M'; \
    echo 'max_execution_time = 300'; \
    } > /usr/local/etc/php/conf.d/99-legacy.ini

# Instalar Composer 1.x (última versión compatible con PHP 5.6)
RUN curl -sS https://getcomposer.org/installer | \
    php -- --1 --install-dir=/usr/local/bin --filename=composer

# Crear usuario coder con mismo UID que en container principal
# La imagen php:5.6-cli ya tiene un usuario www-data, creamos coder adicional
RUN useradd -m -s /bin/bash -u 1000 coder 2>/dev/null || true && \
    mkdir -p /workspaces && \
    chown -R 1000:1000 /workspaces

# Configurar Apache
RUN a2enmod rewrite && \
    sed -i 's!/var/www/html!/workspaces!g' /etc/apache2/sites-available/000-default.conf && \
    echo '<Directory /workspaces>\n\
    Options Indexes FollowSymLinks\n\
    AllowOverride All\n\
    Require all granted\n\
</Directory>' >> /etc/apache2/apache2.conf

# Ajustar permisos para que Apache (www-data) y coder puedan trabajar
RUN chown -R www-data:www-data /workspaces && \
    usermod -a -G www-data coder

WORKDIR /workspaces

# Iniciar Apache en foreground
CMD ["apache2-foreground"]
