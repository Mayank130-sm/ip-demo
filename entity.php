<?php
// =============================================================================
// entity.php — GET /api/entity.php
// Returns a node + ALL its edges + neighbor nodes for vis.js graph visualization.
//
// ArcadeDB-correct implementation:
// - Edge queries use: SELECT FROM EdgeType WHERE out = <rid> (no quotes on RID)
//   OR: WHERE out.@rid = '<rid>' (with quotes — both work)
// - @type on edge records returns the edge class name (e.g. "TREATS") ✓
// - @type on vertex records returns vertex class (e.g. "Drug") ✓
// - out() and in() vertex expansion done separately for reliability
//
// Query Parameters:
//   ?type=Drug&name=Metformin     — Drug or Disease by name
//   ?type=Gene&symbol=BRCA1       — Gene by symbol
//   ?depth=1                      — traversal depth (1 or 2)
// =============================================================================

require_once __DIR__ . '/config.php';

$type   = isset($_GET['type'])   ? sanitize($_GET['type'])   : '';
$name   = isset($_GET['name'])   ? sanitize($_GET['name'])   : '';
$symbol = isset($_GET['symbol']) ? sanitize($_GET['symbol']) : '';
$depth  = isset($_GET['depth'])  ? min((int)$_GET['depth'], 2) : 1;

if (!$type) {
    error_response("Parameter 'type' is required (Drug, Disease, or Gene)");
}

// ── 1. Resolve the starting vertex ──────────────────────────────────
if ($type === 'Gene' && $symbol !== '') {
    $start = arcade_query("SELECT FROM Gene WHERE symbol = '$symbol' LIMIT 1");
} elseif ($name !== '') {
    $start = arcade_query("SELECT FROM $type WHERE name = '$name' LIMIT 1");
} else {
    error_response("Provide 'name' (Drug/Disease) or 'symbol' (Gene)");
}

if (empty($start)) {
    error_response("Entity not found", 404);
}

$node       = $start[0];
$center_rid = $node['@rid'] ?? '';

if (!$center_rid) {
    error_response("Could not resolve entity @rid", 500);
}

$center_label = $node['symbol'] ?? $node['name'] ?? 'Unknown';

// ── 2. Query every edge type for edges touching this vertex ──────────
// ArcadeDB: SELECT FROM EdgeType WHERE out = #X:Y  (RID without quotes in WHERE)
// We also accept string comparison: WHERE out.@rid = '#X:Y'
// Using the subquery form is most reliable across ArcadeDB versions.

$all_edges_raw = [];
$edge_types    = ['TREATS', 'TARGETS', 'ASSOCIATED_WITH', 'CAUSED_BY',
                  'INTERACTS_WITH', 'BIOMARKER_OF', 'HAS_SYMPTOM'];

foreach ($edge_types as $et) {
    // Outgoing: this vertex is the source (out)
    $out_q = "SELECT @rid, @type, out().@rid AS from_rid, out().@type AS from_type,
                     out().name AS from_name, out().symbol AS from_symbol,
                     in().@rid AS to_rid,  in().@type AS to_type,
                     in().name AS to_name, in().symbol AS to_symbol,
                     confidence_score, source, evidence_type, year
              FROM $et
              WHERE out().@rid = '$center_rid'";

    // Incoming: this vertex is the target (in)
    $in_q  = "SELECT @rid, @type, out().@rid AS from_rid, out().@type AS from_type,
                     out().name AS from_name, out().symbol AS from_symbol,
                     in().@rid AS to_rid,  in().@type AS to_type,
                     in().name AS to_name, in().symbol AS to_symbol,
                     confidence_score, source, evidence_type, year
              FROM $et
              WHERE in().@rid = '$center_rid'";

    $out_edges = arcade_query($out_q);
    $in_edges  = arcade_query($in_q);

    foreach ($out_edges as $e) { $e['_etype'] = $et; $all_edges_raw[] = $e; }
    foreach ($in_edges  as $e) { $e['_etype'] = $et; $all_edges_raw[] = $e; }
}

// ── 3. Build unique node map ─────────────────────────────────────────
$node_map = [];

// Center node
$node_map[$center_rid] = [
    'id'         => $center_rid,
    'label'      => $center_label,
    'type'       => $type,
    'properties' => array_filter($node, fn($k) => !str_starts_with($k, '@'), ARRAY_FILTER_USE_KEY),
    'is_center'  => true,
];

// Add neighbor nodes from edge data
foreach ($all_edges_raw as $edge) {
    foreach (['from', 'to'] as $side) {
        $rid   = $edge["{$side}_rid"]    ?? null;
        $vtype = $edge["{$side}_type"]   ?? 'Unknown';
        $vname = $edge["{$side}_symbol"] ?? $edge["{$side}_name"] ?? '?';

        if ($rid && !isset($node_map[$rid])) {
            $node_map[$rid] = [
                'id'        => $rid,
                'label'     => $vname,
                'type'      => $vtype,
                'is_center' => ($rid === $center_rid),
            ];
        }
    }
}

// ── 4. Build edge list for vis.js ────────────────────────────────────
$edge_list = [];
$seen_edges = [];

foreach ($all_edges_raw as $edge) {
    $from = $edge['from_rid'] ?? null;
    $to   = $edge['to_rid']   ?? null;
    if (!$from || !$to) continue;

    // Deduplicate (same edge can appear from both out and in queries)
    $dedup_key = $from . '|' . $to . '|' . ($edge['_etype'] ?? '');
    if (isset($seen_edges[$dedup_key])) continue;
    $seen_edges[$dedup_key] = true;

    $edge_list[] = [
        'from'       => $from,
        'to'         => $to,
        'label'      => $edge['_etype'] ?? ($edge['@type'] ?? ''),
        'confidence' => $edge['confidence_score'] ?? null,
        'source'     => $edge['source']            ?? '',
        'evidence'   => $edge['evidence_type']     ?? '',
        'year'       => $edge['year']              ?? null,
    ];
}

// ── 5. If depth=2, fetch second-hop neighbors ────────────────────────
if ($depth >= 2 && !empty($edge_list)) {
    $first_hop_rids = array_keys($node_map);
    foreach ($first_hop_rids as $hop_rid) {
        if ($hop_rid === $center_rid) continue;
        foreach ($edge_types as $et) {
            $q2 = "SELECT out().@rid AS from_rid, out().@type AS from_type,
                          out().name AS from_name, out().symbol AS from_symbol,
                          in().@rid AS to_rid, in().@type AS to_type,
                          in().name AS to_name, in().symbol AS to_symbol,
                          confidence_score, source, evidence_type, year
                   FROM $et
                   WHERE out().@rid = '$hop_rid' OR in().@rid = '$hop_rid'";
            $hop_edges = arcade_query($q2);
            foreach ($hop_edges as $e) {
                $e['_etype'] = $et;
                foreach (['from', 'to'] as $side) {
                    $rid   = $e["{$side}_rid"]    ?? null;
                    $vtype = $e["{$side}_type"]   ?? 'Unknown';
                    $vname = $e["{$side}_symbol"] ?? $e["{$side}_name"] ?? '?';
                    if ($rid && !isset($node_map[$rid])) {
                        $node_map[$rid] = ['id' => $rid, 'label' => $vname, 'type' => $vtype, 'is_center' => false];
                    }
                }
                $from = $e['from_rid'] ?? null;
                $to   = $e['to_rid']   ?? null;
                if (!$from || !$to) continue;
                $dk = $from . '|' . $to . '|' . $et;
                if (isset($seen_edges[$dk])) continue;
                $seen_edges[$dk] = true;
                $edge_list[] = ['from' => $from, 'to' => $to, 'label' => $et,
                                'confidence' => $e['confidence_score'] ?? null,
                                'source' => $e['source'] ?? '', 'evidence' => $e['evidence_type'] ?? '', 'year' => $e['year'] ?? null];
            }
        }
    }
}

echo json_encode([
    'status' => 'ok',
    'center' => ['rid' => $center_rid, 'label' => $center_label, 'type' => $type],
    'nodes'  => array_values($node_map),
    'edges'  => $edge_list,
    'debug'  => ['edge_count' => count($edge_list), 'node_count' => count($node_map)],
], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
