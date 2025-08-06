#!/bin/bash

KAFKA_CLUSTER_NAME="sbx-stag-kafka"
KAFKA_REST_URL="http://kafka-ui.kafka.api.staging.stackbox.internal"

# Display menu and get user selection
echo "=================================="
echo "    Topic Configuration Update    "
echo "=================================="
echo ""
echo "Select cleanup policy to apply:"
echo "  1) Compact (keeps latest value per key)"
echo "  2) Delete (deletes old segments based on time/size)"
echo "  3) Infinite retention (never delete data)"
echo ""
read -p "Enter your choice (1-3): " choice

case $choice in
    1)
        policy="compact"
        config_json='{"configs": {"cleanup.policy": "compact"}}'
        echo "➜ Selected: Compact policy"
        ;;
    2)
        policy="delete"
        config_json='{"configs": {"cleanup.policy": "delete"}}'
        echo "➜ Selected: Delete policy"
        ;;
    3)
        policy="infinite"
        # For infinite retention: set cleanup.policy to delete but retention to -1 (infinite)
        config_json='{"configs": {"cleanup.policy": "delete", "retention.ms": "-1"}}'
        echo "➜ Selected: Infinite retention"
        ;;
    *)
        echo "❌ Invalid choice. Please run the script again and select 1, 2, or 3."
        exit 1
        ;;
esac

echo ""
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
echo ""

# Count topics (excluding internal ones)
total_topics=0
for topic in $topic_names; do
  if [[ ! "$topic" =~ ^connect-.* ]] && [[ ! "$topic" =~ ^__.* ]]; then
    ((total_topics++))
  fi
done

echo "📊 Will update $total_topics topics (excluding internal topics)"
echo ""
read -p "Do you want to proceed? (y/n): " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "❌ Operation cancelled by user"
  exit 0
fi

echo ""
# Step 4: Update each topic with selected policy
for topic in $topic_names; do
  # Skip Kafka Connect internal topics
  if [[ "$topic" =~ ^connect-.* ]]; then
    echo "Skipping Kafka Connect topic: $topic"
    continue
  fi

  # Skip internal topics
  if [[ "$topic" =~ ^__.* ]]; then
    echo "Skipping internal topic: $topic"
    continue
  fi

  echo -n "Updating topic: $topic to $policy ... "

  response=$(curl -s -w "\n%{http_code}" -X PATCH \
    "${KAFKA_REST_URL}/api/clusters/${KAFKA_CLUSTER_NAME}/topics/${topic}" \
    --header "Content-Type: application/json" \
    --data "$config_json")

  body=$(echo "$response" | head -n1)
  status=$(echo "$response" | tail -n1)

  if [ "$status" = "204" ] || [ "$status" = "200" ]; then
    echo "✅ Updated"
  elif [ "$status" = "404" ]; then
    echo "⚠️ Topic Not Found"
  elif [ "$status" = "400" ]; then
    echo "⚠️ Bad Request (possibly already set or invalid)"
    echo "↪️  Response: $body"
  else
    echo "❌ Error (HTTP $status)"
    echo "↪️  Response Body: $body"
  fi
done

echo ""
echo "✅ Topic update process completed"