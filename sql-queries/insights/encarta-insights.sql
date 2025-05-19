CREATE TABLE IF NOT EXISTS sbx_uat_insights.sku_unit_summary
(
    id UUID,
    "code" String,
    "ibc" String,
    "casecount" String,
    "palletcount" String
    )
ENGINE = ReplacingMergeTree()
ORDER BY ("id","code");