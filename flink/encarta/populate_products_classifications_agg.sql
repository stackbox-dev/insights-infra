-- Population script for product classifications table
INSERT INTO `sbx-uat.encarta.public.products_classifications_agg`
SELECT pc.product_id,
    CAST(JSON_OBJECTAGG(KEY pc.type VALUE pc.`value`) AS STRING) AS product_classifications
FROM `sbx-uat.encarta.public.product_classifications` pc
GROUP BY pc.product_id;
