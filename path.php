<?php
// =============================================================================
// path.php — GET /api/path.php
// Finds shortest path between two entities using ArcadeDB's shortestPath().
//
// ArcadeDB shortestPath syntax:
//   SELECT shortestPath('#X:Y', '#A:B', 'BOTH') AS path
//   Returns: [{path: ['#X:Y', '#Z:W', '#A:B']}]  — array of @rid strings
//
// Query Parameters:
//   ?from_type=Drug&from_name=Metformin
//   ?to_type=Gene&to_symbol=INS
//   ?to_type=Disease&to_name=Alzheimer+Disease
//   ?maxdepth=5
// =============================================================================

require_once __DIR__ . '/config.php';

$from_type   = isset($_GET['from_type'])   ? sanitize($_GET['from_type'])   : '';
$from_name   = isset($_GET['from_name'])   ? sanitize($_GET['from_name'])   : '';
$from_symbol = isset($_GET['from_symbol']) ? sanitize($_GET['from_symbol']) : '';
$to_type     = isset($_GET['to_type'])     ? sanitize($_GET['to_type'])     : '';
$to_name     = isset($_GET['to_name'])     ? sanitize($_GET['to_name'])     : '';
$to_symbol   = isset($_GET['to_symbol'])   ? sanitize($_GET['to_symbol'])   : '';
$maxdepth    = isset($_GET['maxdepth'])    ? min((int)$_GET['maxdepth'], 8) : 5;

if (!$from_type || !$to_type) {
    error_response("'from_type' and 'to_type' are required");
}

// ── Resolve FROM vertex ──────────────────────────────────────────────
if ($from_type === 'Gene' && $from_symbol) {
    $from_rows  = arcade_query("SELECT @rid FROM Gene WHERE symbol = '$from_symbol' LIMIT 1");
    $from_label = $from_symbol;
} elseif ($from_name) {
    $from_rows  = arcade_query("SELECT @rid FROM $from_type WHERE name = '$from_name' LIMIT 1");
    $from_label = $from_name;
} else {
    error_response("Provide 'from_name' or 'from_symbol'");
}
if (empty($from_rows)) error_response("Source entity not found", 404);
$from_rid = $from_rows[0]['@rid'];

// ── Resolve TO vertex ────────────────────────────────────────────────
if ($to_type === 'Gene' && $to_symbol) {
    $to_rows  = arcade_query("SELECT @rid FROM Gene WHERE symbol = '$to_symbol' LIMIT 1");
    $to_label = $to_symbol;
} elseif ($to_name) {
    $to_rows  = arcade_query("SELECT @rid FROM $to_type WHERE name = '$to_name' LIMIT 1");
    $to_label = $to_name;
} else {
    error_response("Provide 'to_name' or 'to_symbol'");
}
if (empty($to_rows)) error_response("Target entity not found", 404);
$to_rid = $to_rows[0]['@rid'];

if ($from_rid === $to_rid) {
    error_response("Source and target are the same entity");
}

// ── Run shortestPath ─────────────────────────────────────────────────
// ArcadeDB SQL: SELECT shortestPath('startRid', 'endRid', 'BOTH') AS path
// Returns an array of @rid strings representing the path vertices
$path_sql    = "SELECT shortestPath('$from_rid', '$to_rid', 'BOTH') AS path";
$path_result = arcade_query($path_sql);

$path_nodes = [];
$path_edges = [];
$found      = false;

if (!empty($path_result) && !empty($path_result[0]['path'])) {
    $rid_chain = $path_result[0]['path'];

    // rid_chain may come as array of strings "#X:Y" or array of objects
    // Normalize to array of rid strings
    $rid_strings = [];
    foreach ($rid_chain as $item) {
        if (is_string($item)) {
            $rid_strings[] = $item;
        } elseif (is_array($item) && isset($item['@rid'])) {
            $rid_strings[] = $item['@rid'];
        }
    }

    if (count($rid_strings) >= 2) {
        $found = true;

        // Fetch each vertex's details
        foreach ($rid_strings as $rid) {
            $vq = arcade_query("SELECT @rid, @type, name, symbol, drug_class, category, gene_type FROM [$rid] LIMIT 1");
            if (!empty($vq)) {
                $v = $vq[0];
                $path_nodes[] = [
                    'rid'   => $rid,
                    'label' => $v['symbol'] ?? $v['name'] ?? $rid,
                    'type'  => $v['@type']  ?? 'Unknown',
                    'data'  => $v,
                ];
            } else {
                // vertex not returned by SELECT FROM [rid] — store minimal
                $path_nodes[] = ['rid' => $rid, 'label' => $rid, 'type' => 'Unknown', 'data' => []];
            }
        }

        // Reconstruct edges between consecutive path vertices
        $edge_types = ['TREATS','TARGETS','ASSOCIATED_WITH','CAUSED_BY',
                       'INTERACTS_WITH','BIOMARKER_OF','HAS_SYMPTOM'];

        for ($i = 0; $i < count($rid_strings) - 1; $i++) {
            $a = $rid_strings[$i];
            $b = $rid_strings[$i + 1];
            $found_edge = false;

            foreach ($edge_types as $et) {
                // Check both directions
                $eq = arcade_query(
                    "SELECT @type, confidence_score, source, evidence_type
                     FROM $et
                     WHERE (out().@rid = '$a' AND in().@rid = '$b')
                        OR (out().@rid = '$b' AND in().@rid = '$a')
                     LIMIT 1"
                );
                if (!empty($eq)) {
                    $path_edges[] = [
                        'from'       => $a,
                        'to'         => $b,
                        'label'      => $et,
                        'confidence' => $eq[0]['confidence_score'] ?? null,
                        'source'     => $eq[0]['source']           ?? '',
                        'evidence'   => $eq[0]['evidence_type']    ?? '',
                    ];
                    $found_edge = true;
                    break;
                }
            }
            // If no edge found between these two (shouldn't happen), add placeholder
            if (!$found_edge) {
                $path_edges[] = ['from' => $a, 'to' => $b, 'label' => 'CONNECTED', 'confidence' => null, 'source' => ''];
            }
        }
    }
}

echo json_encode([
    'status'    => 'ok',
    'found'     => $found,
    'from'      => ['rid' => $from_rid, 'label' => $from_label, 'type' => $from_type],
    'to'        => ['rid' => $to_rid,   'label' => $to_label,   'type' => $to_type],
    'hop_count' => $found ? count($path_nodes) - 1 : null,
    'nodes'     => $path_nodes,
    'edges'     => $path_edges,
], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
