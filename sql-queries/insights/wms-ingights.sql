CREATE TABLE sbx_uat_insights.storage_bin_summary
ENGINE = MergeTree()
ORDER BY ("whId", "bin_code")
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
    sa.description,
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
    sd.code,
    sbd.usage,
    sbd."multiTrip",
    sd.description,
    sd."maxQueue",
    sd."allowInbound",
    sd."allowOutbound",
    sd."allowReturns",
    sd."incompatibleVehicleTypes",
    sd."incompatibleLoadTypes",
    sdp.x AS dockdoor_x_coordinate,
    sdp.y AS dockdoor_y_coordinate
FROM sbx_uat_wms.storage_bin AS sb
JOIN sbx_uat_wms.storage_bin_type sbt ON sb."binTypeId" = sbt.id
JOIN sbx_uat_wms.storage_zone sz ON sb."zoneId" = sz.id
JOIN sbx_uat_wms.storage_area sa ON sz."areaId" = sa.id
FULL OUTER JOIN sbx_uat_wms.storage_position ss ON ss."storageId" = sb.id
JOIN sbx_uat_wms.storage_area_sloc sac ON sa."whId" = sac."whId" AND sa."code" = sac."areaCode"
FULL OUTER JOIN sbx_uat_wms.storage_bin_dockdoor sbd ON sb.id = sbd."binId"
JOIN sbx_uat_wms.storage_dockdoor sd ON sbd."dockdoorId" = sd.id
FULL OUTER JOIN sbx_uat_wms.storage_dockdoor_position sdp ON sd."id" = sdp."dockdoorId"
WHERE sb.status = 'ACTIVE' AND sbt.active = true;