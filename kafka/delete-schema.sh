#!/bin/bash

SCHEMA_REGISTRY_URL="http://localhost:8081"

# Fetch all subjects
subjects=$(curl -s "${SCHEMA_REGISTRY_URL}/subjects" | jq -r '.[]')

# Loop through each subject and delete it
for subject in $subjects; do
  echo "Deleting subject: $subject"
  curl -X DELETE "${SCHEMA_REGISTRY_URL}/subjects/${subject}"
done
