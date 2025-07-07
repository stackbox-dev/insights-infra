-- Population script for product classifications table
INSERT INTO `sbx-uat.encarta.public.products_classifications_agg`
SELECT pc.product_id,
    COALESCE(
        CAST(
            JSON_OBJECTAGG(KEY pc.type VALUE pc.`value`) AS STRING
        ),
        '{}'
    ) AS product_classifications,
    MIN(pc.created_at) AS created_at,
    MAX(pc.updated_at) AS updated_at
FROM `sbx-uat.encarta.public.product_classifications` pc
GROUP BY pc.product_id;