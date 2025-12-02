FROM ubuntu:18.04

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC

# Instalar dependencias base
RUN apt-get update && apt-get install -y \
    software-properties-common \
    ca-certificates \
    curl \
    wget \
    git \
    unzip \
    sudo && \
    rm -rf /var/lib/apt/lists/*

# Agregar PPA ondrej/php (última vez que tuvo PHP 5.6)
RUN LC_ALL=C.UTF-8 add-apt-repository ppa:ondrej/php -y && \
    apt-get update && \
    apt-get install -y \
        php5.6-cli \
        php5.6-mysql \
        php5.6-mysqli \
        php5.6-pdo \
        php5.6-gd \
        php5.6-mbstring \
        php5.6-xml \
        php5.6-zip \
        php5.6-curl \
        php5.6-opcache \
        mysql-client-5.7 && \
    rm -rf /var/lib/apt/lists/*

# Symlink php
RUN update-alternatives --set php /usr/bin/php5.6

# Configuración PHP para código legacy
RUN { \
    echo 'short_open_tag = On'; \
    echo 'display_errors = On'; \
    echo 'error_reporting = E_ALL'; \
    echo 'memory_limit = 512M'; \
    echo 'upload_max_filesize = 64M'; \
    echo 'post_max_size = 64M'; \
    echo 'max_execution_time = 300'; \
    } > /etc/php/5.6/cli/conf.d/99-legacy.ini

# Instalar Composer 1.x (última versión compatible con PHP 5.6)
RUN curl -sS https://getcomposer.org/installer | \
    php -- --1 --install-dir=/usr/local/bin --filename=composer

# Crear usuario coder con mismo UID que en container principal
RUN useradd -m -s /bin/bash -u 1000 coder

WORKDIR /workspaces
USER coder

# Mantener container vivo para kubectl exec
CMD ["sleep", "infinity"]
