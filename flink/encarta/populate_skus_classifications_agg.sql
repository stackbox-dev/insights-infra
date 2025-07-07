-- Population script for SKU classifications table
INSERT INTO `sbx-uat.encarta.public.skus_classifications_agg`
SELECT sc.sku_id,
    COALESCE(
        CAST(
            JSON_OBJECTAGG(KEY sc.type VALUE sc.`value`) AS STRING
        ),
        '{}'
    ) AS sku_classifications,
    MIN(sc.created_at) AS created_at,
    MAX(sc.updated_at) AS updated_at
FROM `sbx-uat.encarta.public.classifications` sc
GROUP BY sc.sku_id;