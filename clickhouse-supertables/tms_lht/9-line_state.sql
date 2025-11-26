-- ClickHouse table for Line State
-- Dimension table for Line State information
-- Source: tms.public.line_state

CREATE TABLE IF NOT EXISTS tms_lht_line_state
(
    id String DEFAULT '',
    ord_line_id String DEFAULT '',
    prev_state_id String DEFAULT '',
    state String DEFAULT 'UNPLANNED',
    blocked Bool DEFAULT false,
    active Bool DEFAULT true,
    deleted Bool DEFAULT false,
    node_id String DEFAULT '',
    created_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updated_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3)
)
ENGINE = ReplacingMergeTree(updated_at)   
PARTITION BY toYYYYMM(created_at)
ORDER BY (id)
SETTINGS index_granularity = 8192;