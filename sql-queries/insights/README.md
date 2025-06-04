# ✅ Step-by-Step Code to Add Two Columns to MV and Destination Table

**1. Alter the destination table to add the new columns**
```sql
ALTER TABLE sbx_uat_insights.storage_bin_summary
ADD COLUMN sb_status String,    -- Or the actual datatype (e.g., UInt8, Int32, etc.)
ADD COLUMN sbt_active UInt8;    -- Replace with correct type if different
```

**2. Drop the existing Materialized View**
```sql
DROP TABLE IF EXISTS sbx_uat_insights.mv_storage_bin_summary;
```

**3. Recreate the MV with the two new columns**
```sql
CREATE MATERIALIZED VIEW sbx_uat_insights.mv_storage_bin_summary
TO sbx_uat_insights.storage_bin_summary
AS
SELECT
    sb."whId" AS "whId",
    sb.code AS bin_code,
    sb.description AS bin_description,
    sb."multiSku",
    sb."multiBatch",
    sb."pickingPosition",
    sb."putawayPosition",
    sb.rank,
    sb.aisle,
    sb.bay,
    sb.level,
    sb.position,
    sb.depth,
    sb."maxSkuCount",
    sb."maxSkuBatchCount",
    sbt.code AS bin_type_code,
    sbt.description AS bintype_description,
    sbt."maxVolumeInCC",
    sbt."maxWeightInKG",
    sbt."palletCapacity",
    sbt."storageHUType",
    sbt."auxiliaryBin",
    sbt."huMultiSku",
    sbt."huMultiBatch",
    sbt."useDerivedPalletBestFit",
    sz.code AS zone_code,
    sz.description AS zone_description,
    sz.face AS zone_face,
    sz.peripheral,
    sz."surveillanceConfig",
    sa.code AS area_code,
    sa.description AS sa_description,
    sa.type AS area_type,
    sa."rollingDays",
    ss.x1,
    ss.x2,
    ss.y1,
    ss.y2,
    sac.quality,
    sac.sloc,
    sac."slocDescription",
    sac."clientQuality",
    sac."inventoryVisible",
    sac."erpToWMS",
    sd.code AS sd_code,
    sbd.usage,
    sbd."multiTrip",
    sd.description AS sd_description,
    sd."maxQueue",
    sd."allowInbound",
    sd."allowOutbound",
    sd."allowReturns",
    sd."incompatibleVehicleTypes",
    sd."incompatibleLoadTypes",
    sdp.x AS dockdoor_x_coordinate,
    sdp.y AS dockdoor_y_coordinate,
    sb.status AS sb_status,
    sbt.active AS sbt_active 
FROM sbx_uat_wms.storage_bin AS sb
LEFT JOIN sbx_uat_wms.storage_bin_type sbt ON sb."binTypeId" = sbt.id
LEFT JOIN sbx_uat_wms.storage_zone sz ON sb."zoneId" = sz.id
LEFT JOIN sbx_uat_wms.storage_area sa ON sz."areaId" = sa.id
LEFT JOIN sbx_uat_wms.storage_position ss ON ss."storageId" = sb.id
LEFT JOIN sbx_uat_wms.storage_area_sloc sac ON sa."whId" = sac."whId" AND sa."code" = sac."areaCode"
LEFT JOIN sbx_uat_wms.storage_bin_dockdoor sbd ON sb.id = sbd."binId"
LEFT JOIN sbx_uat_wms.storage_dockdoor sd ON sbd."dockdoorId" = sd.id
LEFT JOIN sbx_uat_wms.storage_dockdoor_position sdp ON sd."id" = sdp."dockdoorId";
```

**4. (Optional) Backfill existing data**
If needed, repopulate the storage_bin_summary table using a temporary INSERT query (assuming it's empty or append-only):

```sql
INSERT INTO sbx_uat_insights.storage_bin_summary
SELECT
    sb."whId" AS "whId",
    sb.code AS bin_code,
    sb.description AS bin_description,
    sb."multiSku",
    sb."multiBatch",
    sb."pickingPosition",
    sb."putawayPosition",
    sb.rank,
    sb.aisle,
    sb.bay,
    sb.level,
    sb.position,
    sb.depth,
    sb."maxSkuCount",
    sb."maxSkuBatchCount",
    sbt.code AS bin_type_code,
    sbt.description AS bintype_description,
    sbt."maxVolumeInCC",
    sbt."maxWeightInKG",
    sbt."palletCapacity",
    sbt."storageHUType",
    sbt."auxiliaryBin",
    sbt."huMultiSku",
    sbt."huMultiBatch",
    sbt."useDerivedPalletBestFit",
    sz.code AS zone_code,
    sz.description AS zone_description,
    sz.face AS zone_face,
    sz.peripheral,
    sz."surveillanceConfig",
    sa.code AS area_code,
    sa.description AS sa_description,
    sa.type AS area_type,
    sa."rollingDays",
    ss.x1,
    ss.x2,
    ss.y1,
    ss.y2,
    sac.quality,
    sac.sloc,
    sac."slocDescription",
    sac."clientQuality",
    sac."inventoryVisible",
    sac."erpToWMS",
    sd.code AS sd_code,
    sbd.usage,
    sbd."multiTrip",
    sd.description AS sd_description,
    sd."maxQueue",
    sd."allowInbound",
    sd."allowOutbound",
    sd."allowReturns",
    sd."incompatibleVehicleTypes",
    sd."incompatibleLoadTypes",
    sdp.x AS dockdoor_x_coordinate,
    sdp.y AS dockdoor_y_coordinate,
    sb.status AS sb_status,
    sbt.active AS sbt_active
FROM sbx_uat_wms.storage_bin AS sb
LEFT JOIN sbx_uat_wms.storage_bin_type sbt ON sb."binTypeId" = sbt.id
LEFT JOIN sbx_uat_wms.storage_zone sz ON sb."zoneId" = sz.id
LEFT JOIN sbx_uat_wms.storage_area sa ON sz."areaId" = sa.id
LEFT JOIN sbx_uat_wms.storage_position ss ON ss."storageId" = sb.id
LEFT JOIN sbx_uat_wms.storage_area_sloc sac ON sa."whId" = sac."whId" AND sa."code" = sac."areaCode"
LEFT JOIN sbx_uat_wms.storage_bin_dockdoor sbd ON sb.id = sbd."binId"
LEFT JOIN sbx_uat_wms.storage_dockdoor sd ON sbd."dockdoorId" = sd.id
LEFT JOIN sbx_uat_wms.storage_dockdoor_position sdp ON sd."id" = sdp."dockdoorId";
```