CREATE TABLE wms_vehicle_event_trip (
  id varchar(36) NOT NULL COMMENT "",
  whId bigint(20) NOT NULL COMMENT "",
  vehicleEventId varchar(36) NOT NULL COMMENT "",
  sessionId varchar(36) NULL COMMENT "",
  tripId varchar(36) NOT NULL COMMENT "",
  tripCode varchar(256) NOT NULL COMMENT "",
  active boolean NOT NULL COMMENT "",
  createdAt datetime NULL COMMENT "",
  updatedAt datetime NULL COMMENT ""
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
