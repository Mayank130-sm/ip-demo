<?php
// =============================================================================
// drugs.php — GET /api/drugs.php
//
// Query Parameters:
//   ?search=name       — filter by name (partial, case-insensitive)
//   ?class=Statin      — filter by drug_class
//   ?fda=true|false    — filter by FDA approval status
//   ?limit=N           — max results (default 50)
//   ?offset=N          — pagination offset (default 0)
//   ?detail=1&name=X   — get single drug with all relationships
// =============================================================================

require_once __DIR__ . '/config.php';

$search = isset($_GET['search']) ? sanitize($_GET['search']) : '';
$class  = isset($_GET['class'])  ? sanitize($_GET['class'])  : '';
$fda    = isset($_GET['fda'])    ? $_GET['fda']              : '';
$limit  = isset($_GET['limit'])  ? (int)$_GET['limit']       : 50;
$offset = isset($_GET['offset']) ? (int)$_GET['offset']      : 0;
$detail = isset($_GET['detail']) && isset($_GET['name']);

// ---- DETAIL MODE: single drug with all edges ----
if ($detail) {
    $drugName = sanitize($_GET['name']);

    // Get drug node
    $drug = arcade_query("SELECT * FROM Drug WHERE name = '$drugName' LIMIT 1");
    if (empty($drug)) {
        error_response("Drug '$drugName' not found", 404);
    }

    // Get diseases this drug TREATS
    $treats = arcade_query(
        "SELECT expand(out('TREATS')) FROM Drug WHERE name = '$drugName'"
    );

    // Get genes this drug TARGETS
    $targets = arcade_query(
        "SELECT expand(out('TARGETS')) FROM Drug WHERE name = '$drugName'"
    );

    // Get drug-drug interactions
    $interactions = arcade_query(
        "SELECT expand(out('INTERACTS_WITH')) FROM Drug WHERE name = '$drugName'"
    );

    // Get edge details for TREATS
    $treat_edges = arcade_query(
        "SELECT out().name AS drug, in().name AS disease, confidence_score, source, evidence_type, year
         FROM TREATS WHERE out().name = '$drugName'"
    );

    success([
        'drug'         => $drug[0] ?? [],
        'treats'       => $treats,
        'targets'      => $targets,
        'interactions' => $interactions,
        'treat_edges'  => $treat_edges,
    ], ['type' => 'Drug', 'detail' => true]);
}

// ---- LIST MODE ----
$where_clauses = [];

if ($search !== '') {
    $where_clauses[] = "name.toLowerCase() LIKE '%{$search}%'";
}
if ($class !== '') {
    $where_clauses[] = "drug_class = '$class'";
}
if ($fda === 'true') {
    $where_clauses[] = "fda_approved = true";
} elseif ($fda === 'false') {
    $where_clauses[] = "fda_approved = false";
}

$where = !empty($where_clauses) ? 'WHERE ' . implode(' AND ', $where_clauses) : '';
$sql   = "SELECT @rid, name, formula, mechanism, fda_approved, drug_class, description
          FROM Drug $where ORDER BY name ASC LIMIT $limit SKIP $offset";

$rows = arcade_query($sql);

// Format @rid for frontend use
foreach ($rows as &$row) {
    $row['rid'] = $row['@rid'] ?? null;
    $row['type'] = 'Drug';
}
unset($row);

// Get distinct drug classes for filter options
$classes = arcade_query("SELECT DISTINCT(drug_class) as drug_class FROM Drug ORDER BY drug_class ASC");
$class_list = array_column($classes, 'drug_class');

success($rows, [
    'type'        => 'Drug',
    'filter_classes' => $class_list,
    'limit'       => $limit,
    'offset'      => $offset,
]);
