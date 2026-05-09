#!/bin/bash
# =============================================================================
# BioMed Knowledge Graph — ArcadeDB Seed Script
# Run ONCE after ArcadeDB is started.
# Usage:  bash seed.sh
# Needs:  curl only  (no python, no jq, nothing else)
# =============================================================================

HOST="http://localhost:2480"
USER="root"
PASS="arcadedb-password"
DB="biomedkg"

# ── check curl ────────────────────────────────────────────────────────
if ! command -v curl &>/dev/null; then
  echo "ERROR: curl not found. Please install curl and re-run."
  exit 1
fi

# ── send one SQL command to ArcadeDB, print raw response ──────────────
run() {
  local SQL="$1"
  local ESCAPED
  ESCAPED=$(printf '%s' "$SQL" | sed 's/\\/\\\\/g; s/"/\\"/g')
  curl -s -X POST "${HOST}/api/v1/command/${DB}" \
    -u "${USER}:${PASS}" \
    -H "Content-Type: application/json" \
    -d "{\"language\":\"sql\",\"command\":\"${ESCAPED}\"}"
  printf "\n"
}

# ── send a server-level command (create/drop database) ────────────────
server_cmd() {
  curl -s -X POST "${HOST}/api/v1/server" \
    -u "${USER}:${PASS}" \
    -H "Content-Type: application/json" \
    -d "{\"command\":\"$1\"}"
  printf "\n"
}

echo "============================================"
echo "  BioMed Knowledge Graph — ArcadeDB Seeder "
echo "============================================"

# ── connectivity check ────────────────────────────────────────────────
echo ""
echo "Checking ArcadeDB at ${HOST} ..."
HTTP=$(curl -s -o /dev/null -w "%{http_code}" -u "${USER}:${PASS}" "${HOST}/api/v1/ready")
if [ "$HTTP" != "204" ] && [ "$HTTP" != "200" ]; then
  echo "ERROR: ArcadeDB not responding (HTTP ${HTTP})."
  echo "       Start it first:  bin/server.bat  or  bin/server.sh"
  exit 1
fi
echo "OK — ArcadeDB is up."

# ═════════════════════════════════════════════════════════════════════
# 1. CREATE DATABASE
# ═════════════════════════════════════════════════════════════════════
echo ""
echo "[1/3] Creating database '${DB}' ..."
server_cmd "create database ${DB}"
sleep 1

# ═════════════════════════════════════════════════════════════════════
# 2. SCHEMA
# ═════════════════════════════════════════════════════════════════════
echo ""
echo "[2/3] Creating schema ..."

echo "  -> Vertex types"
run "CREATE VERTEX TYPE Drug    IF NOT EXISTS"
run "CREATE VERTEX TYPE Disease IF NOT EXISTS"
run "CREATE VERTEX TYPE Gene    IF NOT EXISTS"

echo "  -> Drug properties"
run "CREATE PROPERTY Drug.name         IF NOT EXISTS STRING"
run "CREATE PROPERTY Drug.formula      IF NOT EXISTS STRING"
run "CREATE PROPERTY Drug.mechanism    IF NOT EXISTS STRING"
run "CREATE PROPERTY Drug.fda_approved IF NOT EXISTS BOOLEAN"
run "CREATE PROPERTY Drug.drug_class   IF NOT EXISTS STRING"
run "CREATE PROPERTY Drug.description  IF NOT EXISTS STRING"

echo "  -> Disease properties"
run "CREATE PROPERTY Disease.name        IF NOT EXISTS STRING"
run "CREATE PROPERTY Disease.mesh_id     IF NOT EXISTS STRING"
run "CREATE PROPERTY Disease.category    IF NOT EXISTS STRING"
run "CREATE PROPERTY Disease.description IF NOT EXISTS STRING"
run "CREATE PROPERTY Disease.prevalence  IF NOT EXISTS STRING"

echo "  -> Gene properties"
run "CREATE PROPERTY Gene.symbol     IF NOT EXISTS STRING"
run "CREATE PROPERTY Gene.name       IF NOT EXISTS STRING"
run "CREATE PROPERTY Gene.ncbi_id    IF NOT EXISTS STRING"
run "CREATE PROPERTY Gene.chromosome IF NOT EXISTS STRING"
run "CREATE PROPERTY Gene.function   IF NOT EXISTS STRING"
run "CREATE PROPERTY Gene.gene_type  IF NOT EXISTS STRING"

echo "  -> Edge types (all 7)"
run "CREATE EDGE TYPE TREATS          IF NOT EXISTS"
run "CREATE EDGE TYPE TARGETS         IF NOT EXISTS"
run "CREATE EDGE TYPE ASSOCIATED_WITH IF NOT EXISTS"
run "CREATE EDGE TYPE CAUSED_BY       IF NOT EXISTS"
run "CREATE EDGE TYPE INTERACTS_WITH  IF NOT EXISTS"
run "CREATE EDGE TYPE HAS_SYMPTOM     IF NOT EXISTS"
run "CREATE EDGE TYPE BIOMARKER_OF    IF NOT EXISTS"

echo "  -> Edge properties"
for ETYPE in TREATS TARGETS ASSOCIATED_WITH CAUSED_BY INTERACTS_WITH HAS_SYMPTOM BIOMARKER_OF; do
  run "CREATE PROPERTY ${ETYPE}.confidence_score IF NOT EXISTS FLOAT"
  run "CREATE PROPERTY ${ETYPE}.source           IF NOT EXISTS STRING"
  run "CREATE PROPERTY ${ETYPE}.evidence_type    IF NOT EXISTS STRING"
  run "CREATE PROPERTY ${ETYPE}.year             IF NOT EXISTS INTEGER"
done

echo "  -> Indexes"
run "CREATE INDEX IF NOT EXISTS ON Drug(name)    NOTUNIQUE"
run "CREATE INDEX IF NOT EXISTS ON Disease(name) NOTUNIQUE"
run "CREATE INDEX IF NOT EXISTS ON Gene(symbol)  NOTUNIQUE"
run "CREATE INDEX IF NOT EXISTS ON Gene(name)    NOTUNIQUE"

echo "Schema done."

# ═════════════════════════════════════════════════════════════════════
# 3. DATA
# ═════════════════════════════════════════════════════════════════════
echo ""
echo "[3/3] Inserting data ..."

# ── Drugs (15) ────────────────────────────────────────────────────────
echo "  -> Drugs"
run "INSERT INTO Drug SET name='Metformin', formula='C4H11N5', mechanism='AMPK activation, reduces hepatic glucose production', fda_approved=true, drug_class='Biguanide', description='First-line oral antidiabetic drug for type 2 diabetes'"
run "INSERT INTO Drug SET name='Ibuprofen', formula='C13H18O2', mechanism='COX-1/COX-2 inhibition, reduces prostaglandin synthesis', fda_approved=true, drug_class='NSAID', description='Non-steroidal anti-inflammatory drug used for pain and fever'"
run "INSERT INTO Drug SET name='Aspirin', formula='C9H8O4', mechanism='Irreversible COX inhibition, acetylation of serine residue', fda_approved=true, drug_class='NSAID/Antiplatelet', description='Analgesic, antipyretic, antiplatelet and anti-inflammatory drug'"
run "INSERT INTO Drug SET name='Erlotinib', formula='C22H23N3O4', mechanism='EGFR tyrosine kinase inhibitor, blocks cell proliferation signaling', fda_approved=true, drug_class='Tyrosine Kinase Inhibitor', description='Targeted therapy for non-small cell lung cancer with EGFR mutations'"
run "INSERT INTO Drug SET name='Trastuzumab', formula='Monoclonal antibody', mechanism='HER2 receptor antagonist, prevents downstream signaling', fda_approved=true, drug_class='Monoclonal Antibody', description='Targeted therapy for HER2-positive breast cancer'"
run "INSERT INTO Drug SET name='Tamoxifen', formula='C26H29NO', mechanism='Selective estrogen receptor modulator (SERM)', fda_approved=true, drug_class='SERM', description='Hormone therapy for estrogen receptor-positive breast cancer'"
run "INSERT INTO Drug SET name='Donepezil', formula='C24H29NO3', mechanism='Acetylcholinesterase inhibitor, increases ACh levels in brain', fda_approved=true, drug_class='Cholinesterase Inhibitor', description='Treatment for Alzheimers disease symptoms'"
run "INSERT INTO Drug SET name='Levodopa', formula='C9H11NO4', mechanism='Dopamine precursor, crosses BBB and converts to dopamine', fda_approved=true, drug_class='Dopamine Precursor', description='Primary treatment for Parkinson disease motor symptoms'"
run "INSERT INTO Drug SET name='Atorvastatin', formula='C33H35FN2O5', mechanism='HMG-CoA reductase inhibitor, reduces cholesterol synthesis', fda_approved=true, drug_class='Statin', description='Widely prescribed drug for hypercholesterolemia and cardiovascular risk'"
run "INSERT INTO Drug SET name='Pembrolizumab', formula='Monoclonal antibody', mechanism='PD-1 checkpoint inhibitor, restores T-cell anti-tumor immunity', fda_approved=true, drug_class='Immune Checkpoint Inhibitor', description='Immunotherapy for multiple cancer types including melanoma and NSCLC'"
run "INSERT INTO Drug SET name='Insulin Glargine', formula='Modified protein', mechanism='Long-acting insulin analog, binds insulin receptors', fda_approved=true, drug_class='Insulin Analog', description='Basal insulin for type 1 and type 2 diabetes management'"
run "INSERT INTO Drug SET name='Lisinopril', formula='C21H31N3O5', mechanism='ACE inhibitor, reduces angiotensin II and aldosterone', fda_approved=true, drug_class='ACE Inhibitor', description='Treatment for hypertension and heart failure'"
run "INSERT INTO Drug SET name='Warfarin', formula='C19H16O4', mechanism='Vitamin K epoxide reductase inhibitor, reduces clotting factor synthesis', fda_approved=true, drug_class='Anticoagulant', description='Oral anticoagulant for thrombosis and stroke prevention'"
run "INSERT INTO Drug SET name='Celecoxib', formula='C17H14F3N3O2S', mechanism='Selective COX-2 inhibitor, spares COX-1 pathway', fda_approved=true, drug_class='COX-2 Inhibitor', description='Anti-inflammatory with reduced GI side effects vs non-selective NSAIDs'"
run "INSERT INTO Drug SET name='Omeprazole', formula='C17H19N3O3S', mechanism='Proton pump inhibitor, irreversibly blocks H+/K+ ATPase', fda_approved=true, drug_class='Proton Pump Inhibitor', description='Treatment for GERD, peptic ulcers and H. pylori infection'"

# ── Diseases (14) ─────────────────────────────────────────────────────
echo "  -> Diseases"
run "INSERT INTO Disease SET name='Type 2 Diabetes Mellitus', mesh_id='D003924', category='Metabolic', description='Chronic metabolic disorder characterized by insulin resistance and hyperglycemia', prevalence='~422 million worldwide'"
run "INSERT INTO Disease SET name='Alzheimer Disease', mesh_id='D000544', category='Neurological', description='Progressive neurodegenerative disease causing dementia, memory loss and cognitive decline', prevalence='~55 million worldwide'"
run "INSERT INTO Disease SET name='Non-Small Cell Lung Cancer', mesh_id='D002289', category='Oncology', description='Most common type of lung cancer, includes adenocarcinoma and squamous cell carcinoma', prevalence='~2 million new cases/year'"
run "INSERT INTO Disease SET name='Breast Cancer', mesh_id='D001943', category='Oncology', description='Malignancy arising from breast tissue, most common cancer in women globally', prevalence='~2.3 million new cases/year'"
run "INSERT INTO Disease SET name='Parkinson Disease', mesh_id='D010300', category='Neurological', description='Progressive neurodegeneration affecting dopaminergic neurons in the substantia nigra', prevalence='~10 million worldwide'"
run "INSERT INTO Disease SET name='Hypercholesterolemia', mesh_id='D006937', category='Cardiovascular', description='Elevated blood cholesterol levels, major risk factor for coronary artery disease', prevalence='~1 billion worldwide'"
run "INSERT INTO Disease SET name='Hypertension', mesh_id='D006973', category='Cardiovascular', description='Persistently elevated arterial blood pressure, leading cause of cardiovascular morbidity', prevalence='~1.28 billion worldwide'"
run "INSERT INTO Disease SET name='Colorectal Cancer', mesh_id='D015179', category='Oncology', description='Malignancy of the colon or rectum, often preceded by adenomatous polyps', prevalence='~1.9 million new cases/year'"
run "INSERT INTO Disease SET name='Melanoma', mesh_id='D008545', category='Oncology', description='Aggressive skin cancer arising from melanocytes, driven by UV damage and mutations', prevalence='~325,000 new cases/year'"
run "INSERT INTO Disease SET name='Chronic Heart Failure', mesh_id='D006333', category='Cardiovascular', description='Progressive inability of the heart to pump sufficient blood to meet body demands', prevalence='~64 million worldwide'"
run "INSERT INTO Disease SET name='Peptic Ulcer Disease', mesh_id='D010437', category='Gastrointestinal', description='Mucosal erosions in stomach or duodenum caused by H. pylori or NSAIDs', prevalence='~4 million in USA'"
run "INSERT INTO Disease SET name='Rheumatoid Arthritis', mesh_id='D001172', category='Autoimmune', description='Chronic autoimmune disease causing joint inflammation, pain and destruction', prevalence='~18 million worldwide'"
run "INSERT INTO Disease SET name='Atrial Fibrillation', mesh_id='D001281', category='Cardiovascular', description='Irregular heart rhythm disorder increasing risk of stroke and heart failure', prevalence='~37 million worldwide'"
run "INSERT INTO Disease SET name='Chronic Kidney Disease', mesh_id='D051436', category='Renal', description='Progressive loss of kidney function over months or years', prevalence='~850 million worldwide'"

# ── Genes (17) ────────────────────────────────────────────────────────
echo "  -> Genes"
run "INSERT INTO Gene SET symbol='BRCA1', name='Breast Cancer Gene 1', ncbi_id='672', chromosome='17q21.31', function='DNA damage repair, tumor suppression via homologous recombination', gene_type='Tumor Suppressor'"
run "INSERT INTO Gene SET symbol='TP53', name='Tumor Protein P53', ncbi_id='7157', chromosome='17p13.1', function='Cell cycle arrest, apoptosis induction, genomic guardian', gene_type='Tumor Suppressor'"
run "INSERT INTO Gene SET symbol='EGFR', name='Epidermal Growth Factor Receptor', ncbi_id='1956', chromosome='7p11.2', function='Cell proliferation signaling via RAS/MAPK and PI3K/AKT pathways', gene_type='Oncogene/Receptor'"
run "INSERT INTO Gene SET symbol='HER2', name='Human Epidermal Growth Factor Receptor 2', ncbi_id='2064', chromosome='17q12', function='Tyrosine kinase receptor driving cell growth, amplified in breast and gastric cancer', gene_type='Oncogene/Receptor'"
run "INSERT INTO Gene SET symbol='KRAS', name='Kirsten Rat Sarcoma Viral Proto-oncogene', ncbi_id='3845', chromosome='12p12.1', function='GTPase in RAS/MAPK signaling, frequently mutated in pancreatic and colorectal cancer', gene_type='Oncogene'"
run "INSERT INTO Gene SET symbol='BRAF', name='B-Raf Proto-Oncogene', ncbi_id='673', chromosome='7q34', function='Serine/threonine kinase in MAPK pathway, V600E mutation drives melanoma', gene_type='Oncogene'"
run "INSERT INTO Gene SET symbol='PTEN', name='Phosphatase and Tensin Homolog', ncbi_id='5728', chromosome='10q23.31', function='Lipid phosphatase that antagonizes PI3K/AKT pathway, negative cell growth regulator', gene_type='Tumor Suppressor'"
run "INSERT INTO Gene SET symbol='APOE', name='Apolipoprotein E', ncbi_id='348', chromosome='19q13.32', function='Lipid transport and metabolism, APOE4 allele is major Alzheimer risk factor', gene_type='Risk Gene'"
run "INSERT INTO Gene SET symbol='APP', name='Amyloid Precursor Protein', ncbi_id='351', chromosome='21q21.3', function='Precursor to amyloid beta peptides, central to Alzheimer disease pathology', gene_type='Disease Gene'"
run "INSERT INTO Gene SET symbol='SNCA', name='Synuclein Alpha', ncbi_id='6622', chromosome='4q22.1', function='Presynaptic protein; aggregation into Lewy bodies is hallmark of Parkinson disease', gene_type='Disease Gene'"
run "INSERT INTO Gene SET symbol='LRRK2', name='Leucine Rich Repeat Kinase 2', ncbi_id='120892', chromosome='12q12', function='Kinase involved in autophagy and vesicle trafficking; most common genetic cause of Parkinson', gene_type='Disease Gene'"
run "INSERT INTO Gene SET symbol='PCSK9', name='Proprotein Convertase Subtilisin/Kexin 9', ncbi_id='255738', chromosome='1p32.3', function='Degrades LDL receptors; gain-of-function mutations cause hypercholesterolemia', gene_type='Drug Target'"
run "INSERT INTO Gene SET symbol='ACE', name='Angiotensin I Converting Enzyme', ncbi_id='1636', chromosome='17q23.3', function='Converts angiotensin I to II, regulates blood pressure and fluid balance', gene_type='Drug Target'"
run "INSERT INTO Gene SET symbol='COX2', name='Cyclooxygenase-2 / PTGS2', ncbi_id='5743', chromosome='1q31.1', function='Prostaglandin synthesis enzyme upregulated in inflammation and cancer', gene_type='Drug Target'"
run "INSERT INTO Gene SET symbol='HMGCR', name='HMG-CoA Reductase', ncbi_id='3156', chromosome='5q13.3', function='Rate-limiting enzyme in cholesterol biosynthesis, target of statins', gene_type='Drug Target'"
run "INSERT INTO Gene SET symbol='PD1', name='Programmed Cell Death Protein 1 / PDCD1', ncbi_id='5133', chromosome='2q37.3', function='Immune checkpoint receptor on T-cells that suppresses immune activation when bound to PD-L1', gene_type='Immune Checkpoint'"
run "INSERT INTO Gene SET symbol='INS', name='Insulin', ncbi_id='3630', chromosome='11p15.5', function='Pancreatic hormone regulating glucose uptake; mutations cause neonatal diabetes', gene_type='Hormone Gene'"

# ── Edges: TREATS (Drug -> Disease, 16) ───────────────────────────────
echo "  -> Edges: TREATS"
run "CREATE EDGE TREATS FROM (SELECT FROM Drug WHERE name='Metformin') TO (SELECT FROM Disease WHERE name='Type 2 Diabetes Mellitus') SET confidence_score=0.99, source='FDA Label', evidence_type='Clinical Trial', year=1994"
run "CREATE EDGE TREATS FROM (SELECT FROM Drug WHERE name='Insulin Glargine') TO (SELECT FROM Disease WHERE name='Type 2 Diabetes Mellitus') SET confidence_score=0.99, source='FDA Label', evidence_type='Clinical Trial', year=2000"
run "CREATE EDGE TREATS FROM (SELECT FROM Drug WHERE name='Donepezil') TO (SELECT FROM Disease WHERE name='Alzheimer Disease') SET confidence_score=0.97, source='FDA Label', evidence_type='RCT', year=1996"
run "CREATE EDGE TREATS FROM (SELECT FROM Drug WHERE name='Erlotinib') TO (SELECT FROM Disease WHERE name='Non-Small Cell Lung Cancer') SET confidence_score=0.95, source='FDA Label', evidence_type='RCT', year=2004"
run "CREATE EDGE TREATS FROM (SELECT FROM Drug WHERE name='Trastuzumab') TO (SELECT FROM Disease WHERE name='Breast Cancer') SET confidence_score=0.98, source='FDA Label', evidence_type='RCT', year=1998"
run "CREATE EDGE TREATS FROM (SELECT FROM Drug WHERE name='Tamoxifen') TO (SELECT FROM Disease WHERE name='Breast Cancer') SET confidence_score=0.97, source='FDA Label', evidence_type='RCT', year=1977"
run "CREATE EDGE TREATS FROM (SELECT FROM Drug WHERE name='Levodopa') TO (SELECT FROM Disease WHERE name='Parkinson Disease') SET confidence_score=0.99, source='FDA Label', evidence_type='RCT', year=1970"
run "CREATE EDGE TREATS FROM (SELECT FROM Drug WHERE name='Atorvastatin') TO (SELECT FROM Disease WHERE name='Hypercholesterolemia') SET confidence_score=0.99, source='FDA Label', evidence_type='RCT', year=1996"
run "CREATE EDGE TREATS FROM (SELECT FROM Drug WHERE name='Lisinopril') TO (SELECT FROM Disease WHERE name='Hypertension') SET confidence_score=0.99, source='FDA Label', evidence_type='RCT', year=1987"
run "CREATE EDGE TREATS FROM (SELECT FROM Drug WHERE name='Lisinopril') TO (SELECT FROM Disease WHERE name='Chronic Heart Failure') SET confidence_score=0.96, source='SOLVD Trial', evidence_type='RCT', year=1991"
run "CREATE EDGE TREATS FROM (SELECT FROM Drug WHERE name='Pembrolizumab') TO (SELECT FROM Disease WHERE name='Melanoma') SET confidence_score=0.97, source='FDA Label', evidence_type='RCT', year=2014"
run "CREATE EDGE TREATS FROM (SELECT FROM Drug WHERE name='Pembrolizumab') TO (SELECT FROM Disease WHERE name='Non-Small Cell Lung Cancer') SET confidence_score=0.95, source='KEYNOTE-024', evidence_type='RCT', year=2016"
run "CREATE EDGE TREATS FROM (SELECT FROM Drug WHERE name='Celecoxib') TO (SELECT FROM Disease WHERE name='Rheumatoid Arthritis') SET confidence_score=0.94, source='FDA Label', evidence_type='RCT', year=1998"
run "CREATE EDGE TREATS FROM (SELECT FROM Drug WHERE name='Warfarin') TO (SELECT FROM Disease WHERE name='Atrial Fibrillation') SET confidence_score=0.97, source='FDA Label', evidence_type='Meta-analysis', year=1991"
run "CREATE EDGE TREATS FROM (SELECT FROM Drug WHERE name='Omeprazole') TO (SELECT FROM Disease WHERE name='Peptic Ulcer Disease') SET confidence_score=0.98, source='FDA Label', evidence_type='RCT', year=1989"
run "CREATE EDGE TREATS FROM (SELECT FROM Drug WHERE name='Ibuprofen') TO (SELECT FROM Disease WHERE name='Rheumatoid Arthritis') SET confidence_score=0.88, source='FDA Label', evidence_type='RCT', year=1974"

# ── Edges: TARGETS (Drug -> Gene, 9) ──────────────────────────────────
echo "  -> Edges: TARGETS"
run "CREATE EDGE TARGETS FROM (SELECT FROM Drug WHERE name='Erlotinib') TO (SELECT FROM Gene WHERE symbol='EGFR') SET confidence_score=0.99, source='Mechanism of Action', evidence_type='Biochemical', year=2004"
run "CREATE EDGE TARGETS FROM (SELECT FROM Drug WHERE name='Trastuzumab') TO (SELECT FROM Gene WHERE symbol='HER2') SET confidence_score=0.99, source='Mechanism of Action', evidence_type='Biochemical', year=1998"
run "CREATE EDGE TARGETS FROM (SELECT FROM Drug WHERE name='Pembrolizumab') TO (SELECT FROM Gene WHERE symbol='PD1') SET confidence_score=0.99, source='Mechanism of Action', evidence_type='Biochemical', year=2014"
run "CREATE EDGE TARGETS FROM (SELECT FROM Drug WHERE name='Atorvastatin') TO (SELECT FROM Gene WHERE symbol='HMGCR') SET confidence_score=0.99, source='Mechanism of Action', evidence_type='Biochemical', year=1996"
run "CREATE EDGE TARGETS FROM (SELECT FROM Drug WHERE name='Lisinopril') TO (SELECT FROM Gene WHERE symbol='ACE') SET confidence_score=0.99, source='Mechanism of Action', evidence_type='Biochemical', year=1987"
run "CREATE EDGE TARGETS FROM (SELECT FROM Drug WHERE name='Celecoxib') TO (SELECT FROM Gene WHERE symbol='COX2') SET confidence_score=0.99, source='Mechanism of Action', evidence_type='Biochemical', year=1998"
run "CREATE EDGE TARGETS FROM (SELECT FROM Drug WHERE name='Ibuprofen') TO (SELECT FROM Gene WHERE symbol='COX2') SET confidence_score=0.96, source='Mechanism of Action', evidence_type='Biochemical', year=1969"
run "CREATE EDGE TARGETS FROM (SELECT FROM Drug WHERE name='Aspirin') TO (SELECT FROM Gene WHERE symbol='COX2') SET confidence_score=0.95, source='Mechanism of Action', evidence_type='Biochemical', year=1971"
run "CREATE EDGE TARGETS FROM (SELECT FROM Drug WHERE name='Tamoxifen') TO (SELECT FROM Gene WHERE symbol='BRCA1') SET confidence_score=0.82, source='DrugBank', evidence_type='In Vitro', year=2003"

# ── Edges: ASSOCIATED_WITH (Gene -> Disease, 18) ──────────────────────
echo "  -> Edges: ASSOCIATED_WITH"
run "CREATE EDGE ASSOCIATED_WITH FROM (SELECT FROM Gene WHERE symbol='BRCA1') TO (SELECT FROM Disease WHERE name='Breast Cancer') SET confidence_score=0.99, source='ClinVar', evidence_type='Genetic Study', year=1994"
run "CREATE EDGE ASSOCIATED_WITH FROM (SELECT FROM Gene WHERE symbol='TP53') TO (SELECT FROM Disease WHERE name='Colorectal Cancer') SET confidence_score=0.97, source='COSMIC', evidence_type='Somatic Mutation', year=1992"
run "CREATE EDGE ASSOCIATED_WITH FROM (SELECT FROM Gene WHERE symbol='TP53') TO (SELECT FROM Disease WHERE name='Breast Cancer') SET confidence_score=0.96, source='COSMIC', evidence_type='Somatic Mutation', year=1992"
run "CREATE EDGE ASSOCIATED_WITH FROM (SELECT FROM Gene WHERE symbol='EGFR') TO (SELECT FROM Disease WHERE name='Non-Small Cell Lung Cancer') SET confidence_score=0.98, source='COSMIC', evidence_type='Driver Mutation', year=2004"
run "CREATE EDGE ASSOCIATED_WITH FROM (SELECT FROM Gene WHERE symbol='HER2') TO (SELECT FROM Disease WHERE name='Breast Cancer') SET confidence_score=0.99, source='ClinVar', evidence_type='Amplification', year=1987"
run "CREATE EDGE ASSOCIATED_WITH FROM (SELECT FROM Gene WHERE symbol='KRAS') TO (SELECT FROM Disease WHERE name='Colorectal Cancer') SET confidence_score=0.97, source='COSMIC', evidence_type='Driver Mutation', year=2006"
run "CREATE EDGE ASSOCIATED_WITH FROM (SELECT FROM Gene WHERE symbol='BRAF') TO (SELECT FROM Disease WHERE name='Melanoma') SET confidence_score=0.98, source='COSMIC', evidence_type='V600E Mutation', year=2002"
run "CREATE EDGE ASSOCIATED_WITH FROM (SELECT FROM Gene WHERE symbol='APOE') TO (SELECT FROM Disease WHERE name='Alzheimer Disease') SET confidence_score=0.97, source='GWAS Catalog', evidence_type='GWAS', year=1993"
run "CREATE EDGE ASSOCIATED_WITH FROM (SELECT FROM Gene WHERE symbol='APP') TO (SELECT FROM Disease WHERE name='Alzheimer Disease') SET confidence_score=0.99, source='ClinVar', evidence_type='Rare Variant', year=1991"
run "CREATE EDGE ASSOCIATED_WITH FROM (SELECT FROM Gene WHERE symbol='SNCA') TO (SELECT FROM Disease WHERE name='Parkinson Disease') SET confidence_score=0.99, source='ClinVar', evidence_type='Pathogenic Variant', year=1997"
run "CREATE EDGE ASSOCIATED_WITH FROM (SELECT FROM Gene WHERE symbol='LRRK2') TO (SELECT FROM Disease WHERE name='Parkinson Disease') SET confidence_score=0.98, source='ClinVar', evidence_type='Pathogenic Variant', year=2004"
run "CREATE EDGE ASSOCIATED_WITH FROM (SELECT FROM Gene WHERE symbol='PCSK9') TO (SELECT FROM Disease WHERE name='Hypercholesterolemia') SET confidence_score=0.97, source='ClinVar', evidence_type='Gain-of-function', year=2003"
run "CREATE EDGE ASSOCIATED_WITH FROM (SELECT FROM Gene WHERE symbol='ACE') TO (SELECT FROM Disease WHERE name='Hypertension') SET confidence_score=0.91, source='GWAS Catalog', evidence_type='GWAS', year=2009"
run "CREATE EDGE ASSOCIATED_WITH FROM (SELECT FROM Gene WHERE symbol='HMGCR') TO (SELECT FROM Disease WHERE name='Hypercholesterolemia') SET confidence_score=0.95, source='OMIM', evidence_type='Biochemical Pathway', year=1985"
run "CREATE EDGE ASSOCIATED_WITH FROM (SELECT FROM Gene WHERE symbol='PD1') TO (SELECT FROM Disease WHERE name='Melanoma') SET confidence_score=0.94, source='Research', evidence_type='Immunology', year=2012"
run "CREATE EDGE ASSOCIATED_WITH FROM (SELECT FROM Gene WHERE symbol='INS') TO (SELECT FROM Disease WHERE name='Type 2 Diabetes Mellitus') SET confidence_score=0.96, source='OMIM', evidence_type='Biochemical Pathway', year=1980"
run "CREATE EDGE ASSOCIATED_WITH FROM (SELECT FROM Gene WHERE symbol='COX2') TO (SELECT FROM Disease WHERE name='Colorectal Cancer') SET confidence_score=0.88, source='Research', evidence_type='Overexpression Study', year=1994"
run "CREATE EDGE ASSOCIATED_WITH FROM (SELECT FROM Gene WHERE symbol='PTEN') TO (SELECT FROM Disease WHERE name='Colorectal Cancer') SET confidence_score=0.91, source='COSMIC', evidence_type='Loss of Function', year=1998"

# ── Edges: CAUSED_BY (Disease -> Gene, 4) ────────────────────────────
echo "  -> Edges: CAUSED_BY"
run "CREATE EDGE CAUSED_BY FROM (SELECT FROM Disease WHERE name='Breast Cancer') TO (SELECT FROM Gene WHERE symbol='BRCA1') SET confidence_score=0.98, source='ClinVar', evidence_type='Hereditary Mutation', year=1994"
run "CREATE EDGE CAUSED_BY FROM (SELECT FROM Disease WHERE name='Parkinson Disease') TO (SELECT FROM Gene WHERE symbol='SNCA') SET confidence_score=0.95, source='Research', evidence_type='Protein Aggregation', year=1997"
run "CREATE EDGE CAUSED_BY FROM (SELECT FROM Disease WHERE name='Alzheimer Disease') TO (SELECT FROM Gene WHERE symbol='APP') SET confidence_score=0.96, source='ClinVar', evidence_type='Amyloid Pathway', year=1991"
run "CREATE EDGE CAUSED_BY FROM (SELECT FROM Disease WHERE name='Hypercholesterolemia') TO (SELECT FROM Gene WHERE symbol='PCSK9') SET confidence_score=0.94, source='ClinVar', evidence_type='Gain-of-function Mutation', year=2003"

# ── Edges: INTERACTS_WITH (Drug <-> Drug, 4) ──────────────────────────
echo "  -> Edges: INTERACTS_WITH"
run "CREATE EDGE INTERACTS_WITH FROM (SELECT FROM Drug WHERE name='Warfarin') TO (SELECT FROM Drug WHERE name='Aspirin') SET confidence_score=0.98, source='FDA Drug Interactions', evidence_type='PD Interaction', year=1990"
run "CREATE EDGE INTERACTS_WITH FROM (SELECT FROM Drug WHERE name='Warfarin') TO (SELECT FROM Drug WHERE name='Ibuprofen') SET confidence_score=0.97, source='FDA Drug Interactions', evidence_type='PK/PD Interaction', year=1990"
run "CREATE EDGE INTERACTS_WITH FROM (SELECT FROM Drug WHERE name='Metformin') TO (SELECT FROM Drug WHERE name='Omeprazole') SET confidence_score=0.72, source='DrugBank', evidence_type='PK Interaction', year=2009"
run "CREATE EDGE INTERACTS_WITH FROM (SELECT FROM Drug WHERE name='Aspirin') TO (SELECT FROM Drug WHERE name='Ibuprofen') SET confidence_score=0.85, source='FDA', evidence_type='PD Interaction', year=2006"

# ── Edges: BIOMARKER_OF (Gene -> Disease, 4) ─────────────────────────
echo "  -> Edges: BIOMARKER_OF"
run "CREATE EDGE BIOMARKER_OF FROM (SELECT FROM Gene WHERE symbol='EGFR') TO (SELECT FROM Disease WHERE name='Non-Small Cell Lung Cancer') SET confidence_score=0.97, source='NCCN Guidelines', evidence_type='Predictive Biomarker', year=2004"
run "CREATE EDGE BIOMARKER_OF FROM (SELECT FROM Gene WHERE symbol='BRAF') TO (SELECT FROM Disease WHERE name='Melanoma') SET confidence_score=0.98, source='NCCN Guidelines', evidence_type='Predictive Biomarker', year=2011"
run "CREATE EDGE BIOMARKER_OF FROM (SELECT FROM Gene WHERE symbol='BRCA1') TO (SELECT FROM Disease WHERE name='Breast Cancer') SET confidence_score=0.99, source='NCCN Guidelines', evidence_type='Diagnostic Biomarker', year=1996"
run "CREATE EDGE BIOMARKER_OF FROM (SELECT FROM Gene WHERE symbol='KRAS') TO (SELECT FROM Disease WHERE name='Colorectal Cancer') SET confidence_score=0.96, source='NCCN Guidelines', evidence_type='Negative Predictive Biomarker', year=2008"

# ── Edges: HAS_SYMPTOM (Disease -> Disease, 3) ───────────────────────
echo "  -> Edges: HAS_SYMPTOM"
run "CREATE EDGE HAS_SYMPTOM FROM (SELECT FROM Disease WHERE name='Type 2 Diabetes Mellitus') TO (SELECT FROM Disease WHERE name='Chronic Kidney Disease') SET confidence_score=0.91, source='Clinical Evidence', evidence_type='Comorbidity', year=2010"
run "CREATE EDGE HAS_SYMPTOM FROM (SELECT FROM Disease WHERE name='Hypertension') TO (SELECT FROM Disease WHERE name='Chronic Heart Failure') SET confidence_score=0.89, source='Clinical Evidence', evidence_type='Progression', year=2005"
run "CREATE EDGE HAS_SYMPTOM FROM (SELECT FROM Disease WHERE name='Hypertension') TO (SELECT FROM Disease WHERE name='Chronic Kidney Disease') SET confidence_score=0.88, source='Clinical Evidence', evidence_type='Comorbidity', year=2008"

# ─────────────────────────────────────────────────────────────────────
echo ""
echo "============================================"
echo "  Seeding complete!"
echo "  Vertices : 46  (15 Drugs, 14 Diseases, 17 Genes)"
echo "  Edges    : 58  (TREATS:16, TARGETS:9, ASSOC:18,"
echo "                   CAUSED_BY:4, INTERACTS:4,"
echo "                   BIOMARKER:4, HAS_SYMPTOM:3)"
echo "  Verify   : http://localhost:2480  -> ArcadeDB Studio"
echo "  Run app  : http://localhost/biomedkg/"
echo "============================================"
