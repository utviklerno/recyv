#!/bin/sh

# Read JSON from stdin
DATA=$(cat)

# Simple validation: Check if empty
if [ -z "$DATA" ]; then
    echo "Error: No data received"
    exit 1
fi

# Send to local API
# We use the internal API_KEY which will be set in environment variables
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST http://localhost:8080/api/upload \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $API_KEY" \
    -d "$DATA")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 201 ]; then
    echo "OK"
else
    echo "Error: Server returned $HTTP_CODE"
    echo "$BODY"
    exit 1
fi
