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
export SCHEMA_REGISTRY_AUTH=$(kubectl get secret aiven-credentials -n kafka -o jsonpath='{.data.userinfo}' | base64 --decode)
export CLUSTER_USER_NAME=$(kubectl get secret aiven-credentials -n kafka -o jsonpath='{.data.username}' | base64 --decode)
export CLUSTER_PASSWORD=$(kubectl get secret aiven-credentials -n kafka -o jsonpath='{.data.password}' | base64 --decode)
export AIVEN_TRUSTSTORE=$(kubectl get secret kafka-truststore-secret -n kafka -o jsonpath='{.data.truststore-password}' | base64 --decode)


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

if [ -z "$AIVEN_TRUSTSTORE" ]; then
  echo "Error: AIVEN_TRUSTSTORE environment variable is not set"
  exit 1
fi

# The rest of the script uses these environment variables
curl -X PUT http://localhost:8083/connectors/clickhouse-connect-sbx-uat-wms/config -H "Content-Type: application/json" \
-d  '{
      "connector.class": "com.clickhouse.kafka.connect.ClickHouseSinkConnector",
      "tasks.max": "1",
      "consumer.override.max.poll.records": "5000",
      "consumer.override.max.partition.fetch.bytes": "5242880",
      "database": "sbx_uat",
      "errors.retry.timeout": "60",
      "exactlyOnce": "false",
      "hostname": "sbx-stag-clickhouse-stackbox.h.aivencloud.com",
      "port": "22155",
      "jdbcConnectionProperties": "?ssl=true",
      "username": "avnadmin",
      "password": "'"$CLICKHOUSE_ADMIN_PASSWORD"'",
      "topics": "sbx_uat.wms.public.inventory,sbx_uat.wms.public.storage_bin_summary",
      "value.converter.schemas.enable": "false",
      "clickhouse.debug": "true",
      "clickhouse.log.level": "DEBUG",
      "topic2TableMap": "sbx_uat.wms.public.inventory=inventory,sbx_uat.wms.public.storage_bin_summary=storage_bin_summary",

      "key.converter": "io.confluent.connect.avro.AvroConverter",
      "value.converter": "io.confluent.connect.avro.AvroConverter",
      "key.converter.schema.registry.url": "https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159",
      "value.converter.schema.registry.url": "https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159",
      "key.converter.basic.auth.credentials.source": "USER_INFO",
      "value.converter.basic.auth.credentials.source": "USER_INFO",
      "key.converter.basic.auth.user.info": "'"$SCHEMA_REGISTRY_AUTH"'",
      "value.converter.basic.auth.user.info": "'"$SCHEMA_REGISTRY_AUTH"'",

      "errors.tolerance": "all",
      "errors.log.enable": "true",
      "errors.log.include.messages": "true",
      "ssl.truststore.location": "/etc/kafka/secrets/kafka.truststore.jks",
      "ssl.truststore.password": "'"$AIVEN_TRUSTSTORE"'",
      "ssl.endpoint.identification.algorithm": "",

      "producer.security.protocol": "SASL_SSL",
      "producer.sasl.mechanism": "SCRAM-SHA-512",
      "producer.sasl.jaas.config": "org.apache.kafka.common.security.scram.ScramLoginModule required username=\"'"$CLUSTER_USER_NAME"'\" password=\"'"$CLUSTER_PASSWORD"'\";",
      "producer.ssl.truststore.location": "/etc/kafka/secrets/kafka.truststore.jks",
      "producer.ssl.truststore.password": "'"$AIVEN_TRUSTSTORE"'",
      "producer.ssl.endpoint.identification.algorithm": "",
  
      "consumer.security.protocol": "SASL_SSL",
      "consumer.sasl.mechanism": "SCRAM-SHA-512",
      "consumer.sasl.jaas.config": "org.apache.kafka.common.security.scram.ScramLoginModule required username=\"'"$CLUSTER_USER_NAME"'\" password=\"'"$CLUSTER_PASSWORD"'\";",
      "consumer.ssl.truststore.location": "/etc/kafka/secrets/kafka.truststore.jks",
      "consumer.ssl.truststore.password": "'"$AIVEN_TRUSTSTORE"'",
      "consumer.ssl.endpoint.identification.algorithm": "",

      "admin.security.protocol": "SASL_SSL",
      "admin.sasl.mechanism": "SCRAM-SHA-512",
      "admin.sasl.jaas.config": "org.apache.kafka.common.security.scram.ScramLoginModule required username=\"'"$CLUSTER_USER_NAME"'\" password=\"'"$CLUSTER_PASSWORD"'\";",
      "admin.ssl.truststore.location": "/etc/kafka/secrets/kafka.truststore.jks",
      "admin.ssl.truststore.password": "'"$AIVEN_TRUSTSTORE"'",
      "admin.ssl.endpoint.identification.algorithm": ""
}'

# Stop port forwarding
echo "Stopping port forwarding..."
kill $PORT_FORWARD_PID

echo "Done."