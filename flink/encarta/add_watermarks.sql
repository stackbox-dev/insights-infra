-- Add watermarks to all source tables for event-time processing
-- Run this file after creating all base tables to enable watermark-based temporal joins
-- Using ALTER TABLE MODIFY since Confluent tables already have system-provided watermarks

-- Add watermark to skus table
ALTER TABLE `sbx-uat.encarta.public.skus` 
MODIFY WATERMARK FOR updated_at AS updated_at - INTERVAL '5' SECONDS;

-- Add watermark to products table
ALTER TABLE `sbx-uat.encarta.public.products` 
MODIFY WATERMARK FOR updated_at AS updated_at - INTERVAL '5' SECONDS;

-- Add watermark to sub_categories table
ALTER TABLE `sbx-uat.encarta.public.sub_categories` 
MODIFY WATERMARK FOR updated_at AS updated_at - INTERVAL '5' SECONDS;

-- Add watermark to categories table
ALTER TABLE `sbx-uat.encarta.public.categories` 
MODIFY WATERMARK FOR updated_at AS updated_at - INTERVAL '5' SECONDS;

-- Add watermark to category_groups table
ALTER TABLE `sbx-uat.encarta.public.category_groups` 
MODIFY WATERMARK FOR updated_at AS updated_at - INTERVAL '5' SECONDS;

-- Add watermark to sub_brands table
ALTER TABLE `sbx-uat.encarta.public.sub_brands` 
MODIFY WATERMARK FOR updated_at AS updated_at - INTERVAL '5' SECONDS;

-- Add watermark to brands table
ALTER TABLE `sbx-uat.encarta.public.brands` 
MODIFY WATERMARK FOR updated_at AS updated_at - INTERVAL '5' SECONDS;

-- Add watermark to uoms table (used by populate_skus_uoms_agg.sql)
ALTER TABLE `sbx-uat.encarta.public.uoms` 
MODIFY WATERMARK FOR updated_at AS updated_at - INTERVAL '5' SECONDS;

-- Add watermark to classifications table (used by populate_skus_classifications_agg.sql)
ALTER TABLE `sbx-uat.encarta.public.classifications` 
MODIFY WATERMARK FOR updated_at AS updated_at - INTERVAL '5' SECONDS;

-- Add watermark to product_classifications table (used by populate_products_classifications_agg.sql)
ALTER TABLE `sbx-uat.encarta.public.product_classifications` 
MODIFY WATERMARK FOR updated_at AS updated_at - INTERVAL '5' SECONDS;
