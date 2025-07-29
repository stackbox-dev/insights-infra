#!/bin/bash
gcloud container clusters get-credentials services-1-staging --region asia-south1 --project sbx-stag

export SCHEMA_REGISTRY_AUTH=$(kubectl get secret schema-registry-credentials -n kafka -o jsonpath='{.data.credentials}' | base64 --decode)

if [ -z "$SCHEMA_REGISTRY_AUTH" ]; then
  echo "Error: SCHEMA_REGISTRY_AUTH environment variable is not set"
  exit 1
fi

SCHEMA_REGISTRY_URL="https://psrc-mkzxq1.asia-south1.gcp.confluent.cloud"
KAFKA_CLUSTER_NAME="sbx-stag-kafka"

# Step 1: Get all subjects
subjects=$(curl -s -u "$SCHEMA_REGISTRY_AUTH" "$SCHEMA_REGISTRY_URL/subjects")

# Step 2: Sort subjects: value schemas first, key schemas later
sorted_subjects=$(echo "$subjects" | jq -r '.[]' | sort -r -t '-' -k2)

echo "Found subjects: $sorted_subjects"

# Step 2: Loop through and delete each subject
for subject in $sorted_subjects; do
  echo -n "Deleting subject: $subject ... "
  # status=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "http://kafka-ui.kafka.api.staging.stackbox.internal/api/clusters/${KAFKA_CLUSTER_NAME}/schemas/$subject")
  status=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE -u "$SCHEMA_REGISTRY_AUTH" "$SCHEMA_REGISTRY_URL/subjects/$subject")

  if [ "$status" = "200" ]; then
    echo "✅ Deleted"
  elif [ "$status" = "404" ]; then
    echo "⚠️ Not Found"
  else
    echo "❌ Error (HTTP $status)"
  fi
done