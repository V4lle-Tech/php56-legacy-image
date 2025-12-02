# PHP 5.6 Legacy Docker Image

Imagen Docker pre-construida con PHP 5.6.40 para usar como sidecar en workspaces de Coder.

## Características

- **Base**: php:5.6-cli (Debian Stretch archivado)
- **PHP**: 5.6.40 (EOL, solo para legacy)
- **Extensiones**: mysqli, pdo, pdo_mysql, gd, mbstring, xml, zip, opcache
- **Composer**: 1.10.27 (última versión compatible con PHP 5.6)
- **MySQL Client**: Incluido

## Configuración PHP

```ini
short_open_tag = On
display_errors = On
error_reporting = E_ALL
memory_limit = 512M
upload_max_filesize = 64M
post_max_size = 64M
max_execution_time = 300
```

## Uso

Esta imagen está diseñada para ejecutarse como sidecar container en pods de Kubernetes, junto con un container principal que ejecuta code-server.

El container principal usa wrappers que ejecutan comandos PHP via `kubectl exec` al sidecar:

```bash
# En container principal
php -v           # Ejecuta: kubectl exec ... -c php56-runtime -- php -v
composer install # Ejecuta: kubectl exec ... -c php56-runtime -- composer install
```

## Build Local

```bash
docker build -t ghcr.io/v4lle-tech/php56-legacy:latest .
docker run --rm -it ghcr.io/v4lle-tech/php56-legacy:latest php -v
```

## Publicación

La imagen se construye y publica automáticamente a GitHub Container Registry via GitHub Actions en cada push a `main` que modifique el Dockerfile.

```bash
docker pull ghcr.io/v4lle-tech/php56-legacy:latest
```

## Notas

- PHP 5.6 llegó a EOL en enero de 2019
- Esta imagen solo debe usarse para mantener código legacy
- Se recomienda migrar a PHP 7.4+ o 8.x cuando sea posible

## Licencia

MIT
