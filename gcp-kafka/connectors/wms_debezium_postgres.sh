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


export DB_PASSWORD=$(kubectl get secret debezium-pg-pass -n kafka -o jsonpath='{.data.password}' | base64 --decode)


if [ -z "$DB_PASSWORD" ]; then
  echo "Error: DB_PASSWORD environment variable is not set"
  exit 1
fi

# The rest of the script uses these environment variables
curl -X PUT http://localhost:8083/connectors/source-sbx-uat-wms/config -H "Content-Type: application/json" \
-d '{
      "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
      "database.hostname": "192.168.16.8",
      "database.port": "5432",
      "database.user": "debezium",
      "database.password": "'"$DB_PASSWORD"'",
      "database.dbname": "postgres",
      "database.server.name": "postgres",
      "plugin.name": "pgoutput",
      "table.include.list": "public.storage_dockdoor_position,public.storage_bin_dockdoor,public.storage_dockdoor,public.storage_bin,public.storage_bin_type,public.storage_zone,public.storage_area_sloc,public.storage_area,public.storage_position,public.inventory,public.storage_bin_fixed_mapping,public.pd_pick_item,public.pd_pick_drop_mapping,public.pd_drop_item,public.task,public.session,public.worker,public.handling_unit,public.trip_relation,public.trip,public.inb_receive_item,public.ob_load_item,public.inb_palletization_item,public.inb_serialization_item,public.inb_qc_item_v2,public.ira_bin_items,public.ob_qa_lineitem", 
      "database.history.kafka.topic": "schema-changes.postgres",
      "publication.name": "dbz_publication",
      "slot.name": "dbz",

      "database.history.kafka.bootstrap.servers": "bootstrap.sbx-kafka-cluster.asia-south1.managedkafka.sbx-stag.cloud.goog:9092",
      "topic.prefix": "sbx-uat.wms",
      "slot.drop.on.stop": false,
      "schema.include.list": "public",
      "publication.autocreate.mode": "disabled",
      "tombstones.on.delete": true,
      "provide.transaction.metadata": true,
      "binary.handling.mode": "base64",
      "snapshot.mode": "initial",
      "incremental.snapshot.enabled": "true",
      "snapshot.locking.mode": "shared",
      "producer.compression.type": "lz4",
      "key.converter": "io.confluent.connect.avro.AvroConverter",
      "value.converter": "io.confluent.connect.avro.AvroConverter",
      "key.converter.schema.registry.url": "http://cp-schema-registry",
      "value.converter.schema.registry.url": "http://cp-schema-registry",
      "key.converter.basic.auth.user.info.configurable": "true",
      "key.converter.schemas.enable": "true",
      "value.converter.schemas.enable": "true",
      "topic.creation.default.replication.factor": 3,
      "topic.creation.default.partitions": 1,
      "topic.creation.default.cleanup.policy": "compact",
      "topic.creation.default.compression.type": "lz4",
      "topic.creation.default.include": ".*",
      "skipped.operations": "none",
      "producer.override.metadata.max.age.ms": "20000",
      "producer.override.request.timeout.ms": "30000",
      "producer.override.retries": "10",
      "producer.override.retry.backoff.ms": "1000",
      "producer.override.delivery.timeout.ms": "120000",
      "time.precision.mode":"connect",

      "transforms": "unwrap,ts2epoch,cast,renameDelete",
      "transforms.unwrap.type": "io.debezium.transforms.ExtractNewRecordState",
      "transforms.unwrap.drop.tombstones": "false",
      "transforms.unwrap.delete.handling.mode": "rewrite",
      "transforms.unwrap.add.fields": "__deleted",
      "transforms.ts2epoch.type": "xyz.stackbox.kafka.transforms.AllTimestamptzToEpoch",
      "transforms.cast.type": "org.apache.kafka.connect.transforms.Cast$Value",
      "transforms.cast.spec": "__deleted:boolean",
      "transforms.renameDelete.type": "org.apache.kafka.connect.transforms.ReplaceField$Value",
      "transforms.renameDelete.renames": "__deleted:is_deleted",

      "sasl.security.protocol": "SASL_SSL",
      "sasl.mechanism": "OAUTHBEARER",
      "sasl.jaas.config": "org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required clientId=\"unused\" clientSecret=\"unused\";",
      "sasl.oauthbearer.token.endpoint.url": "http://localhost:14293",
      "sasl.login.callback.handler.class": "org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginCallbackHandler",

      "consumer.sasl.security.protocol": "SASL_SSL",
      "consumer.sasl.mechanism": "OAUTHBEARER",
      "consumer.sasl.jaas.config": "org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required clientId=\"unused\" clientSecret=\"unused\";",
      "consumer.sasl.oauthbearer.token.endpoint.url": "http://localhost:14293",
      "consumer.sasl.login.callback.handler.class": "org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginCallbackHandler",

      "producer.sasl.security.protocol": "SASL_SSL",
      "producer.sasl.mechanism": "OAUTHBEARER",
      "producer.sasl.jaas.config": "org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required clientId=\"unused\" clientSecret=\"unused\";",
      "producer.sasl.oauthbearer.token.endpoint.url": "http://localhost:14293",
      "producer.sasl.login.callback.handler.class": "org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginCallbackHandler",

      "admin.sasl.security.protocol": "SASL_SSL",
      "admin.sasl.mechanism": "OAUTHBEARER",
      "admin.sasl.jaas.config": "org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required clientId=\"unused\" clientSecret=\"unused\";",
      "admin.sasl.oauthbearer.token.endpoint.url": "http://localhost:14293",
      "admin.sasl.login.callback.handler.class": "org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginCallbackHandler"
}'

# Stop port forwarding
echo "Stopping port forwarding..."
kill $PORT_FORWARD_PID

echo "Done."