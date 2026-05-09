<?php
// Database configuration from seed.sh
define('ARCADE_HOST', 'http://localhost:2480');
define('ARCADE_DB', 'biomedkg');
define('ARCADE_USER', 'root');
define('ARCADE_PASS', 'Mayank123@');

// Helper function to send commands to ArcadeDB
function queryArcade($command, $language = 'cypher') {
    $url = ARCADE_HOST . "/api/v1/command/" . ARCADE_DB;
    $payload = json_encode([
        "language" => $language,
        "command" => $command
    ]);

    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, $payload);
    curl_setopt($ch, CURLOPT_USERPWD, ARCADE_USER . ":" . ARCADE_PASS);
    curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);

    $result = curl_exec($ch);
    curl_close($ch);
    return json_decode($result, true);
}
?>