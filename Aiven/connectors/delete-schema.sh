#!/bin/bash
SCHEMA_REGISTRY_URL="http://kafka-ui.kafka.api.staging.stackbox.internal"
KAFKA_CLUSTER_NAME="sbx-stag-kafka"

# # Step 1: Get all subjects
schema_response=$(curl -s -X GET "${SCHEMA_REGISTRY_URL}/api/clusters/${KAFKA_CLUSTER_NAME}/schemas" \
  --header "Content-Type: application/json" \
  --header "Accept: application/json" | jq -r '.schemas[]?.subject' | grep -v null
)

# Step 2: Sort subjects: value schemas first, key schemas later
sorted_subjects=$(echo "$schema_response" | sort  -t '-' -k2,2r -k1,1)

# Validate output
if [ -z "$sorted_subjects" ] || [ "$sorted_subjects" == "null" ]; then
  echo "❌ Error: No subjects found or could not parse the response"
  echo "📦 API Response: $schema_response"
  exit 1
fi

# Step 3: Display the subjects
echo "✅ Found subjects:"
echo "$sorted_subjects"

# Step 4: Loop through and delete each subject
for subject in $sorted_subjects; do
  echo -n "Deleting subject: $subject ... "
  status=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "${SCHEMA_REGISTRY_URL}/api/clusters/${KAFKA_CLUSTER_NAME}/schemas/$subject")

  if [ "$status" = "200" ]; then
    echo "✅ Deleted"
  elif [ "$status" = "404" ]; then
    echo "⚠️ Not Found"
  else
    echo "❌ Error (HTTP $status)"
    echo "↪️  Response Body: $body"
    exit 1
  fi
done