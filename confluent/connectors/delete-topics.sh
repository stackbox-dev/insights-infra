#!/bin/bash

KAFKA_CLUSTER_NAME="services-1-staging"
KAFKA_REST_URL="http://kafka-ui.kafka.api.staging.stackbox.internal"

echo "Fetching topics..."

topics_response=$(curl -s -X GET "${KAFKA_REST_URL}/api/clusters/${KAFKA_CLUSTER_NAME}/topics" \
  --header "Content-Type: application/json" \
  --header "Accept: application/json" )

# Step 2: Extract topic names using jq
topic_names=$(echo "$topics_response" | jq -r '.topics[].name' 2>/dev/null)

# Validate output
if [ -z "$topic_names" ] || [ "$topic_names" == "null" ]; then
  echo "Error: No topics found or could not parse the response"
  echo "API Response: $topics_response"
  exit 1
fi

# Step 3: Display the topics
echo "Found topics:"
echo "$topic_names"


# Step 4: Delete each topic
for topic in $topic_names; do
  # Skip Kafka Connect internal topics
  if [[ "$topic" =~ ^connect-.* ]]; then
    echo "Skipping Kafka Connect topic: $topic"
    continue
  fi

  echo -n "Deleting topic: $topic ... "
  status=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
          "${KAFKA_REST_URL}/api/clusters/${KAFKA_CLUSTER_NAME}/topics/${topic}")

  if [ "$status" = "204" ] || [ "$status" = "200" ]; then
    echo "✅ Deleted"
  elif [ "$status" = "404" ]; then
    echo "⚠️ Not Found"
  else
    echo "❌ Error (HTTP $status)"
  fi
done