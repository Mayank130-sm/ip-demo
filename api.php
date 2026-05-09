<?php
include 'config.php';
header('Content-Type: application/json');

$typeFilter = $_GET['type'] ?? null;
$search = $_GET['search'] ?? null;

// Build Dynamic Cypher Query
if ($search) {
    // Search across name (Drugs/Diseases) and symbol (Genes)
    $query = "MATCH (n) WHERE n.name CONTAINS '$search' OR n.symbol CONTAINS '$search' 
              OPTIONAL MATCH (n)-[r]-(m) RETURN n, r, m";
} elseif ($typeFilter) {
    // Filter by specific Vertex Type
    $query = "MATCH (n:$typeFilter)-[r]-(m) RETURN n, r, m";
} else {
    // Default: Show overview
    $query = "MATCH (n)-[r]->(m) RETURN n, r, m LIMIT 100";
}

$data = queryArcade($query);
$elements = [];
$seen = []; // Prevent duplicate nodes

if (isset($data['result'])) {
    foreach ($data['result'] as $row) {
        foreach (['n', 'm'] as $key) {
            if (!isset($row[$key])) continue;
            $node = $row[$key];
            if (!in_array($node['@rid'], $seen)) {
                $elements[] = [
                    "data" => [
                        "id" => $node['@rid'],
                        "label" => $node['name'] ?? $node['symbol'] ?? 'Unknown',
                        "type" => $node['@type'],
                        // Include all properties for the sidebar
                        "properties" => $node 
                    ]
                ];
                $seen[] = $node['@rid'];
            }
        }
        if (isset($row['r'])) {
            $edge = $row['r'];
            $elements[] = [
                "data" => [
                    "id" => $edge['@rid'],
                    "source" => $edge['@out'],
                    "target" => $edge['@in'],
                    "label" => $edge['@type']
                ]
            ];
        }
    }
}
echo json_encode($elements);
?>