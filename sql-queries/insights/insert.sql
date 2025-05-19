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
    sdp.y AS dockdoor_y_coordinate
FROM sbx_uat_wms.storage_bin AS sb
LEFT JOIN sbx_uat_wms.storage_bin_type sbt ON sb."binTypeId" = sbt.id
LEFT JOIN sbx_uat_wms.storage_zone sz ON sb."zoneId" = sz.id
LEFT JOIN sbx_uat_wms.storage_area sa ON sz."areaId" = sa.id
LEFT JOIN sbx_uat_wms.storage_position ss ON ss."storageId" = sb.id
LEFT JOIN sbx_uat_wms.storage_area_sloc sac ON sa."whId" = sac."whId" AND sa."code" = sac."areaCode"
LEFT JOIN sbx_uat_wms.storage_bin_dockdoor sbd ON sb.id = sbd."binId"
LEFT JOIN sbx_uat_wms.storage_dockdoor sd ON sbd."dockdoorId" = sd.id
LEFT JOIN sbx_uat_wms.storage_dockdoor_position sdp ON sd."id" = sdp."dockdoorId";



INSERT INTO sbx_uat_insights.sku_unit_summary
SELECT 
    suv.id,
    suv.code,
    SUM(suv.l1units) AS ibc,
    SUM(suv.l2units) AS casecount,
    SUM(suv.l3units) AS palletcount
FROM
    (SELECT 
        su.id,
        su.code,
        CASE WHEN su.hierarchy='L1' THEN units ELSE 0 END AS l1units,
        CASE WHEN su.hierarchy='L2' THEN units ELSE 0 END AS l2units,
        CASE WHEN su.hierarchy='L3' THEN units ELSE 0 END AS l3units
     FROM
        (SELECT 
            s.id,
            s.code,
            u.hierarchy,
            u.units 
         FROM sbx_uat_encarta.skus s
         Left JOIN sbx_uat_encarta.uoms u ON s.id=u.sku_id
        ) AS su
    ) suv
GROUP BY suv.id, suv.code;