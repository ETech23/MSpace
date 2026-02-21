#!/bin/bash
# Test script for local send-notification Edge function
# Usage: ./test-send.sh

URL="http://localhost:9999"

cat <<EOF | curl -s -X POST "$URL" -H "Content-Type: application/json" -d @-
{
  "userId": "ad12651d-c1fc-44bf-9cc0-5c493dcfc8d7",
  "title": "💼 New Painter Job",
  "body": "Test job - numeric data fields",
  "type": "job",
  "data": {
    "jobId": "test-job-123",
    "distanceKm": 0.15213999394475941,
    "matchScore": 99.543580018165727,
    "extra": { "nested": true }
  }
}
EOF

echo "\n-- Done --"