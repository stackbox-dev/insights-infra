#!/bin/bash

# Set variables
CLUSTER_ID="sbx-kafka-cluster"
LOCATION="asia-south1"

# Get the list of topics
TOPICS=$(gcloud managed-kafka topics list $CLUSTER_ID --location=$LOCATION --format="value(name)")

# Check if topics exist
if [ -z "$TOPICS" ]; then
    echo "No topics found in the cluster."
    exit 0
fi

echo $TOPICS
# Loop through topics and delete each one
for TOPIC in $TOPICS; do
    echo "Deleting topic: $TOPIC"
    gcloud managed-kafka topics delete $TOPIC --cluster=$CLUSTER_ID --location=$LOCATION --quiet
    echo "Deleted $TOPIC"
done

echo "All topics deleted successfully."
