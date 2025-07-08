#!/bin/bash
gcloud container clusters get-credentials services-1-staging --region asia-south1 --project sbx-stag

NAMESPACE="kafka"
LABEL="app=cp-connect"
LOCAL_PORT=8083
REMOTE_PORT=8083


echo "Finding a kafka connect pod in namespace '$NAMESPACE' with label '$LABEL'..."

# Get the first pod matching the label
POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l "$LABEL" -o jsonpath="{.items[0].metadata.name}")

if [ -z "$POD_NAME" ]; then
  echo "No pods found with label '$LABEL' in namespace '$NAMESPACE'. Exiting."
  exit 1
fi

echo "Found pod: $POD_NAME"

# Start port-forwarding
echo "Starting port forward from localhost:$LOCAL_PORT to $POD_NAME:$REMOTE_PORT..."
kubectl port-forward -n "$NAMESPACE" pod/"$POD_NAME" "$LOCAL_PORT":"$REMOTE_PORT" &
PORT_FORWARD_PID=$!

# Wait a few seconds to ensure port forwarding is active
sleep 3

# Check if port forwarding started successfully
if ! ps -p $PORT_FORWARD_PID > /dev/null; then
  echo "Port forwarding failed. Exiting."
  exit 1
fi


export CLICKHOUSE_ADMIN_PASSWORD=$(kubectl get secret clickhouse-admin -n kafka -o jsonpath='{.data.password}' | base64 --decode)
export SCHEMA_REGISTRY_AUTH=$(kubectl get secret schema-registry-credentials -n kafka -o jsonpath='{.data.credentials}' | base64 --decode)
export CLUSTER_USER_NAME=$(kubectl get secret confluent-cloud-credentials -n kafka -o jsonpath='{.data.username}' | base64 --decode)
export CLUSTER_PASSWORD=$(kubectl get secret confluent-cloud-credentials -n kafka -o jsonpath='{.data.password}' | base64 --decode)


if [ -z "$CLICKHOUSE_ADMIN_PASSWORD" ]; then
  echo "Error: CLICKHOUSE_ADMIN_PASSWORD environment variable is not set"
  exit 1
fi

if [ -z "$SCHEMA_REGISTRY_AUTH" ]; then
  echo "Error: SCHEMA_REGISTRY_AUTH environment variable is not set"
  exit 1
fi

if [ -z "$CLUSTER_USER_NAME" ]; then
  echo "Error: CLUSTER_USER_NAME environment variable is not set"
  exit 1
fi

if [ -z "$CLUSTER_PASSWORD" ]; then
  echo "Error: CLUSTER_PASSWORD environment variable is not set"
  exit 1
fi

# The rest of the script uses these environment variables
curl -X PUT http://localhost:8083/connectors/clickhouse-connect-sbx-uat-encarta/config -H "Content-Type: application/json" \
-d  '{
      "connector.class": "com.clickhouse.kafka.connect.ClickHouseSinkConnector",
      "tasks.max": "1",
      "consumer.override.max.poll.records": "5000",
      "consumer.override.max.partition.fetch.bytes": "5242880",
      "database": "sbx_uat",
      "errors.retry.timeout": "60",
      "exactlyOnce": "false",
      "hostname": "clickhouse-headless",
      "port": "8123",
      "username": "default",
      "password": "'"$CLICKHOUSE_ADMIN_PASSWORD"'",
      "topics": "sbx-uat.encarta.public.skus_master",
      "value.converter.schemas.enable": "false",
      "clickhouse.debug": "true",
      "clickhouse.log.level": "DEBUG",
      "topic2TableMap": "sbx-uat.encarta.public.skus_master=skus_master",

      "key.converter": "io.confluent.connect.avro.AvroConverter",
      "value.converter": "io.confluent.connect.avro.AvroConverter",
      "key.converter.schema.registry.url": "https://psrc-mkzxq1.asia-south1.gcp.confluent.cloud",
      "value.converter.schema.registry.url": "https://psrc-mkzxq1.asia-south1.gcp.confluent.cloud",
      "key.converter.basic.auth.credentials.source": "USER_INFO",
      "value.converter.basic.auth.credentials.source": "USER_INFO",
      "key.converter.basic.auth.user.info": "'"$SCHEMA_REGISTRY_AUTH"'",
      "value.converter.basic.auth.user.info": "'"$SCHEMA_REGISTRY_AUTH"'",

      "errors.tolerance": "all",
      "errors.log.enable": "true",
      "errors.log.include.messages": "true",

      "producer.security.protocol": "SASL_SSL",
      "producer.sasl.mechanism": "PLAIN",
      "producer.sasl.jaas.config": "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"'"$CLUSTER_USER_NAME"'\" password=\"'"$CLUSTER_PASSWORD"'\";",
  
      "consumer.security.protocol": "SASL_SSL",
      "consumer.sasl.mechanism": "PLAIN",
      "consumer.sasl.jaas.config": "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"'"$CLUSTER_USER_NAME"'\" password=\"'"$CLUSTER_PASSWORD"'\";",

      "admin.security.protocol": "SASL_SSL",
      "admin.sasl.mechanism": "PLAIN",
      "admin.sasl.jaas.config": "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"'"$CLUSTER_USER_NAME"'\" password=\"'"$CLUSTER_PASSWORD"'\";"
}'


# Stop port forwarding
echo "Stopping port forwarding..."
kill $PORT_FORWARD_PID

echo "Done."