<?php
header('Content-Type: application/json');

// Debug info
error_reporting(E_ALL);
ini_set('display_errors', 1);

$dir = '/var/www/html/api-specs';
$files = [];

try {
    if (is_dir($dir)) {
        $dirContents = scandir($dir);
        if ($dirContents === false) {
            throw new Exception("Unable to scan directory");
        }

        foreach ($dirContents as $file) {
            if ($file === '.' || $file === '..') {
                continue;
            }

            $ext = strtolower(pathinfo($file, PATHINFO_EXTENSION));
            if (!is_dir($dir . '/' . $file) && in_array($ext, ['yaml', 'yml', 'json'])) {
                $files[] = $file;
            }
        }
    } else {
        throw new Exception("Directory not found: $dir");
    }

    echo json_encode($files);
} catch (Exception $e) {
    echo json_encode(["error" => $e->getMessage()]);
}