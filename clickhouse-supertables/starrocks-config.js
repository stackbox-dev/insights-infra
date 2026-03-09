// StarRocks Sink Connector Configurations
// This file defines all the connector configurations for StarRocks sink

const starrocksBaseConfig = {
  'connector.class': 'com.starrocks.connector.kafka.StarRocksSinkConnector',
  
  // StarRocks Stream Load specific settings
  'sink.properties.strip_outer_array': 'true',
  'sink.properties.format': 'json',
  'sink.properties.strict_mode': 'false',
  'sink.properties.max_filter_ratio': '0.1',
  'sink.properties.ignore_json_size': 'true',
  'sink.label-prefix': 'kafka_starrocks_sink',
  'sink.flush.interval.ms': '10000',
  'sink.flush.rows': '50000',

  // Avro converter settings
  'key.converter': 'io.confluent.connect.avro.AvroConverter',
  'value.converter': 'io.confluent.connect.avro.AvroConverter',
  'value.converter.schemas.enable': 'true',
  'key.converter.schemas.enable': 'true',
  'key.converter.basic.auth.credentials.source': 'USER_INFO',
  'value.converter.basic.auth.credentials.source': 'USER_INFO',

  // Single Message Transforms to unwrap Avro unions and exclude CDC metadata columns
  'transforms': 'unwrapUnions,dropCDCFields',
  'transforms.unwrapUnions.type': 'xyz.stackbox.kafka.transforms.UnwrapAvroUnions$Value',
  'transforms.dropCDCFields.type': 'org.apache.kafka.connect.transforms.ReplaceField$Value',
  'transforms.dropCDCFields.exclude': '__op,__source_ts_ms,__deleted,__source_snapshot',

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
      { namespace: 'public', topic: 'vehicle_event', table: 'wms_vehicle_event' },
      { namespace: 'public', topic: 'worker', table: 'wms_workers' },
      { namespace: 'public', topic: 'session', table: 'wms_sessions' },
      { namespace: 'public', topic: 'trip_relation', table: 'wms_trip_relations' },
      { namespace: 'public', topic: 'task_worker_assignment', table: 'wms_task_worker_assignment' },
      { namespace: 'public', topic: 'worker_active_time', table: 'wms_worker_active_time' },
      { namespace: 'public', topic: 'worker_productivity', table: 'wms_worker_productivity' },
      { namespace: 'public', topic: 'worker_mhe_mapping', table: 'wms_worker_mhe_mapping' },
      { namespace: 'public', topic: 'worker_device_session', table: 'wms_worker_device_session' },
      { namespace: 'public', topic: 'handling_unit', table: 'wms_handling_units' },
      { namespace: 'public', topic: 'handling_unit_kind', table: 'wms_handling_unit_kinds' },
      { namespace: 'public', topic: 'inb_asn', table: 'wms_inb_asn' },
      { namespace: 'public', topic: 'inb_asn_lineitem', table: 'wms_inb_asn_lineitem' },
      { namespace: 'public', topic: 'inb_grn', table: 'wms_inb_grn' },
      { namespace: 'public', topic: 'inb_grn_line', table: 'wms_inb_grn_line' },
      { namespace: 'public', topic: 'inb_receive_item', table: 'wms_inb_receive_item' },
      { namespace: 'public', topic: 'inb_palletization_item', table: 'wms_inb_palletization_item' },
      { namespace: 'public', topic: 'inb_qc_item_v2', table: 'wms_inb_qc_item_v2' },
      { namespace: 'public', topic: 'inb_serialization_item', table: 'wms_inb_serialization_item' },
      { namespace: 'public', topic: 'inb_unload_item', table: 'wms_inb_unload_item' },
      { namespace: 'public', topic: 'ob_chu', table: 'wms_ob_chu' },
      { namespace: 'public', topic: 'ob_chu_line', table: 'wms_ob_chu_line' },
      { namespace: 'public', topic: 'ob_gin', table: 'wms_ob_gin' },
      { namespace: 'public', topic: 'ob_gin_line', table: 'wms_ob_gin_line' },
      { namespace: 'public', topic: 'ob_load_unpick_item', table: 'wms_ob_load_unpick_item' },
      { namespace: 'public', topic: 'ob_order_progress', table: 'wms_ob_order_progress' },
      { namespace: 'public', topic: 'ob_qc_chu', table: 'wms_ob_qc_chu' },
      { namespace: 'public', topic: 'ob_qc_chu_item', table: 'wms_ob_qc_chu_item' },
      { namespace: 'public', topic: 'ob_qa_lineitem', table: 'wms_ob_qa_lineitem' },
      { namespace: 'public', topic: 'wave_olg_invoice_line', table: 'wms_wave_olg_invoice_line' },
      { namespace: 'public', topic: 'invoice', table: 'wms_invoices' },
      { namespace: 'public', topic: 'invoice_line', table: 'wms_invoice_line' },
      { namespace: 'public', topic: 'provisional_gin', table: 'wms_provisional_gin' },
      { namespace: 'public', topic: 'po_oms_allocation', table: 'wms_po_oms_allocation' },
      { namespace: 'public', topic: 'sbl_demand', table: 'wms_sbl_demand' },
      { namespace: 'public', topic: 'sbl_demand_packed', table: 'wms_sbl_demand_packed' },
      { namespace: 'public', topic: 'sbl_bin_chu', table: 'wms_sbl_bin_chu' },
      { namespace: 'public', topic: 'sbl_chu_reduction', table: 'wms_sbl_chu_reduction' },
      { namespace: 'public', topic: 'bbulk_ptl_demand', table: 'wms_bbulk_ptl_demand' },
      { namespace: 'public', topic: 'bbulk_ptl_demand_packed', table: 'wms_bbulk_ptl_demand_packed' },
      { namespace: 'public', topic: 'bbulk_ptl_bin_reduction', table: 'wms_bbulk_ptl_bin_reduction' },
      { namespace: 'public', topic: 'seg_item', table: 'wms_seg_item' },
      { namespace: 'public', topic: 'seg_group', table: 'wms_seg_group' },
      { namespace: 'public', topic: 'seg_container', table: 'wms_seg_container' },
      { namespace: 'public', topic: 'exception_bin', table: 'wms_exception_bin' },
      { namespace: 'public', topic: 'exception_hu', table: 'wms_exception_hu' },
      { namespace: 'public', topic: 'exception_manual_assignment', table: 'wms_exception_manual_assignment' },
      { namespace: 'public', topic: 'ira_approval', table: 'wms_ira_approval' },
      { namespace: 'public', topic: 'ira_bin_items', table: 'wms_ira_bin_items' },
      { namespace: 'public', topic: 'ira_bin_items_scanned_hu', table: 'wms_ira_bin_items_scanned_hu' },
      { namespace: 'public', topic: 'ira_discrepancies_config', table: 'wms_ira_discrepancies_config' },
      { namespace: 'public', topic: 'ira_manual_update', table: 'wms_ira_manual_update' },
      { namespace: 'public', topic: 'ira_record', table: 'wms_ira_record' },
      { namespace: 'public', topic: 'ira_session_progress', table: 'wms_ira_session_progress' },
      { namespace: 'public', topic: 'ira_session_sku', table: 'wms_ira_session_sku' },
      { namespace: 'public', topic: 'ira_session_summary', table: 'wms_ira_session_summary' },
      { namespace: 'public', topic: 'ira_task_bin', table: 'wms_ira_task_bin' },
      { namespace: 'public', topic: 'ira_worker_update', table: 'wms_ira_worker_update' },
      { namespace: 'public', topic: 'pl_inv_cnt_plan', table: 'wms_pl_inv_cnt_plan' },
      { namespace: 'public', topic: 'pl_inv_cnt_plan_cycle', table: 'wms_pl_inv_cnt_plan_cycle' },
      { namespace: 'public', topic: 'pl_inv_cnt_plan_seq', table: 'wms_pl_inv_cnt_plan_seq' },
      { namespace: 'public', topic: 'pln_ira_cycle_plan', table: 'wms_pln_ira_cycle_plan' },
      { namespace: 'public', topic: 'pln_ira_cycle_step', table: 'wms_pln_ira_cycle_step' },
      { namespace: 'public', topic: 'pln_ira_cycle_step_bin', table: 'wms_pln_ira_cycle_step_bin' },
      { namespace: 'public', topic: 'mhe', table: 'wms_mhe' },
      { namespace: 'public', topic: 'mhe_kind', table: 'wms_mhe_kind' },
      { namespace: 'public', topic: 'vehicle_parking', table: 'wms_vehicle_parking' },
      { namespace: 'public', topic: 'yms_trip', table: 'wms_yms_trip' },
      { namespace: 'public', topic: 'yms_asn', table: 'wms_yms_asn' },
      { namespace: 'public', topic: 'pd_provisional_item', table: 'wms_pd_provisional_item' },
      { namespace: 'public', topic: 'pd_pick_drop_mapping', table: 'wms_pd_pick_drop_mapping' },
      { namespace: 'public', topic: 'pd_pick_drop_item_inner_hu', table: 'wms_pd_pick_drop_item_inner_hu' },
      { namespace: 'public', topic: 'hht_pick_item', table: 'wms_hht_pick_item' },
      { namespace: 'public', topic: 'hht_pick_item_reduction', table: 'wms_hht_pick_item_reduction' },
      { namespace: 'public', topic: 'hht_pick_group', table: 'wms_hht_pick_group' },
      { namespace: 'public', topic: 'ccs_hu_conveyor_event', table: 'wms_ccs_hu_conveyor_event' },
      { namespace: 'public', topic: 'ccs_chu_status', table: 'wms_ccs_chu_status' },
      { namespace: 'public', topic: 'ccs_cnode', table: 'wms_ccs_cnode' },
      { namespace: 'public', topic: 'ccs_ptl_chu_visit', table: 'wms_ccs_ptl_chu_visit' },
      { namespace: 'public', topic: 'ccs_sbl_hu_visit', table: 'wms_ccs_sbl_hu_visit' },
      { namespace: 'public', topic: 'ccs_ptl_zone_inventory', table: 'wms_ccs_ptl_zone_inventory' },
      { namespace: 'public', topic: 'storage_area', table: 'wms_storage_area' },
      { namespace: 'public', topic: 'storage_zone', table: 'wms_storage_zone' },
      { namespace: 'public', topic: 'storage_bin', table: 'wms_storage_bin' },
      { namespace: 'public', topic: 'storage_bin_type', table: 'wms_storage_bin_type' },
      { namespace: 'public', topic: 'storage_bin_type_best_fit', table: 'wms_storage_bin_type_best_fit' },
      { namespace: 'public', topic: 'storage_bin_distance', table: 'wms_storage_bin_distance' },
      { namespace: 'public', topic: 'storage_bin_fixed_mapping', table: 'wms_storage_bin_fixed_mapping' },
      { namespace: 'public', topic: 'storage_bin_dockdoor', table: 'wms_storage_bin_dockdoor' },
      { namespace: 'public', topic: 'storage_dockdoor', table: 'wms_storage_dockdoor' },
      { namespace: 'public', topic: 'storage_dockdoor_position', table: 'wms_storage_dockdoor_position' },
      { namespace: 'public', topic: 'storage_position', table: 'wms_storage_position' },
      { namespace: 'public', topic: 'storage_activity_zone', table: 'wms_storage_activity_zone' },
      { namespace: 'public', topic: 'inventory', table: 'wms_inventory' },
    ],
    dlqTopic: 'dlq-wms-starrocks-commons',
    performanceConfig: starrocksDefaultPerformanceConfig
  },
  'encarta': {
    service: 'encarta',
    topicMappings: [
      { namespace: 'flink', topic: 'skus_master', table: 'encarta_skus_master' }
    ],
    dlqTopic: 'dlq-encarta-starrocks',
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
