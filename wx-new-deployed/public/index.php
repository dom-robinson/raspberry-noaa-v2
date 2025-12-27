<?php

# composer auto-loading
require dirname(__DIR__) . '/vendor/autoload.php';

use Config\Config;

# error handling
# Suppress deprecation warnings for PHP 8.2 compatibility (legacy code)
error_reporting(E_ALL & ~E_DEPRECATED & ~E_STRICT);
ini_set('display_errors', 0);  # Set to 0 for production, 1 for debugging
ini_set('display_startup_errors', 0);

include(__DIR__ . '/../Lib/Router.php');

# handle route dispatching
$router = new Lib\Router();

?>
