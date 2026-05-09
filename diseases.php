<?php
// =============================================================================
// diseases.php — GET /api/diseases.php
//
// Query Parameters:
//   ?search=name       — partial name search
//   ?category=Oncology — filter by category
//   ?limit=N           — max results (default 50)
//   ?offset=N          — pagination
//   ?detail=1&name=X   — single disease with all relationships
// =============================================================================

require_once __DIR__ . '/config.php';

$search   = isset($_GET['search'])   ? sanitize($_GET['search'])   : '';
$category = isset($_GET['category']) ? sanitize($_GET['category']) : '';
$limit    = isset($_GET['limit'])    ? (int)$_GET['limit']         : 50;
$offset   = isset($_GET['offset'])   ? (int)$_GET['offset']        : 0;
$detail   = isset($_GET['detail'])   && isset($_GET['name']);

// ---- DETAIL MODE ----
if ($detail) {
    $diseaseName = sanitize($_GET['name']);

    $disease = arcade_query("SELECT * FROM Disease WHERE name = '$diseaseName' LIMIT 1");
    if (empty($disease)) {
        error_response("Disease '$diseaseName' not found", 404);
    }

    // Drugs that treat this disease
    $treated_by = arcade_query(
        "SELECT expand(in('TREATS')) FROM Disease WHERE name = '$diseaseName'"
    );

    // Genes associated with this disease
    $genes = arcade_query(
        "SELECT expand(in('ASSOCIATED_WITH')) FROM Disease WHERE name = '$diseaseName'"
    );

    // Genes that cause this disease (CAUSED_BY direction: Disease->Gene)
    $caused_by_genes = arcade_query(
        "SELECT expand(out('CAUSED_BY')) FROM Disease WHERE name = '$diseaseName'"
    );

    // Biomarker genes
    $biomarkers = arcade_query(
        "SELECT expand(in('BIOMARKER_OF')) FROM Disease WHERE name = '$diseaseName'"
    );

    // Disease comorbidities/symptoms
    $comorbidities = arcade_query(
        "SELECT expand(out('HAS_SYMPTOM')) FROM Disease WHERE name = '$diseaseName'"
    );

    success([
        'disease'          => $disease[0] ?? [],
        'treated_by'       => $treated_by,
        'associated_genes' => $genes,
        'caused_by'        => $caused_by_genes,
        'biomarkers'       => $biomarkers,
        'comorbidities'    => $comorbidities,
    ], ['type' => 'Disease', 'detail' => true]);
}

// ---- LIST MODE ----
$where_clauses = [];

if ($search !== '') {
    $where_clauses[] = "name.toLowerCase() LIKE '%{$search}%'";
}
if ($category !== '') {
    $where_clauses[] = "category = '$category'";
}

$where = !empty($where_clauses) ? 'WHERE ' . implode(' AND ', $where_clauses) : '';
$sql   = "SELECT @rid, name, mesh_id, category, description, prevalence
          FROM Disease $where ORDER BY name ASC LIMIT $limit SKIP $offset";

$rows = arcade_query($sql);

foreach ($rows as &$row) {
    $row['rid']  = $row['@rid'] ?? null;
    $row['type'] = 'Disease';
}
unset($row);

// Distinct categories for filter dropdown
$cats = arcade_query("SELECT DISTINCT(category) as category FROM Disease ORDER BY category ASC");
$cat_list = array_column($cats, 'category');

success($rows, [
    'type'       => 'Disease',
    'categories' => $cat_list,
    'limit'      => $limit,
    'offset'     => $offset,
]);
