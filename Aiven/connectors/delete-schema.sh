#!/bin/bash
SCHEMA_REGISTRY_URL="http://kafka-ui.kafka.api.staging.stackbox.internal"
KAFKA_CLUSTER_NAME="sbx-stag-kafka"

# Parse command line arguments
FILTER_PATTERN=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --filter|-f)
      FILTER_PATTERN="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: $0 [OPTIONS]"
      echo "Options:"
      echo "  --filter, -f PATTERN   Filter schemas by pattern (supports regex)"
      echo "  --help, -h            Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Step 1: Get all subjects with pagination
all_subjects=""
page=1
page_size=100

echo "Fetching schemas..."

while true; do
  schema_response=$(curl -s -X GET "${SCHEMA_REGISTRY_URL}/api/clusters/${KAFKA_CLUSTER_NAME}/schemas?page=${page}&perPage=${page_size}" \
    --header "Content-Type: application/json" \
    --header "Accept: application/json")
  
  # Extract subjects from current page
  page_subjects=$(echo "$schema_response" | jq -r '.schemas[]?.subject' 2>/dev/null | grep -v null)
  
  # Check if we got any subjects
  if [ -z "$page_subjects" ]; then
    break
  fi
  
  # Append to all subjects
  if [ -n "$all_subjects" ]; then
    all_subjects="${all_subjects}"$'\n'"${page_subjects}"
  else
    all_subjects="${page_subjects}"
  fi
  
  # Check if there are more pages
  total_pages=$(echo "$schema_response" | jq -r '.pageCount' 2>/dev/null)
  if [ -z "$total_pages" ] || [ "$total_pages" == "null" ] || [ "$page" -ge "$total_pages" ]; then
    break
  fi
  
  page=$((page + 1))
done

# Apply filter if provided
if [ -n "$FILTER_PATTERN" ]; then
  filtered_subjects=$(echo "$all_subjects" | grep -E "$FILTER_PATTERN" 2>/dev/null)
  if [ $? -ne 0 ]; then
    echo "❌ Error: Invalid filter pattern"
    exit 1
  fi
  all_subjects="$filtered_subjects"
fi

# Step 2: Sort subjects: value schemas first, key schemas later
sorted_subjects=$(echo "$all_subjects" | sort -t '-' -k2,2r -k1,1)

# Validate output
if [ -z "$sorted_subjects" ] || [ "$sorted_subjects" == "null" ]; then
  echo "❌ Error: No subjects found or could not parse the response"
  if [ -n "$FILTER_PATTERN" ]; then
    echo "Filter applied: $FILTER_PATTERN"
  fi
  exit 1
fi

# Step 3: Display the subjects
subject_count=$(echo "$sorted_subjects" | wc -l | xargs)
echo "✅ Found $subject_count subjects:"
if [ -n "$FILTER_PATTERN" ]; then
  echo "   Filter applied: $FILTER_PATTERN"
fi
echo "$sorted_subjects"

# Step 4: Confirm deletion
read -p "Do you want to delete these $subject_count schemas? (y/N): " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
  echo "Deletion cancelled"
  exit 0
fi

# Step 5: Loop through and delete each subject
for subject in $sorted_subjects; do
  echo -n "Deleting subject: $subject ... "
  response=$(curl -s -w "\n%{http_code}" -X DELETE "${SCHEMA_REGISTRY_URL}/api/clusters/${KAFKA_CLUSTER_NAME}/schemas/$subject")
  
  body=$(echo "$response" | head -n-1)
  status=$(echo "$response" | tail -n1)

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