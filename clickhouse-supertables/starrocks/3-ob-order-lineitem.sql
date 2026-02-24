CREATE TABLE wms_ob_order_lineitem (
  id varchar(36) NOT NULL COMMENT "",
  whId bigint(20) NOT NULL COMMENT "",
  orderId varchar(36) NOT NULL COMMENT "",
  skuId varchar(36) NOT NULL COMMENT "",
  uom varchar(64) NOT NULL COMMENT "",
  batch varchar(256) NOT NULL COMMENT "",
  qty int(11) NOT NULL COMMENT "",
  createdAt datetime NULL COMMENT "",
  extraFields json NOT NULL COMMENT "",
  value int(11) NOT NULL COMMENT "",
  huId varchar(36) NULL COMMENT "",
  huCode varchar(256) NULL COMMENT "",
  huWeight double NULL COMMENT "",
  deliveryOrder varchar(256) NULL COMMENT "",
  customerOrderQty int(11) NULL COMMENT "",
  deliveryOrderQty int(11) NULL COMMENT "",
  processFlag varchar(128) NULL COMMENT "",
  promoCode varchar(256) NULL COMMENT "",
  promoLineType varchar(256) NULL COMMENT "",
  ratio int(11) NULL COMMENT "",
  salesAllocationLossReceivedAt datetime NULL COMMENT "",
  deactivatedAt datetime NULL COMMENT "",
  lineCode varchar(256) NULL COMMENT "",
  deactivationReason varchar(512) NULL COMMENT "",
  iloc varchar(256) NOT NULL COMMENT "",
  invoicingQty int(11) NULL COMMENT ""
) ENGINE=OLAP 
PRIMARY KEY(id)
DISTRIBUTED BY HASH(id) BUCKETS 16 
PROPERTIES (
"compression" = "LZ4",
"enable_persistent_index" = "true",
"fast_schema_evolution" = "true",
"replicated_storage" = "true",
"replication_num" = "2"
);
