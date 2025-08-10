#!/bin/bash

KAFKA_CLUSTER_NAME="sbx-stag-kafka"
KAFKA_REST_URL="http://kafka-ui.kafka.api.staging.stackbox.internal"

# Parse command line arguments
FILTER_PATTERN=""
SKIP_CONNECT_TOPICS=true

while [[ $# -gt 0 ]]; do
  case $1 in
    --filter|-f)
      FILTER_PATTERN="$2"
      shift 2
      ;;
    --include-connect)
      SKIP_CONNECT_TOPICS=false
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [OPTIONS]"
      echo "Options:"
      echo "  --filter, -f PATTERN    Filter topics by pattern (supports regex)"
      echo "  --include-connect       Include Kafka Connect internal topics (connect-*)"
      echo "  --help, -h             Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Step 1: Get all topics with pagination
all_topics=""
page=1
page_size=100

echo "Fetching topics..."

while true; do
  topics_response=$(curl -s -X GET "${KAFKA_REST_URL}/api/clusters/${KAFKA_CLUSTER_NAME}/topics?page=${page}&perPage=${page_size}" \
    --header "Content-Type: application/json" \
    --header "Accept: application/json")
  
  # Extract topic names from current page
  page_topics=$(echo "$topics_response" | jq -r '.topics[].name' 2>/dev/null)
  
  # Check if we got any topics
  if [ -z "$page_topics" ]; then
    break
  fi
  
  # Append to all topics
  if [ -n "$all_topics" ]; then
    all_topics="${all_topics}"$'\n'"${page_topics}"
  else
    all_topics="${page_topics}"
  fi
  
  # Check if there are more pages
  total_pages=$(echo "$topics_response" | jq -r '.pageCount' 2>/dev/null)
  if [ -z "$total_pages" ] || [ "$total_pages" == "null" ] || [ "$page" -ge "$total_pages" ]; then
    break
  fi
  
  page=$((page + 1))
done

# Apply filters
filtered_topics="$all_topics"

# Filter out Kafka Connect topics if requested
if [ "$SKIP_CONNECT_TOPICS" = true ]; then
  filtered_topics=$(echo "$filtered_topics" | grep -v '^connect-' 2>/dev/null)
fi

# Apply custom filter if provided
if [ -n "$FILTER_PATTERN" ]; then
  temp_filtered=$(echo "$filtered_topics" | grep -E "$FILTER_PATTERN" 2>/dev/null)
  if [ $? -ne 0 ]; then
    echo "❌ Error: Invalid filter pattern"
    exit 1
  fi
  filtered_topics="$temp_filtered"
fi

# Sort topics
topic_names=$(echo "$filtered_topics" | sort)

# Validate output
if [ -z "$topic_names" ] || [ "$topic_names" == "null" ]; then
  echo "❌ Error: No topics found or could not parse the response"
  if [ -n "$FILTER_PATTERN" ]; then
    echo "Filter applied: $FILTER_PATTERN"
  fi
  if [ "$SKIP_CONNECT_TOPICS" = true ]; then
    echo "Kafka Connect topics excluded"
  fi
  exit 1
fi

# Step 2: Display the topics
topic_count=$(echo "$topic_names" | wc -l | xargs)
echo "✅ Found $topic_count topics:"
if [ -n "$FILTER_PATTERN" ]; then
  echo "   Filter applied: $FILTER_PATTERN"
fi
if [ "$SKIP_CONNECT_TOPICS" = true ]; then
  echo "   Kafka Connect topics excluded"
fi
echo "$topic_names"

# Step 3: Confirm deletion
read -p "Do you want to delete these $topic_count topics? (y/N): " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
  echo "Deletion cancelled"
  exit 0
fi

# Step 4: Delete each topic
for topic in $topic_names; do
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