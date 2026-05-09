<?php
// =============================================================================
// config.php — ArcadeDB connection settings
// Include this in every API file.
// =============================================================================

define('ARCADE_HOST',     'http://localhost:2480');
define('ARCADE_DB',       'biomedkg');
define('ARCADE_USER',     'root');
define('ARCADE_PASS',     'arcadedb-password');
define('ARCADE_ENDPOINT', ARCADE_HOST . '/api/v1/command/' . ARCADE_DB);
define('ARCADE_QUERY_EP', ARCADE_HOST . '/api/v1/query/'   . ARCADE_DB);

// CORS — allow frontend on same server (localhost)
header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// -----------------------------------------------------------------------
// arcade_query($sql, $language = 'sql')
// Sends a query/command to ArcadeDB via HTTP and returns decoded JSON.
// Use language='sql' for SELECT; 'cypher' for MATCH queries.
// -----------------------------------------------------------------------
function arcade_query(string $sql, string $language = 'sql'): array {
    $payload = json_encode([
        'language' => $language,
        'command'  => $sql,
    ]);

    $ch = curl_init(ARCADE_ENDPOINT);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST           => true,
        CURLOPT_POSTFIELDS     => $payload,
        CURLOPT_USERPWD        => ARCADE_USER . ':' . ARCADE_PASS,
        CURLOPT_HTTPHEADER     => ['Content-Type: application/json'],
        CURLOPT_TIMEOUT        => 15,
    ]);

    $raw      = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $curlErr  = curl_error($ch);
    curl_close($ch);

    if ($curlErr) {
        return ['error' => 'cURL error: ' . $curlErr, 'results' => []];
    }

    $decoded = json_decode($raw, true);

    if ($httpCode !== 200) {
        return [
            'error'   => $decoded['detail'] ?? "HTTP $httpCode from ArcadeDB",
            'results' => []
        ];
    }

    return $decoded['result'] ?? [];
}

// -----------------------------------------------------------------------
// success($data, $meta = [])
// Outputs a standardized JSON success envelope.
// -----------------------------------------------------------------------
function success(array $data, array $meta = []): void {
    echo json_encode([
        'status' => 'ok',
        'count'  => count($data),
        'meta'   => $meta,
        'data'   => $data,
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    exit;
}

// -----------------------------------------------------------------------
// error_response($message, $code = 400)
// -----------------------------------------------------------------------
function error_response(string $message, int $code = 400): void {
    http_response_code($code);
    echo json_encode(['status' => 'error', 'message' => $message], JSON_PRETTY_PRINT);
    exit;
}

// -----------------------------------------------------------------------
// sanitize($val)
// Escapes single quotes to prevent SQL injection in ArcadeDB SQL strings.
// -----------------------------------------------------------------------
function sanitize(string $val): string {
    return str_replace("'", "\\'", trim($val));
}
