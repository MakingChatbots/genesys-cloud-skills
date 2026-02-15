#!/bin/bash

# Download latest Genesys Cloud Platform API OpenAPI schema
# This script is intended for manual execution by humans only
#
# Usage: ./download-schema.sh [REGION]
#
# Arguments:
#   REGION - Optional. Genesys Cloud region domain (default: mypurecloud.com)
#
# Examples:
#   ./download-schema.sh                    # US region (mypurecloud.com)
#   ./download-schema.sh mypurecloud.ie     # Ireland region
#   ./download-schema.sh euw1.pure.cloud    # Europe West 1 region
#   ./download-schema.sh cac1.pure.cloud    # Canada Central 1 region
#
# Note: The API URL redirects to an S3 bucket, so we use -L to follow redirects

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments
REGION="${1:-mypurecloud.com}"

# Construct schema URL based on region
SCHEMA_URL="https://api.${REGION}/api/v2/docs/swagger"

SKILL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT_FILE="${SKILL_DIR}/schema.json"
BACKUP_FILE="${SKILL_DIR}/schema.json.backup"

echo "=================================================="
echo "Genesys Cloud Platform API Schema Downloader"
echo "=================================================="
echo "Region: $REGION"
echo ""

# Check if curl is installed
if ! command -v curl &> /dev/null; then
    echo "Error: curl is not installed. Please install curl and try again."
    exit 1
fi

# Check if jq is installed (for validation)
if ! command -v jq &> /dev/null; then
    echo "Warning: jq is not installed. Schema validation will be skipped."
    echo "Install jq to enable JSON validation: brew install jq"
    JQ_AVAILABLE=false
else
    JQ_AVAILABLE=true
fi

# Backup existing schema if it exists
if [ -f "$OUTPUT_FILE" ]; then
    echo "Backing up existing schema to schema.json.backup..."
    cp "$OUTPUT_FILE" "$BACKUP_FILE"
    echo "Backup created: $BACKUP_FILE"
    echo ""
fi

# Download the schema
echo "Downloading schema from: $SCHEMA_URL"
echo "This may take a moment (file is over 15MB)..."
echo ""

if curl -L -f -o "$OUTPUT_FILE" "$SCHEMA_URL"; then
    echo "Download completed successfully!"
    echo "Saved to: $OUTPUT_FILE"
    echo ""

    # Validate JSON if jq is available
    if [ "$JQ_AVAILABLE" = true ]; then
        echo "Validating JSON structure..."
        if jq empty "$OUTPUT_FILE" 2>/dev/null; then
            echo "✓ JSON is valid"

            # Show schema stats
            echo ""
            echo "Schema Statistics:"
            echo "------------------"

            ENDPOINT_COUNT=$(jq '.paths | length' "$OUTPUT_FILE")
            echo "Endpoints: $ENDPOINT_COUNT"

            DEFINITION_COUNT=$(jq '.definitions | length' "$OUTPUT_FILE")
            echo "Definitions: $DEFINITION_COUNT"

            FILE_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
            echo "File Size: $FILE_SIZE"

            # Show swagger version
            SWAGGER_VERSION=$(jq -r '.swagger // .openapi // "unknown"' "$OUTPUT_FILE")
            echo "Swagger/OpenAPI Version: $SWAGGER_VERSION"

        else
            echo "✗ Error: Downloaded file is not valid JSON"
            echo "Restoring backup..."
            if [ -f "$BACKUP_FILE" ]; then
                mv "$BACKUP_FILE" "$OUTPUT_FILE"
                echo "Backup restored"
            fi
            exit 1
        fi
    fi

    # Clean up backup on success
    if [ -f "$BACKUP_FILE" ]; then
        rm "$BACKUP_FILE"
    fi

    echo ""
    echo "=================================================="
    echo "Schema download complete!"
    echo "=================================================="

else
    echo "✗ Error: Failed to download schema"
    echo "Please check:"
    echo "  - Your internet connection"
    echo "  - The API URL is accessible: $SCHEMA_URL"
    echo ""

    # Restore backup if download failed
    if [ -f "$BACKUP_FILE" ]; then
        echo "Restoring backup..."
        mv "$BACKUP_FILE" "$OUTPUT_FILE"
        echo "Backup restored"
    fi

    exit 1
fi