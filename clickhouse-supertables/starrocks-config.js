// StarRocks Sink Connector Configurations
// This file defines all the connector configurations for StarRocks sink

const starrocksBaseConfig = {
  'connector.class': 'com.starrocks.connector.kafka.StarRocksSinkConnector',
  
  // StarRocks Stream Load specific settings
  'sink.properties.strip_outer_array': 'true',
  
  // Avro converter settings
  'key.converter': 'io.confluent.connect.avro.AvroConverter',
  'value.converter': 'io.confluent.connect.avro.AvroConverter',
  'value.converter.schemas.enable': 'true',
  'value.converter.use.logical.type.converters': 'true',
  'key.converter.basic.auth.credentials.source': 'USER_INFO',
  'value.converter.basic.auth.credentials.source': 'USER_INFO',

  // Single Message Transforms to exclude CDC metadata columns
  'transforms': 'dropCDCFields',
  'transforms.dropCDCFields.type': 'org.apache.kafka.connect.transforms.ReplaceField$Value',
  'transforms.dropCDCFields.exclude': '__op,__source_ts_ms,__deleted',

  // Error handling
  'errors.tolerance': 'none',
  'errors.log.enable': 'true',
  'errors.log.include.messages': 'true',
  'errors.deadletterqueue.topic.replication.factor': '1',

  // Consumer security settings
  'consumer.security.protocol': 'SASL_SSL',
  'consumer.sasl.mechanism': 'SCRAM-SHA-512',
  'consumer.ssl.truststore.location': '/etc/kafka/secrets/kafka.truststore.jks',
  'consumer.ssl.endpoint.identification.algorithm': ''
};

const starrocksDefaultPerformanceConfig = {
  'tasks.max': '1',
  'sink.properties.max_retries': '3',
  'sink.properties.max.batch.rows': '50000',
  'sink.properties.connect.timeout.ms': '30000',
  'consumer.override.max.poll.records': '50000',
  'consumer.override.max.partition.fetch.bytes': '20971520'
};

// StarRocks sink configurations - mirror critical tables from ClickHouse
const starrocksSinkConfigurations = {
  'wms-commons': {
    service: 'wms',
    topicMappings: [
      { namespace: 'public', topic: 'ob_load_item', table: 'wms_ob_load_item' },
      { namespace: 'public', topic: 'ob_order', table: 'wms_ob_order' },
      { namespace: 'public', topic: 'ob_order_lineitem', table: 'wms_ob_order_lineitem' },
      { namespace: 'public', topic: 'task', table: 'wms_tasks' },
      { namespace: 'public', topic: 'trip', table: 'wms_trips' },
      { namespace: 'public', topic: 'vehicle_event_trip', table: 'wms_vehicle_event_trip' },
      { namespace: 'public', topic: 'vehicle_event', table: 'wms_vehicle_event' }
    ],
    dlqTopic: 'dlq-wms-starrocks-commons',
    performanceConfig: starrocksDefaultPerformanceConfig
  }
};

// Generate topics list and topic-to-table mapping for StarRocks
function generateStarRocksTopicMappings(sinkConfig) {
  const topicPrefix = process.env.TOPIC_PREFIX;
  const { service, topicMappings, topicFormat } = sinkConfig;
  const topics = [];
  const topic2TableMap = [];

  topicMappings.forEach(mapping => {
    let fullTopic;

    if (topicFormat === 'combined') {
      fullTopic = `${topicPrefix}.${service}.${mapping.topic}`;
    } else {
      fullTopic = `${topicPrefix}.${service}.${mapping.namespace}.${mapping.topic}`;
    }

    topics.push(fullTopic);
    topic2TableMap.push(`${fullTopic}:${mapping.table}`); // StarRocks uses colon separator
  });

  return {
    topics: topics.join(','),
    topic2TableMap: topic2TableMap.join(',')
  };
}

// Build complete StarRocks connector configuration
function buildStarRocksConfig(sinkConfig) {
  const { topics, topic2TableMap } = generateStarRocksTopicMappings(sinkConfig);

  const config = {
    ...starrocksBaseConfig,
    ...sinkConfig.performanceConfig,

    // StarRocks connection settings from process.env
    'starrocks.http.url': process.env.STARROCKS_HTTP_URL || `${process.env.STARROCKS_FE_HOST}:${process.env.STARROCKS_HTTP_PORT}`,
    'starrocks.username': process.env.STARROCKS_USER,
    'starrocks.password': process.env.STARROCKS_PASSWORD,
    'starrocks.database.name': process.env.STARROCKS_DATABASE,

    // Backend load URL for Stream Load (required for Kubernetes deployments)
    'sink.properties.load-url': process.env.STARROCKS_BE_LOAD_URL || `${process.env.STARROCKS_BE_HOST}:${process.env.STARROCKS_BE_PORT}`,

    // Topics and table mappings
    topics,
    'starrocks.topic2table.map': topic2TableMap,

    // Schema Registry from process.env
    'key.converter.schema.registry.url': process.env.SCHEMA_REGISTRY_URL,
    'value.converter.schema.registry.url': process.env.SCHEMA_REGISTRY_URL,
    'key.converter.basic.auth.user.info': process.env.SCHEMA_REGISTRY_AUTH,
    'value.converter.basic.auth.user.info': process.env.SCHEMA_REGISTRY_AUTH,

    // Consumer settings from process.env
    'consumer.sasl.jaas.config': `org.apache.kafka.common.security.scram.ScramLoginModule required username="${process.env.CLUSTER_USER_NAME}" password="${process.env.CLUSTER_PASSWORD}";`,
    'consumer.ssl.truststore.password': process.env.AIVEN_TRUSTSTORE_PASSWORD
  };

  // Add DLQ topic if specified
  if (sinkConfig.dlqTopic) {
    config['errors.deadletterqueue.topic.name'] = sinkConfig.dlqTopic;
  }

  return config;
}

export {
  starrocksBaseConfig,
  starrocksDefaultPerformanceConfig,
  starrocksSinkConfigurations,
  buildStarRocksConfig
};
