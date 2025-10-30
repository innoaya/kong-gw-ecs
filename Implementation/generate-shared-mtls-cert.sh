#!/bin/bash
# ===============================================================
# Generate Kong Hybrid Mode Shared Certificate & Key
# for ECS / Secrets Manager (single-line escaped output, no quotes)
# ===============================================================
set -euo pipefail

CERT_NAME="kong_clustering"
CERT_DIR="certs"
DAYS_VALID=365

# Create folder for actual PEM files
mkdir -p "${CERT_DIR}"

# 1️⃣ Generate private key and self-signed certificate
openssl genrsa -out "${CERT_DIR}/${CERT_NAME}.key" 2048 >/dev/null 2>&1
openssl req -new -x509 \
  -key "${CERT_DIR}/${CERT_NAME}.key" \
  -out "${CERT_DIR}/${CERT_NAME}.crt" \
  -days "${DAYS_VALID}" \
  -subj "/CN=kong_clustering/O=KongCluster/C=US" >/dev/null 2>&1

# 2️⃣ Convert PEMs into single-line JSON-safe strings (no surrounding quotes)
# Resulting files contain plain escaped content like:
# -----BEGIN CERTIFICATE-----\nMIIC...==\n-----END CERTIFICATE-----\n
perl -0777 -pe 's/\n/\\n/g' "${CERT_DIR}/${CERT_NAME}.crt" > "CLUSTER_CERT_CONTENT.txt"
perl -0777 -pe 's/\n/\\n/g' "${CERT_DIR}/${CERT_NAME}.key" > "CLUSTER_KEY_CONTENT.txt"

# 3️⃣ Done silently
# Folder layout:
#   certs/kong_clustering.crt
#   certs/kong_clustering.key
#   CLUSTER_CERT_CONTENT.txt
#   CLUSTER_KEY_CONTENT.txt
