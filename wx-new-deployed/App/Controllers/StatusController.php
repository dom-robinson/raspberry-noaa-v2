<?php

namespace App\Controllers;

use Lib\View;

class StatusController extends \Lib\Controller {
  public function rtl_tcpAction($args) {
    // Get rtl_tcp configuration from settings
    $config_file = '/home/pi/raspberry-noaa-v2/config/settings.yml';
    $rtl_tcp_host = '192.168.0.86';
    $rtl_tcp_port = 1234;
    
    // Try to read from config file if it exists
    if (file_exists($config_file)) {
      $config_content = file_get_contents($config_file);
      // Extract rtl_tcp host and port from config
      if (preg_match('/METEOR_M2_3_SDR_DEVICE_ID.*rtl_tcp=([^:]+):(\d+)/', $config_content, $matches)) {
        $rtl_tcp_host = $matches[1];
        $rtl_tcp_port = (int)$matches[2];
      }
    }
    
    // Check rtl_tcp connectivity
    $status = 'unknown';
    $message = '';
    $timestamp = time();
    
    // Use socket connection test (non-blocking)
    $socket = @fsockopen($rtl_tcp_host, $rtl_tcp_port, $errno, $errstr, 2);
    if ($socket) {
      $status = 'online';
      $message = "rtl_tcp is reachable at {$rtl_tcp_host}:{$rtl_tcp_port}";
      fclose($socket);
    } else {
      $status = 'offline';
      $message = "rtl_tcp is not reachable at {$rtl_tcp_host}:{$rtl_tcp_port}";
      if ($errno > 0) {
        $message .= " (Error: {$errstr})";
      }
    }
    
    // Return JSON response
    header('Content-Type: application/json');
    echo json_encode([
      'status' => $status,
      'message' => $message,
      'host' => $rtl_tcp_host,
      'port' => $rtl_tcp_port,
      'timestamp' => $timestamp
    ]);
    exit;
  }
}

?>

