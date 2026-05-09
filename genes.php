<?php
// =============================================================================
// genes.php — GET /api/genes.php
//
// Query Parameters:
//   ?search=name       — partial name or symbol search
//   ?type=Oncogene     — filter by gene_type
//   ?chromosome=17     — filter by chromosome
//   ?limit=N
//   ?offset=N
//   ?detail=1&symbol=BRCA1 — single gene with all relationships
// =============================================================================

require_once __DIR__ . '/config.php';

$search     = isset($_GET['search'])     ? sanitize($_GET['search'])     : '';
$gene_type  = isset($_GET['type'])       ? sanitize($_GET['type'])       : '';
$chromosome = isset($_GET['chromosome']) ? sanitize($_GET['chromosome']) : '';
$limit      = isset($_GET['limit'])      ? (int)$_GET['limit']           : 50;
$offset     = isset($_GET['offset'])     ? (int)$_GET['offset']          : 0;
$detail     = isset($_GET['detail'])     && isset($_GET['symbol']);

// ---- DETAIL MODE ----
if ($detail) {
    $symbol = sanitize($_GET['symbol']);

    $gene = arcade_query("SELECT * FROM Gene WHERE symbol = '$symbol' LIMIT 1");
    if (empty($gene)) {
        error_response("Gene '$symbol' not found", 404);
    }

    // Diseases this gene is associated with
    $diseases = arcade_query(
        "SELECT expand(out('ASSOCIATED_WITH')) FROM Gene WHERE symbol = '$symbol'"
    );

    // Drugs that target this gene
    $targeted_by = arcade_query(
        "SELECT expand(in('TARGETS')) FROM Gene WHERE symbol = '$symbol'"
    );

    // Diseases this gene is a biomarker for
    $biomarker_for = arcade_query(
        "SELECT expand(out('BIOMARKER_OF')) FROM Gene WHERE symbol = '$symbol'"
    );

    // Diseases caused by this gene
    $causes = arcade_query(
        "SELECT expand(in('CAUSED_BY')) FROM Gene WHERE symbol = '$symbol'"
    );

    // Edge details for ASSOCIATED_WITH
    $assoc_edges = arcade_query(
        "SELECT out().symbol AS gene, in().name AS disease, confidence_score, source, evidence_type, year
         FROM ASSOCIATED_WITH WHERE out().symbol = '$symbol'"
    );

    success([
        'gene'          => $gene[0] ?? [],
        'diseases'      => $diseases,
        'targeted_by'   => $targeted_by,
        'biomarker_for' => $biomarker_for,
        'causes'        => $causes,
        'assoc_edges'   => $assoc_edges,
    ], ['type' => 'Gene', 'detail' => true]);
}

// ---- LIST MODE ----
$where_clauses = [];

if ($search !== '') {
    $where_clauses[] = "(symbol.toLowerCase() LIKE '%{$search}%' OR name.toLowerCase() LIKE '%{$search}%')";
}
if ($gene_type !== '') {
    $where_clauses[] = "gene_type = '$gene_type'";
}
if ($chromosome !== '') {
    $where_clauses[] = "chromosome LIKE '$chromosome%'";
}

$where = !empty($where_clauses) ? 'WHERE ' . implode(' AND ', $where_clauses) : '';
$sql   = "SELECT @rid, symbol, name, ncbi_id, chromosome, function, gene_type
          FROM Gene $where ORDER BY symbol ASC LIMIT $limit SKIP $offset";

$rows = arcade_query($sql);

foreach ($rows as &$row) {
    $row['rid']  = $row['@rid'] ?? null;
    $row['type'] = 'Gene';
}
unset($row);

// Distinct gene types
$types = arcade_query("SELECT DISTINCT(gene_type) as gene_type FROM Gene ORDER BY gene_type ASC");
$type_list = array_column($types, 'gene_type');

success($rows, [
    'type'       => 'Gene',
    'gene_types' => $type_list,
    'limit'      => $limit,
    'offset'     => $offset,
]);
