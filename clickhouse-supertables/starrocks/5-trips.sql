CREATE TABLE wms_trips (
  id varchar(36) NOT NULL COMMENT "",
  sessionCreatedAt datetime NULL COMMENT "",
  whId bigint(20) NOT NULL COMMENT "",
  sessionId varchar(36) NOT NULL COMMENT "",
  createdAt datetime NULL COMMENT "",
  bbId varchar(256) NULL COMMENT "",
  code varchar(256) NOT NULL COMMENT "",
  type varchar(128) NOT NULL COMMENT "",
  priority int(11) NOT NULL COMMENT "",
  dockdoorId varchar(256) NULL COMMENT "",
  dockdoorCode varchar(256) NULL COMMENT "",
  vehicleId varchar(256) NULL COMMENT "",
  vehicleNo varchar(256) NULL COMMENT "",
  vehicleType varchar(256) NULL COMMENT "",
  deliveryDate date NULL COMMENT "",
  stagingBinId varchar(256) NULL COMMENT ""
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
