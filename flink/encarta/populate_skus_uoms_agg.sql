-- Population script for UOM aggregations table
INSERT INTO `sbx-uat.encarta.public.skus_uoms_agg`
SELECT u.sku_id,
    MAX(
        CASE
            WHEN u.hierarchy = 'L0' THEN u.units
        END
    ) AS l0_units,
    MAX(
        CASE
            WHEN u.hierarchy = 'L1' THEN u.units
        END
    ) AS l1_units,
    MAX(
        CASE
            WHEN u.hierarchy = 'L2' THEN u.units
        END
    ) AS l2_units,
    MAX(
        CASE
            WHEN u.hierarchy = 'L3' THEN u.units
        END
    ) AS l3_units,
    MAX(
        CASE
            WHEN u.hierarchy = 'L0' THEN u.name
        END
    ) AS l0_name,
    MAX(
        CASE
            WHEN u.hierarchy = 'L0' THEN u.weight
        END
    ) AS l0_weight,
    MAX(
        CASE
            WHEN u.hierarchy = 'L0' THEN u.volume
        END
    ) AS l0_volume,
    MAX(
        CASE
            WHEN u.hierarchy = 'L0' THEN u.package_type
        END
    ) AS l0_package_type,
    MAX(
        CASE
            WHEN u.hierarchy = 'L0' THEN u.length
        END
    ) AS l0_length,
    MAX(
        CASE
            WHEN u.hierarchy = 'L0' THEN u.width
        END
    ) AS l0_width,
    MAX(
        CASE
            WHEN u.hierarchy = 'L0' THEN u.height
        END
    ) AS l0_height,
    MAX(
        CASE
            WHEN u.hierarchy = 'L0' THEN u.packing_efficiency
        END
    ) AS l0_packing_efficiency,
    MAX(
        CASE
            WHEN u.hierarchy = 'L0' THEN u.itf_code
        END
    ) AS l0_itf_code,
    MAX(
        CASE
            WHEN u.hierarchy = 'L0' THEN u.erp_weight
        END
    ) AS l0_erp_weight,
    MAX(
        CASE
            WHEN u.hierarchy = 'L0' THEN u.erp_volume
        END
    ) AS l0_erp_volume,
    MAX(
        CASE
            WHEN u.hierarchy = 'L0' THEN u.erp_length
        END
    ) AS l0_erp_length,
    MAX(
        CASE
            WHEN u.hierarchy = 'L0' THEN u.erp_width
        END
    ) AS l0_erp_width,
    MAX(
        CASE
            WHEN u.hierarchy = 'L0' THEN u.erp_height
        END
    ) AS l0_erp_height,
    MAX(
        CASE
            WHEN u.hierarchy = 'L0' THEN u.text_tag1
        END
    ) AS l0_text_tag1,
    MAX(
        CASE
            WHEN u.hierarchy = 'L0' THEN u.text_tag2
        END
    ) AS l0_text_tag2,
    MAX(
        CASE
            WHEN u.hierarchy = 'L0' THEN u.image
        END
    ) AS l0_image,
    MAX(
        CASE
            WHEN u.hierarchy = 'L0' THEN u.num_tag1
        END
    ) AS l0_num_tag1,
    MAX(
        CASE
            WHEN u.hierarchy = 'L1' THEN u.name
        END
    ) AS l1_name,
    MAX(
        CASE
            WHEN u.hierarchy = 'L1' THEN u.weight
        END
    ) AS l1_weight,
    MAX(
        CASE
            WHEN u.hierarchy = 'L1' THEN u.volume
        END
    ) AS l1_volume,
    MAX(
        CASE
            WHEN u.hierarchy = 'L1' THEN u.package_type
        END
    ) AS l1_package_type,
    MAX(
        CASE
            WHEN u.hierarchy = 'L1' THEN u.length
        END
    ) AS l1_length,
    MAX(
        CASE
            WHEN u.hierarchy = 'L1' THEN u.width
        END
    ) AS l1_width,
    MAX(
        CASE
            WHEN u.hierarchy = 'L1' THEN u.height
        END
    ) AS l1_height,
    MAX(
        CASE
            WHEN u.hierarchy = 'L1' THEN u.packing_efficiency
        END
    ) AS l1_packing_efficiency,
    MAX(
        CASE
            WHEN u.hierarchy = 'L1' THEN u.itf_code
        END
    ) AS l1_itf_code,
    MAX(
        CASE
            WHEN u.hierarchy = 'L1' THEN u.erp_weight
        END
    ) AS l1_erp_weight,
    MAX(
        CASE
            WHEN u.hierarchy = 'L1' THEN u.erp_volume
        END
    ) AS l1_erp_volume,
    MAX(
        CASE
            WHEN u.hierarchy = 'L1' THEN u.erp_length
        END
    ) AS l1_erp_length,
    MAX(
        CASE
            WHEN u.hierarchy = 'L1' THEN u.erp_width
        END
    ) AS l1_erp_width,
    MAX(
        CASE
            WHEN u.hierarchy = 'L1' THEN u.erp_height
        END
    ) AS l1_erp_height,
    MAX(
        CASE
            WHEN u.hierarchy = 'L1' THEN u.text_tag1
        END
    ) AS l1_text_tag1,
    MAX(
        CASE
            WHEN u.hierarchy = 'L1' THEN u.text_tag2
        END
    ) AS l1_text_tag2,
    MAX(
        CASE
            WHEN u.hierarchy = 'L1' THEN u.image
        END
    ) AS l1_image,
    MAX(
        CASE
            WHEN u.hierarchy = 'L1' THEN u.num_tag1
        END
    ) AS l1_num_tag1,
    MAX(
        CASE
            WHEN u.hierarchy = 'L2' THEN u.name
        END
    ) AS l2_name,
    MAX(
        CASE
            WHEN u.hierarchy = 'L2' THEN u.weight
        END
    ) AS l2_weight,
    MAX(
        CASE
            WHEN u.hierarchy = 'L2' THEN u.volume
        END
    ) AS l2_volume,
    MAX(
        CASE
            WHEN u.hierarchy = 'L2' THEN u.package_type
        END
    ) AS l2_package_type,
    MAX(
        CASE
            WHEN u.hierarchy = 'L2' THEN u.length
        END
    ) AS l2_length,
    MAX(
        CASE
            WHEN u.hierarchy = 'L2' THEN u.width
        END
    ) AS l2_width,
    MAX(
        CASE
            WHEN u.hierarchy = 'L2' THEN u.height
        END
    ) AS l2_height,
    MAX(
        CASE
            WHEN u.hierarchy = 'L2' THEN u.packing_efficiency
        END
    ) AS l2_packing_efficiency,
    MAX(
        CASE
            WHEN u.hierarchy = 'L2' THEN u.itf_code
        END
    ) AS l2_itf_code,
    MAX(
        CASE
            WHEN u.hierarchy = 'L2' THEN u.erp_weight
        END
    ) AS l2_erp_weight,
    MAX(
        CASE
            WHEN u.hierarchy = 'L2' THEN u.erp_volume
        END
    ) AS l2_erp_volume,
    MAX(
        CASE
            WHEN u.hierarchy = 'L2' THEN u.erp_length
        END
    ) AS l2_erp_length,
    MAX(
        CASE
            WHEN u.hierarchy = 'L2' THEN u.erp_width
        END
    ) AS l2_erp_width,
    MAX(
        CASE
            WHEN u.hierarchy = 'L2' THEN u.erp_height
        END
    ) AS l2_erp_height,
    MAX(
        CASE
            WHEN u.hierarchy = 'L2' THEN u.text_tag1
        END
    ) AS l2_text_tag1,
    MAX(
        CASE
            WHEN u.hierarchy = 'L2' THEN u.text_tag2
        END
    ) AS l2_text_tag2,
    MAX(
        CASE
            WHEN u.hierarchy = 'L2' THEN u.image
        END
    ) AS l2_image,
    MAX(
        CASE
            WHEN u.hierarchy = 'L2' THEN u.num_tag1
        END
    ) AS l2_num_tag1,
    MAX(
        CASE
            WHEN u.hierarchy = 'L3' THEN u.name
        END
    ) AS l3_name,
    MAX(
        CASE
            WHEN u.hierarchy = 'L3' THEN u.weight
        END
    ) AS l3_weight,
    MAX(
        CASE
            WHEN u.hierarchy = 'L3' THEN u.volume
        END
    ) AS l3_volume,
    MAX(
        CASE
            WHEN u.hierarchy = 'L3' THEN u.package_type
        END
    ) AS l3_package_type,
    MAX(
        CASE
            WHEN u.hierarchy = 'L3' THEN u.length
        END
    ) AS l3_length,
    MAX(
        CASE
            WHEN u.hierarchy = 'L3' THEN u.width
        END
    ) AS l3_width,
    MAX(
        CASE
            WHEN u.hierarchy = 'L3' THEN u.height
        END
    ) AS l3_height,
    MAX(
        CASE
            WHEN u.hierarchy = 'L3' THEN u.packing_efficiency
        END
    ) AS l3_packing_efficiency,
    MAX(
        CASE
            WHEN u.hierarchy = 'L3' THEN u.itf_code
        END
    ) AS l3_itf_code,
    MAX(
        CASE
            WHEN u.hierarchy = 'L3' THEN u.erp_weight
        END
    ) AS l3_erp_weight,
    MAX(
        CASE
            WHEN u.hierarchy = 'L3' THEN u.erp_volume
        END
    ) AS l3_erp_volume,
    MAX(
        CASE
            WHEN u.hierarchy = 'L3' THEN u.erp_length
        END
    ) AS l3_erp_length,
    MAX(
        CASE
            WHEN u.hierarchy = 'L3' THEN u.erp_width
        END
    ) AS l3_erp_width,
    MAX(
        CASE
            WHEN u.hierarchy = 'L3' THEN u.erp_height
        END
    ) AS l3_erp_height,
    MAX(
        CASE
            WHEN u.hierarchy = 'L3' THEN u.text_tag1
        END
    ) AS l3_text_tag1,
    MAX(
        CASE
            WHEN u.hierarchy = 'L3' THEN u.text_tag2
        END
    ) AS l3_text_tag2,
    MAX(
        CASE
            WHEN u.hierarchy = 'L3' THEN u.image
        END
    ) AS l3_image,
    MAX(
        CASE
            WHEN u.hierarchy = 'L3' THEN u.num_tag1
        END
    ) AS l3_num_tag1,
    MAX(u.updated_at) AS updated_at
FROM `sbx-uat.encarta.public.uoms` u
WHERE u.active = true
GROUP BY u.sku_id;