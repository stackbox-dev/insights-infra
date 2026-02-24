CREATE TABLE wms_tasks (
  id varchar(36) NOT NULL COMMENT "",
  whId bigint(20) NOT NULL COMMENT "",
  sessionId varchar(36) NOT NULL COMMENT "",
  kind varchar(128) NOT NULL COMMENT "",
  code varchar(256) NOT NULL COMMENT "",
  seq int(11) NOT NULL COMMENT "",
  exclusive boolean NOT NULL COMMENT "",
  state varchar(64) NOT NULL COMMENT "",
  attrs json NOT NULL COMMENT "",
  progress json NOT NULL COMMENT "",
  createdAt datetime NULL COMMENT "",
  updatedAt datetime NULL COMMENT "",
  active boolean NOT NULL COMMENT "",
  allowForceComplete boolean NOT NULL COMMENT "",
  autoComplete boolean NOT NULL COMMENT "",
  wave int(11) NULL COMMENT "",
  forceCompleteTaskId varchar(36) NULL COMMENT "",
  forceCompleted boolean NOT NULL COMMENT "",
  subKind varchar(128) NOT NULL COMMENT "",
  label varchar(256) NOT NULL COMMENT "",
  scope varchar(256) NULL COMMENT ""
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
