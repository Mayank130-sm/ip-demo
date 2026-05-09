<?php
// =============================================================================
// search.php — GET /api/search.php?q=brca&limit=20
// Global search across Drug, Disease, Gene — ranked by match quality.
// =============================================================================

require_once __DIR__ . '/config.php';

$q     = isset($_GET['q'])     ? sanitize($_GET['q'])     : '';
$limit = isset($_GET['limit']) ? (int)$_GET['limit']       : 20;

if (strlen($q) < 1) {
    error_response("Query parameter 'q' is required and must be at least 1 character");
}

$results = [];

// ---- Search Drugs ----
$drugs = arcade_query(
    "SELECT @rid, 'Drug' as type, name as label, drug_class as subtype, description
     FROM Drug
     WHERE name.toLowerCase() LIKE '%{$q}%'
        OR drug_class.toLowerCase() LIKE '%{$q}%'
        OR description.toLowerCase() LIKE '%{$q}%'
     ORDER BY name ASC LIMIT $limit"
);
foreach ($drugs as &$d) {
    $d['rid']  = $d['@rid'] ?? null;
    $d['type'] = 'Drug';
}
$results = array_merge($results, $drugs);

// ---- Search Diseases ----
$diseases = arcade_query(
    "SELECT @rid, 'Disease' as type, name as label, category as subtype, description
     FROM Disease
     WHERE name.toLowerCase() LIKE '%{$q}%'
        OR category.toLowerCase() LIKE '%{$q}%'
        OR mesh_id.toLowerCase() LIKE '%{$q}%'
        OR description.toLowerCase() LIKE '%{$q}%'
     ORDER BY name ASC LIMIT $limit"
);
foreach ($diseases as &$d) {
    $d['rid']  = $d['@rid'] ?? null;
    $d['type'] = 'Disease';
}
$results = array_merge($results, $diseases);

// ---- Search Genes ----
$genes = arcade_query(
    "SELECT @rid, 'Gene' as type, symbol as label, gene_type as subtype, function as description
     FROM Gene
     WHERE symbol.toLowerCase() LIKE '%{$q}%'
        OR name.toLowerCase() LIKE '%{$q}%'
        OR gene_type.toLowerCase() LIKE '%{$q}%'
        OR function.toLowerCase() LIKE '%{$q}%'
     ORDER BY symbol ASC LIMIT $limit"
);
foreach ($genes as &$g) {
    $g['rid']  = $g['@rid'] ?? null;
    $g['type'] = 'Gene';
    $g['name'] = $g['label']; // symbol is used as label for genes
}
$results = array_merge($results, $genes);

// ---- Score results: exact name match ranks higher ----
$q_lower = strtolower($q);
usort($results, function($a, $b) use ($q_lower) {
    $a_label = strtolower($a['label'] ?? '');
    $b_label = strtolower($b['label'] ?? '');
    $a_exact = ($a_label === $q_lower) ? 0 : (str_starts_with($a_label, $q_lower) ? 1 : 2);
    $b_exact = ($b_label === $q_lower) ? 0 : (str_starts_with($b_label, $q_lower) ? 1 : 2);
    if ($a_exact !== $b_exact) return $a_exact - $b_exact;
    return strcmp($a_label, $b_label);
});

// Limit total results
$results = array_slice($results, 0, $limit);

success($results, [
    'query'   => $q,
    'limit'   => $limit,
    'breakdown' => [
        'drugs'    => count($drugs),
        'diseases' => count($diseases),
        'genes'    => count($genes),
    ],
]);
