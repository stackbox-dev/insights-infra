-- ClickHouse Table: plan
CREATE TABLE IF NOT EXISTS tms_plan
(
    id Int32 DEFAULT 0,
    orderUploadId Int32 DEFAULT 0,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    status String DEFAULT '',
    progress Int32 DEFAULT 0,
    extras String DEFAULT '{}',                  
    active Bool DEFAULT false,
    profileId Int32 DEFAULT 0,
    static String DEFAULT '{}',                 
    darwin String DEFAULT '{}', 
    wmsSortingSessionId String DEFAULT '',
    huPlanningParameters String DEFAULT '{}',
    remarks Array(String) DEFAULT [],

   
    PRIMARY KEY (id)
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;