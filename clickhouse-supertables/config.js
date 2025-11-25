// ClickHouse Sink Connector Configurations
// This file defines all the connector configurations with common base settings

const baseConfig = {
  'connector.class': 'com.clickhouse.kafka.connect.ClickHouseSinkConnector',
  exactlyOnce: 'false',
  ssl: 'true',

  // Tombstone filtering to handle ClickHouse connector bug
  transforms: 'dropNull',
  'transforms.dropNull.type': 'org.apache.kafka.connect.transforms.Filter',
  'transforms.dropNull.predicate': 'isNullRecord',
  predicates: 'isNullRecord',
  'predicates.isNullRecord.type': 'org.apache.kafka.connect.transforms.predicates.RecordIsTombstone',

  // Avro converter settings
  'key.converter': 'io.confluent.connect.avro.AvroConverter',
  'value.converter': 'io.confluent.connect.avro.AvroConverter',
  'value.converter.schemas.enable': 'true',
  'value.converter.use.logical.type.converters': 'true',
  'key.converter.basic.auth.credentials.source': 'USER_INFO',
  'value.converter.basic.auth.credentials.source': 'USER_INFO',

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

const defaultPerformanceConfig = {
  'tasks.max': '2',
  bufferFlushTime: '30000',
  bufferSize: '100000',
  clickhouseSettings: 'date_time_input_format=best_effort,max_insert_block_size=100000',
  'consumer.override.max.poll.records': '50000',
  'consumer.override.max.partition.fetch.bytes': '20971520'
};

const sinkConfigurations = {
  'wms-inventory': {
    service: 'wms',
    topicMappings: [
      { namespace: 'flink', topic: 'inventory_events_staging', table: 'wms_inventory_events_staging' }
    ],
    dlqTopic: 'dlq-wms-clickhouse-inventory',
    performanceConfig: defaultPerformanceConfig
  },

  'wms-pick-drop': {
    service: 'wms',
    topicMappings: [
      { namespace: 'flink', topic: 'pick_drop_staging', table: 'wms_pick_drop_staging' },
      { namespace: 'public', topic: 'pd_drop_item', table: 'wms_pd_drop_item' },
      { namespace: 'public', topic: 'pd_pick_item', table: 'wms_pd_pick_item' }
    ],
    dlqTopic: 'dlq-wms-clickhouse-pick-drop',
    performanceConfig: defaultPerformanceConfig
  },

  'wms-storage': {
    service: 'wms',
    topicMappings: [
      { namespace: 'public', topic: 'storage_area_sloc', table: 'wms_storage_area_sloc' },
      { namespace: 'flink', topic: 'storage_bin_master', table: 'wms_storage_bin_master' },
      { namespace: 'flink', topic: 'storage_bin_dockdoor_master', table: 'wms_storage_bin_dockdoor_master' }
    ],
    dlqTopic: 'dlq-wms-clickhouse-storage',
    performanceConfig: {
      ...defaultPerformanceConfig,
      'tasks.max': '1'
    }
  },

  'wms-workstation': {
    service: 'wms',
    topicMappings: [
      { namespace: 'flink', topic: 'workstation_events_staging', table: 'wms_workstation_events_staging' }
    ],
    dlqTopic: 'dlq-wms-clickhouse-workstation',
    performanceConfig: defaultPerformanceConfig
  },

  'wms-commons': {
    service: 'wms',
    topicMappings: [
      { namespace: 'public', topic: 'handling_unit_kind', table: 'wms_handling_unit_kinds' },
      { namespace: 'public', topic: 'handling_unit', table: 'wms_handling_units' },
      { namespace: 'public', topic: 'session', table: 'wms_sessions' },
      { namespace: 'public', topic: 'task', table: 'wms_tasks' },
      { namespace: 'public', topic: 'trip', table: 'wms_trips' },
      { namespace: 'public', topic: 'trip_relation', table: 'wms_trip_relations' },
      { namespace: 'public', topic: 'worker', table: 'wms_workers' },
      { namespace: 'public', topic: 'inb_asn', table: 'wms_inb_asn' },
      { namespace: 'public', topic: 'inb_asn_lineitem', table: 'wms_inb_asn_lineitem' },
      { namespace: 'public', topic: 'po_oms_allocation', table: 'wms_po_oms_allocation' },
      { namespace: 'public', topic: 'inb_grn_line', table: 'wms_inb_grn_line' },
      { namespace: 'public', topic: 'inb_receive_item', table: 'wms_inb_receive_item' },
      { namespace: 'public', topic: 'invoice', table: 'wms_invoices' },
      { namespace: 'public', topic: 'invoice_line', table: 'wms_invoice_line' },
      { namespace: 'public', topic: 'inb_palletization_item', table: 'wms_inb_palletization_item' },
      { namespace: 'public', topic: 'inb_qc_item_v2', table: 'wms_inb_qc_item_v2' },
      { namespace: 'public', topic: 'ob_load_item', table: 'wms_ob_load_item' },
      { namespace: 'public', topic: 'inb_serialization_item', table: 'wms_inb_serialization_item' },
      { namespace: 'public', topic: 'sbl_demand_packed', table: 'wms_sbl_demand_packed' },
      { namespace: 'public', topic: 'sbl_demand', table: 'wms_sbl_demand' },
      { namespace: 'public', topic: 'bbulk_ptl_demand_packed', table: 'wms_bbulk_ptl_demand_packed' },
      { namespace: 'public', topic: 'ob_qc_chu', table: 'wms_ob_qc_chu' },
      { namespace: 'public', topic: 'wave_olg_invoice_line', table: 'wms_wave_olg_invoice_line' },
      { namespace: 'public', topic: 'vehicle_event', table: 'wms_vehicle_event' },
      { namespace: 'public', topic: 'ob_chu', table: 'wms_ob_chu' },
      { namespace: 'public', topic: 'ob_chu_line', table: 'wms_ob_chu_line' },
      { namespace: 'public', topic: 'seg_item', table: 'wms_seg_item' },
      { namespace: 'public', topic: 'seg_group', table: 'wms_seg_group' },
      { namespace: 'public', topic: 'seg_container', table: 'wms_seg_container' },
      { namespace: 'public', topic: 'yms_trip', table: 'wms_yms_trip' },
      { namespace: 'public', topic: 'exception_bin', table: 'wms_exception_bin' },
      { namespace: 'public', topic: 'exception_hu', table: 'wms_exception_hu' },
      { namespace: 'public', topic: 'exception_manual_assignment', table: 'wms_exception_manual_assignment' },
      { namespace: 'public', topic: 'ira_approval', table: 'wms_ira_approval' },
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
      { namespace: 'public', topic: 'vehicle_event_trip', table: 'wms_vehicle_event_trip' },
      { namespace: 'public', topic: 'mhe', table: 'wms_mhe' },
      { namespace: 'public', topic: 'mhe_kind', table: 'wms_mhe_kind' },
      { namespace: 'public', topic: 'inb_grn', table: 'wms_inb_grn' },
      { namespace: 'public', topic: 'ira_bin_items', table: 'wms_ira_bin_items' },
      { namespace: 'public', topic: 'vehicle_parking', table: 'wms_vehicle_parking' },
      { namespace: 'public', topic: 'pd_provisional_item', table: 'wms_pd_provisional_item' },
      { namespace: 'public', topic: 'worker_active_time', table: 'wms_worker_active_time' },
      { namespace: 'public', topic: 'worker_productivity', table: 'wms_worker_productivity' },
      { namespace: 'public', topic: 'ob_gin', table: 'wms_ob_gin' },
      { namespace: 'public', topic: 'worker_mhe_mapping', table: 'wms_worker_mhe_mapping' },
      { namespace: 'public', topic: 'worker_device_session', table: 'wms_worker_device_session' },
      { namespace: 'public', topic: 'task_worker_assignment', table: 'wms_task_worker_assignment' },
      { namespace: 'public', topic: 'ob_order', table: 'wms_ob_order' },
      { namespace: 'public', topic: 'ob_order_progress', table: 'wms_ob_order_progress' },
      { namespace: 'public', topic: 'ob_order_lineitem', table: 'wms_ob_order_lineitem' },
      { namespace: 'public', topic: 'ob_load_unpick_item', table: 'wms_ob_load_unpick_item' },
      { namespace: 'public', topic: 'ob_gin_line', table: 'wms_ob_gin_line' }
    ],
    dlqTopic: 'dlq-wms-clickhouse-commons',
    performanceConfig: defaultPerformanceConfig
  },

  encarta: {
    service: 'encarta',
    topicMappings: [
      { namespace: 'flink', topic: 'skus_master', table: 'encarta_skus_master' },
      { namespace: 'flink', topic: 'skus_overrides', table: 'encarta_skus_overrides' },
      { namespace: 'public', topic: 'batches', table: 'encarta_batches' },
      { namespace: 'public', topic: 'products', table: 'encarta_products' },
      { namespace: 'public', topic: 'uoms', table: 'encarta_uoms' }
    ],
    dlqTopic: 'dlq-encarta-clickhouse',
    performanceConfig: {
      ...defaultPerformanceConfig,
      'tasks.max': '1'
    }
  },

  oms: {
    service: 'oms',
    topicMappings: [
      { namespace: 'public', topic: 'ord', table: 'oms_ord' },
      { namespace: 'public', topic: 'line', table: 'oms_line' },
      { namespace: 'public', topic: 'allocation_line', table: 'oms_allocation_line' },
      { namespace: 'public', topic: 'allocation_run', table: 'oms_allocation_run' },
      { namespace: 'public', topic: 'inv', table: 'oms_inv' },
      { namespace: 'public', topic: 'inv_line', table: 'oms_inv_line' },
      { namespace: 'public', topic: 'shipment_input', table: 'oms_shipment_input' },
      { namespace: 'public', topic: 'shipment_output', table: 'oms_shipment_output' },
      { namespace: 'public', topic: 'wms_dock_line', table: 'oms_wms_dock_line' }
    ],
    dlqTopic: 'dlq-oms-clickhouse',
    performanceConfig: defaultPerformanceConfig
  },

  tms: {
    service: 'tms',
    topicMappings: [
      { namespace: 'public', topic: 'invoice', table: 'tms_invoice' },
      { namespace: 'public', topic: 'invoice_state', table: 'tms_invoice_state' },
      { namespace: 'public', topic: 'invoice_line', table: 'tms_invoice_line' },
      { namespace: 'public', topic: 'load', table: 'tms_load' },
      { namespace: 'public', topic: 'load_line', table: 'tms_load_line' },
      { namespace: 'public', topic: 'ord', table: 'tms_ord' },
      { namespace: 'public', topic: 'ord_state', table: 'tms_ord_state' },
      { namespace: 'public', topic: 'line', table: 'tms_line' },
      { namespace: 'public', topic: 'line_state', table: 'tms_line_state' },
      { namespace: 'public', topic: 'contract', table: 'tms_contract' },
      { namespace: 'public', topic: 'contract_line', table: 'tms_contract_line' }
    ],
    dlqTopic: 'dlq-tms-clickhouse',
    performanceConfig: defaultPerformanceConfig
  },

  razum: {
    service: 'razum',
    topicMappings: [
      { namespace: 'public', topic: 'market_activity', table: 'razum_market_activity' },
      { namespace: 'public', topic: 'retailer_activity', table: 'razum_retailer_activity' },
      { namespace: 'public', topic: 'metrics', table: 'razum_metrics' }
    ],
    dlqTopic: 'dlq-razum-clickhouse',
    performanceConfig: defaultPerformanceConfig
  },

  backbone: {
    service: 'backbone',
    topicMappings: [
      { namespace: 'public', topic: 'retailer', table: 'backbone_retailer' },
      { namespace: 'public', topic: 'skuMaster', table: 'backbone_skuMaster' },
      { namespace: 'public', topic: 'picklistRetailer', table: 'backbone_picklistRetailer' },
      { namespace: 'public', topic: 'trip_invoice', table: 'backbone_trip_invoice' },
      { namespace: 'public', topic: 'picklist', table: 'backbone_picklist' },
      { namespace: 'public', topic: 'plan', table: 'backbone_plan' },
      { namespace: 'public', topic: 'picklistAssignment', table: 'backbone_picklistAssignment' },
      { namespace: 'public', topic: 'vehicle', table: 'backbone_vehicle' },
      { namespace: 'public', topic: 'vehicleType', table: 'backbone_vehicleType' },
      { namespace: 'public', topic: 'invoice', table: 'backbone_invoice' },
      { namespace: 'public', topic: 'invoiceState', table: 'backbone_invoiceState' },
      { namespace: 'public', topic: 'lineItem', table: 'backbone_lineItem' },
      { namespace: 'public', topic: 'node', table: 'backbone_node' },
      { namespace: 'public', topic: 'node_closure', table: 'backbone_node_closure' },
      { namespace: 'public', topic: 'planProfile', table: 'backbone_planProfile' },
      { namespace: 'public', topic: 'orderUpload', table: 'backbone_orderUpload' },
      { namespace: 'public', topic: 'invoiceExtras', table: 'backbone_invoiceExtras' },
      { namespace: 'public', topic: 'line_item_state', table: 'backbone_line_item_state' },
      { namespace: 'public', topic: 'odometer', table: 'backbone_odometer' },
      { namespace: 'public', topic: 'invoice_tray', table: 'backbone_invoice_tray' },
      { namespace: 'public', topic: 'extvehicleevents', table: 'backbone_extvehicleevents' }
    ],
    dlqTopic: 'dlq-backbone-clickhouse',
    performanceConfig: defaultPerformanceConfig
  }
};

// Generate topics list and topic-to-table mapping
function generateTopicMappings(sinkConfig) {
  const topicPrefix = process.env.TOPIC_PREFIX;
  const { service, topicMappings, topicFormat } = sinkConfig;
  const topics = [];
  const topic2TableMap = [];

  topicMappings.forEach(mapping => {
    let fullTopic;

    if (topicFormat === 'combined') {
      // Format: ${TOPIC_PREFIX}.${SERVICE}.${TOPIC}
      fullTopic = `${topicPrefix}.${service}.${mapping.topic}`;
    } else {
      // Standard format: ${TOPIC_PREFIX}.${SERVICE}.${NAMESPACE}.${TOPIC}
      fullTopic = `${topicPrefix}.${service}.${mapping.namespace}.${mapping.topic}`;
    }

    topics.push(fullTopic);
    topic2TableMap.push(`${fullTopic}=${mapping.table}`);
  });

  return {
    topics: topics.join(','),
    topic2TableMap: topic2TableMap.join(',')
  };
}

// Build complete connector configuration using process.env
function buildConfig(sinkConfig) {
  const { topics, topic2TableMap } = generateTopicMappings(sinkConfig);

  const config = {
    ...baseConfig,
    ...sinkConfig.performanceConfig,

    // Connection settings from process.env
    hostname: process.env.CLICKHOUSE_HOSTNAME,
    port: process.env.CLICKHOUSE_HTTP_PORT,
    username: process.env.CLICKHOUSE_USER,
    password: process.env.CLICKHOUSE_ADMIN_PASSWORD,
    database: process.env.CLICKHOUSE_DATABASE,

    // Topics
    topics,
    topic2TableMap,

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
  baseConfig,
  defaultPerformanceConfig,
  sinkConfigurations,
  buildConfig
};
