#!/bin/sh

# Source environment variables (API_KEY)
if [ -f /app/env.sh ]; then
    . /app/env.sh
fi

# Send to local API by piping stdin directly to curl
# -d @- tells curl to read the body from stdin
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST http://localhost:8080/api/upload \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $API_KEY" \
    -d @-)

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
# The body is everything except the last line (which is the status code)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 201 ]; then
    echo "OK"
else
    echo "Error: Server returned $HTTP_CODE"
    echo "$BODY"
    exit 1
fi
