#!/bin/bash

KAFKA_CLUSTER_NAME="sbx-stag-kafka"
KAFKA_REST_URL="http://kafka-ui.kafka.api.staging.stackbox.internal"

echo "Fetching topics..."

topics_response=$(curl -s -X GET "${KAFKA_REST_URL}/api/clusters/${KAFKA_CLUSTER_NAME}/topics" \
  --header "Content-Type: application/json" \
  --header "Accept: application/json" )

# Step 2: Extract topic names using jq
topic_names=$(echo "$topics_response" | jq -r '.topics[].name' 2>/dev/null)

# Validate output
if [ -z "$topic_names" ] || [ "$topic_names" == "null" ]; then
  echo "❌ Error: No topics found or could not parse the response"
  echo "📦 API Response: $topics_response"
  exit 1
fi

# Step 3: Display the topics
echo "✅ Found topics:"
echo "$topic_names"


# Step 4: Delete each topic
for topic in $topic_names; do
  # Skip Kafka Connect internal topics
  if [[ "$topic" =~ ^connect-.* ]]; then
    echo "Skipping Kafka Connect topic: $topic"
    continue
  fi

  echo -n "Deleting topic: $topic ... "
  response=$(curl -s -w "\n%{http_code}" -X DELETE \
    "${KAFKA_REST_URL}/api/clusters/${KAFKA_CLUSTER_NAME}/topics/${topic}" \
    --header "Content-Type: application/json")

  body=$(echo "$response" | head -n1)
  status=$(echo "$response" | tail -n1)

  if [ "$status" = "204" ] || [ "$status" = "200" ]; then
    echo "✅ Deleted"
  elif [ "$status" = "404" ]; then
    echo "⚠️ Not Found"
  else
    echo "❌ Error (HTTP $status)"
    echo "↪️  Response Body: $body"
    exit 1
  fi
done