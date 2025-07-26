-- Create Hive catalog with GCS backend
CREATE CATALOG hive_catalog WITH (
    'type' = 'hive',
    'default-database' = 'default',
    'hive-conf-dir' = '/opt/hive-conf'
);
