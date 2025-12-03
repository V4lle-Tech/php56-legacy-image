# .htaccess con PHP Built-in Server

## Respuesta Corta: NO

El servidor `php -S` (PHP built-in server) **NO procesa archivos .htaccess** porque .htaccess es específico de Apache. El servidor built-in de PHP ignora completamente estos archivos.

## Alternativa: Router Script

PHP built-in server tiene su propia forma de routing mediante un archivo router:

```bash
# En lugar de solo:
php -S localhost:8000

# Usas:
php -S localhost:8000 router.php
```

## Implementación para Strangler Pattern

### router.php (Entry point para desarrollo)

```php
<?php
// router.php - Para PHP built-in server

$requestUri = $_SERVER['REQUEST_URI'];
$requestPath = parse_url($requestUri, PHP_URL_PATH);

// 1. Servir archivos estáticos directamente
if (preg_match('/\.(css|js|jpg|jpeg|png|gif|ico|svg|woff|woff2|ttf)$/i', $requestPath)) {
    return false; // El servidor PHP maneja el archivo estático
}

// 2. Cargar el router principal
require_once __DIR__ . '/app/Router.php';

$router = new Router();
$router->dispatch($requestPath);
```

### Comparación de configuración

```php
// === DESARROLLO (PHP Built-in Server) ===
// Comando: php -S localhost:8000 router.php

// router.php
<?php
$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);

// Assets estáticos
if (preg_match('/\.(css|js|png|jpg)$/i', $path)) {
    return false;
}

// Todo lo demás va al router
require __DIR__ . '/public/index.php';
```

```apache
# === PRODUCCIÓN (Apache) ===
# .htaccess en public/

<IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteBase /
    
    # Assets estáticos pasan directo
    RewriteCond %{REQUEST_FILENAME} -f
    RewriteRule ^ - [L]
    
    # Todo lo demás a index.php
    RewriteRule ^(.*)$ index.php [QSA,L]
</IfModule>
```

## Ejemplo Completo: Proyecto Híbrido

### Estructura

```
proyecto/
├── router.php              # Para php -S (desarrollo)
├── public/
│   ├── index.php          # Front controller (producción)
│   ├── .htaccess          # Solo para Apache
│   └── assets/
│       ├── css/
│       └── js/
├── app/
│   ├── Router.php
│   └── Controllers/
└── legacy/
    └── usuarios/
        └── perfil.php
```

### router.php (Desarrollo)

```php
<?php
// router.php - Para: php -S localhost:8000 router.php

// Capturar request
$requestUri = $_SERVER['REQUEST_URI'];
$requestPath = parse_url($requestUri, PHP_URL_PATH);

// Log para debug (opcional)
error_log("Request: $requestPath");

// 1. Archivos estáticos
if (preg_match('/\.(css|js|jpg|jpeg|png|gif|ico|svg|pdf|woff|woff2|ttf|eot)$/i', $requestPath)) {
    // Buscar en public/assets
    $staticFile = __DIR__ . '/public' . $requestPath;
    
    if (file_exists($staticFile)) {
        return false; // PHP server lo sirve
    }
    
    // No encontrado
    header("HTTP/1.0 404 Not Found");
    echo "Asset not found";
    exit;
}

// 2. Redirigir al front controller
$_SERVER['SCRIPT_NAME'] = '/index.php';
require __DIR__ . '/public/index.php';
```

### public/index.php (Producción)

```php
<?php
// public/index.php - Front controller común

require_once __DIR__ . '/../app/Router.php';

$requestPath = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);

$router = new Router();
$router->dispatch($requestPath);
```

### public/.htaccess (Solo Apache)

```apache
<IfModule mod_rewrite.c>
    RewriteEngine On
    
    # Si el archivo existe, servirlo
    RewriteCond %{REQUEST_FILENAME} -f
    RewriteRule ^ - [L]
    
    # Si el directorio existe, servirlo
    RewriteCond %{REQUEST_FILENAME} -d
    RewriteRule ^ - [L]
    
    # Todo lo demás a index.php
    RewriteRule ^ index.php [L]
</IfModule>
```

## Router Universal

Para que funcione en AMBOS entornos sin cambios:

```php
// app/Router.php
class Router {
    private array $migratedRoutes = [];
    private string $legacyRoot;
    private bool $isDevelopment;
    
    public function __construct() {
        $this->legacyRoot = __DIR__ . '/../legacy';
        $this->isDevelopment = php_sapi_name() === 'cli-server';
        $this->registerMigratedRoutes();
    }
    
    private function registerMigratedRoutes() {
        $this->migratedRoutes = [
            '/usuarios/perfil' => ['App\\Controllers\\UserController', 'profile'],
            '/usuarios/editar' => ['App\\Controllers\\UserController', 'edit'],
        ];
    }
    
    public function dispatch(string $path) {
        // Limpiar path
        $path = $this->normalizePath($path);
        
        // Log en desarrollo
        if ($this->isDevelopment) {
            error_log("Routing: $path");
        }
        
        // Rutas migradas
        if (isset($this->migratedRoutes[$path])) {
            return $this->handleModern($path);
        }
        
        // Legacy
        if ($this->legacyFileExists($path)) {
            return $this->handleLegacy($path);
        }
        
        // 404
        $this->handle404($path);
    }
    
    private function normalizePath(string $path): string {
        $path = rtrim($path, '/');
        $path = preg_replace('/\.php$/', '', $path);
        return $path ?: '/';
    }
    
    private function handleModern(string $path) {
        if ($this->isDevelopment) {
            error_log("✓ Modern route: $path");
        }
        
        require_once __DIR__ . '/../vendor/autoload.php';
        
        [$class, $method] = $this->migratedRoutes[$path];
        $controller = new $class();
        $controller->$method();
    }
    
    private function handleLegacy(string $path) {
        if ($this->isDevelopment) {
            error_log("⚠ Legacy route: $path");
        }
        
        $legacyFile = $this->legacyRoot . $path . '.php';
        
        // Incluir dependencies legacy
        $this->initLegacyEnvironment();
        
        // Ejecutar legacy file
        include $legacyFile;
    }
    
    private function initLegacyEnvironment() {
        // Inicializar lo que el legacy necesita
        require_once $this->legacyRoot . '/includes/db.php';
        require_once $this->legacyRoot . '/includes/funciones_globales.php';
        
        if (session_status() === PHP_SESSION_NONE) {
            session_start();
        }
    }
    
    private function legacyFileExists(string $path): bool {
        $file = $this->legacyRoot . $path . '.php';
        return file_exists($file);
    }
    
    private function handle404(string $path) {
        if ($this->isDevelopment) {
            error_log("✗ 404: $path");
        }
        
        header("HTTP/1.0 404 Not Found");
        echo "<h1>404 - Not Found</h1>";
        echo "<p>Path: " . htmlspecialchars($path) . "</p>";
        
        if ($this->isDevelopment) {
            echo "<pre>";
            echo "Migrated routes:\n";
            print_r(array_keys($this->migratedRoutes));
            echo "\nLegacy root: {$this->legacyRoot}\n";
            echo "</pre>";
        }
        exit;
    }
}
```

## Scripts de Desarrollo

### package.json / composer.json scripts

```json
{
    "scripts": {
        "dev": "php -S localhost:8000 router.php",
        "dev:verbose": "php -S localhost:8000 router.php 2>&1 | tee server.log"
    }
}
```

### Makefile

```makefile
.PHONY: dev prod

dev:
	@echo "Starting development server..."
	php -S localhost:8000 router.php

dev-verbose:
	@echo "Starting development server with logging..."
	php -S localhost:8000 router.php 2>&1 | tee server.log

prod-test:
	@echo "Testing with Apache simulation..."
	docker run -v $(PWD):/var/www/html -p 8080:80 php:apache
```

## Testing de Configuración

```php
// tests/RouterTest.php
class RouterTest extends PHPUnit\Framework\TestCase {
    public function testStaticFiles() {
        // Simular request de asset
        $_SERVER['REQUEST_URI'] = '/assets/css/style.css';
        
        ob_start();
        include __DIR__ . '/../router.php';
        $output = ob_get_clean();
        
        // Debería devolver false o servir el archivo
        $this->assertFileExists(__DIR__ . '/../public/assets/css/style.css');
    }
    
    public function testModernRoute() {
        $_SERVER['REQUEST_URI'] = '/usuarios/perfil';
        
        ob_start();
        include __DIR__ . '/../router.php';
        $output = ob_get_clean();
        
        $this->assertStringContainsString('Perfil', $output);
    }
    
    public function testLegacyRoute() {
        $_SERVER['REQUEST_URI'] = '/admin/dashboard.php';
        
        ob_start();
        include __DIR__ . '/../router.php';
        $output = ob_get_clean();
        
        // Verificar que legacy se ejecutó
        $this->assertNotEmpty($output);
    }
}
```

## Resumen Comparativo

| Característica | PHP Built-in (`php -S`) | Apache |
|----------------|-------------------------|---------|
| .htaccess | ❌ No funciona | ✅ Funciona |
| Router script | ✅ `router.php` | ❌ No necesario |
| Rewrites | Manual en PHP | .htaccess |
| Performance | Solo desarrollo | Producción |
| Configuración | Simple | Más compleja |

## Recomendación

```bash
# DESARROLLO
php -S localhost:8000 router.php

# PRODUCCIÓN  
# Usar Apache/Nginx con .htaccess/config real
```

El router.php te da la flexibilidad de desarrollar sin Apache y luego deployar a Apache/Nginx sin cambiar tu código de aplicación.