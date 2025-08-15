#!/bin/bash

# Build Snapshots Script for WMS Inventory
# Usage: ./build-snapshots.sh --interval-days <days> --lookback-days <days> --env <env-file> [--dry-run]

set -euo pipefail

# Default values
INTERVAL_DAYS=180
LOOKBACK_DAYS=0
DRY_RUN=false
ENV_FILE=""
BATCH_SIZE=100

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --interval-days)
            INTERVAL_DAYS="$2"
            shift 2
            ;;
        --lookback-days)
            LOOKBACK_DAYS="$2"
            shift 2
            ;;
        --env)
            ENV_FILE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --batch-size)
            BATCH_SIZE="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 --interval-days <days> --lookback-days <days> --env <env-file> [--dry-run] [--batch-size <num>]"
            echo ""
            echo "Options:"
            echo "  --interval-days   Interval between snapshots in days (default: 1)"
            echo "                    Examples: 0.25 (6 hours), 1 (daily), 7 (weekly), 30 (monthly)"
            echo "  --lookback-days   How far back to look for missing snapshots (default: 0 = from beginning)"
            echo "  --env             Environment file with ClickHouse credentials"
            echo "  --dry-run         Show what would be created without actually creating snapshots"
            echo "  --batch-size      Number of snapshots to create per batch (default: 100)"
            echo ""
            echo "Examples:"
            echo "  # Dry run for weekly snapshots from beginning"
            echo "  $0 --interval-days 7 --lookback-days 0 --env .env --dry-run"
            echo ""
            echo "  # Build daily snapshots for last 30 days"
            echo "  $0 --interval-days 1 --lookback-days 30 --env .env"
            echo ""
            echo "  # Build monthly snapshots from beginning"
            echo "  $0 --interval-days 30 --lookback-days 0 --env .env"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Check required parameters
if [ -z "$ENV_FILE" ]; then
    echo "Error: --env parameter is required"
    echo "Use --help for usage information"
    exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: Environment file '$ENV_FILE' not found"
    exit 1
fi

# Source environment file
source "$ENV_FILE"

# Check required environment variables
if [ -z "$CLICKHOUSE_HOST" ]; then
    echo "Error: CLICKHOUSE_HOST not set in environment file"
    exit 1
fi

if [ -z "$CLICKHOUSE_PASSWORD" ]; then
    echo "Error: CLICKHOUSE_PASSWORD not set in environment file"
    echo "The deploy script should have fetched and included the password"
    exit 1
fi

# Set ClickHouse connection parameters
CH_PARAMS="--host=$CLICKHOUSE_HOST"
[ -n "$CLICKHOUSE_PORT" ] && CH_PARAMS="$CH_PARAMS --port=$CLICKHOUSE_PORT"
[ -n "$CLICKHOUSE_USER" ] && CH_PARAMS="$CH_PARAMS --user=$CLICKHOUSE_USER"
[ -n "$CLICKHOUSE_PASSWORD" ] && CH_PARAMS="$CH_PARAMS --password=$CLICKHOUSE_PASSWORD"
[ -n "$CLICKHOUSE_DATABASE" ] && CH_PARAMS="$CH_PARAMS --database=$CLICKHOUSE_DATABASE"

# Aiven ClickHouse always requires SSL/TLS
CH_PARAMS="$CH_PARAMS --secure"

echo "=========================================="
echo "Snapshot Build Configuration"
echo "=========================================="
echo "Interval:        $INTERVAL_DAYS days"
echo "Lookback:        $LOOKBACK_DAYS days (0 = from beginning)"
echo "Batch Size:      $BATCH_SIZE snapshots per batch"
echo "Mode:            $([ "$DRY_RUN" = true ] && echo "DRY RUN" || echo "EXECUTE")"
echo "ClickHouse Host: $CLICKHOUSE_HOST"
echo "Database:        ${CLICKHOUSE_DATABASE:-default}"
echo "=========================================="
echo ""

if [ "$DRY_RUN" = true ]; then
    echo "Performing dry run - checking what snapshots would be created..."
    echo ""
    
    # Create dry-run query
    cat > /tmp/snapshot_dryrun.sql << 'EOF'
WITH 
interval_hours AS (
    SELECT {interval_days:Int32} * 24 as hours
),
data_range AS (
    SELECT 
        COALESCE(toStartOfHour(min(hu_event_timestamp)), toStartOfHour(now() - INTERVAL 30 DAY)) as min_time,
        COALESCE(toStartOfHour(max(hu_event_timestamp)), toStartOfHour(now())) as max_time,
        count() as total_events
    FROM wms_inventory_events_enriched
),
start_time AS (
    SELECT 
        CASE 
            WHEN {lookback_days:Int32} > 0 
            THEN toStartOfHour(now() - INTERVAL {lookback_days:Int32} DAY)
            ELSE (SELECT min_time FROM data_range)
        END as value
),
expected_snapshots AS (
    SELECT toStartOfHour(
        (SELECT value FROM start_time) + INTERVAL (number * (SELECT hours FROM interval_hours)) HOUR
    ) as snapshot_time
    FROM numbers(
        CAST(
            CASE 
                WHEN (SELECT max_time FROM data_range) IS NULL OR (SELECT value FROM start_time) IS NULL
                THEN 1
                ELSE GREATEST(
                    1,
                    ceil(
                        (toUnixTimestamp((SELECT max_time FROM data_range)) - toUnixTimestamp((SELECT value FROM start_time))) 
                        / 3600.0 
                        / (SELECT hours FROM interval_hours)
                    )
                )
            END AS UInt64
        )
    )
    WHERE snapshot_time <= toStartOfHour(now())
      AND snapshot_time >= (SELECT value FROM start_time)
),
existing_snapshots AS (
    SELECT DISTINCT snapshot_timestamp
    FROM wms_inventory_snapshot
    WHERE snapshot_timestamp >= (SELECT value FROM start_time)
),
missing_snapshots AS (
    SELECT es.snapshot_time
    FROM expected_snapshots es
    WHERE es.snapshot_time NOT IN (
        SELECT snapshot_timestamp 
        FROM wms_inventory_snapshot 
        WHERE snapshot_timestamp >= (SELECT value FROM start_time)
          AND snapshot_timestamp IS NOT NULL
    )
    ORDER BY es.snapshot_time
)
SELECT 
    '=== DRY RUN RESULTS ===' as info
UNION ALL
SELECT 
    'Data Range: ' || formatDateTime((SELECT min_time FROM data_range), '%Y-%m-%d %H:%M') || 
    ' to ' || formatDateTime((SELECT max_time FROM data_range), '%Y-%m-%d %H:%M')
UNION ALL
SELECT 
    'Total Events in Source: ' || toString((SELECT total_events FROM data_range))
UNION ALL
SELECT 
    'Expected Snapshots: ' || toString(count()) || ' (from ' || 
    formatDateTime(min(snapshot_time), '%Y-%m-%d %H:%M') || ' to ' || 
    formatDateTime(max(snapshot_time), '%Y-%m-%d %H:%M') || ')'
FROM expected_snapshots
UNION ALL
SELECT 
    'Existing Snapshots: ' || toString(count())
FROM existing_snapshots
UNION ALL
SELECT 
    'Missing Snapshots: ' || toString(count()) || 
    CASE WHEN count() > 0 
    THEN ' (from ' || formatDateTime(min(snapshot_time), '%Y-%m-%d %H:%M') || 
         ' to ' || formatDateTime(max(snapshot_time), '%Y-%m-%d %H:%M') || ')'
    ELSE ''
    END
FROM missing_snapshots
UNION ALL
SELECT 
    'Snapshots per Batch: ' || toString({batch_size:Int32})
UNION ALL
SELECT 
    'Total Batches Required: ' || toString(
        CASE 
            WHEN (SELECT count() FROM missing_snapshots) > 0 
            THEN ceiling((SELECT count() FROM missing_snapshots) / {batch_size:Int32})
            ELSE 0
        END
    );
EOF

    # Run dry-run query with explicit parameter types
    clickhouse-client $CH_PARAMS \
        --queries-file /tmp/snapshot_dryrun.sql \
        --param_interval_days="$INTERVAL_DAYS" \
        --param_lookback_days="$LOOKBACK_DAYS" \
        --param_batch_size="$BATCH_SIZE"
    
    rm /tmp/snapshot_dryrun.sql
    
else
    echo "Building snapshots..."
    echo ""
    
    # Get script directory
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    # SQL file is in the same directory as this script when deployed
    SQL_FILE="$SCRIPT_DIR/XX-snapshot-build-configurable.sql"
    
    if [ ! -f "$SQL_FILE" ]; then
        echo "Error: SQL file not found: $SQL_FILE"
        exit 1
    fi
    
    # First check if we have any data
    HAS_DATA=$(clickhouse-client $CH_PARAMS --query "SELECT count() > 0 FROM wms_inventory_events_enriched")
    
    if [ "$HAS_DATA" = "0" ]; then
        echo "No data in wms_inventory_events_enriched table yet."
        echo "Cannot create snapshots without source data."
        echo ""
        echo "==========================================" 
        echo "Snapshot build complete (no data to process)!"
        echo "=========================================="
        exit 0
    fi
    
    # Get data range and calculate snapshot dates
    echo "Calculating snapshot dates needed..."
    DATA_RANGE=$(clickhouse-client $CH_PARAMS --query "
    SELECT 
        formatDateTime(toStartOfDay(min(hu_event_timestamp)), '%Y-%m-%d') as min_date,
        formatDateTime(toStartOfDay(now()), '%Y-%m-%d') as max_date
    FROM wms_inventory_events_enriched
    FORMAT TSVRaw")
    
    MIN_DATE=$(echo "$DATA_RANGE" | cut -f1)
    MAX_DATE=$(echo "$DATA_RANGE" | cut -f2)
    
    # Determine start date based on lookback parameter
    if [ "$LOOKBACK_DAYS" -gt 0 ]; then
        START_DATE=$(date -d "today - $LOOKBACK_DAYS days" +%Y-%m-%d)
    else
        START_DATE="$MIN_DATE"
    fi
    
    echo "Data range: $MIN_DATE to $MAX_DATE"
    echo "Building snapshots from: $START_DATE"
    echo "Interval: every $INTERVAL_DAYS day(s)"
    echo ""
    
    # Generate list of snapshot dates
    CURRENT_DATE="$START_DATE"
    SNAPSHOT_COUNT=0
    
    while [ "$(date -d "$CURRENT_DATE" +%s)" -le "$(date -d "$MAX_DATE" +%s)" ]; do
        SNAPSHOT_TIMESTAMP="${CURRENT_DATE} 00:00:00"
        
        # Check if snapshot already exists
        EXISTS=$(clickhouse-client $CH_PARAMS --query "
        SELECT count(*) > 0 
        FROM wms_inventory_snapshot 
        WHERE snapshot_timestamp = '$SNAPSHOT_TIMESTAMP'")
        
        if [ "$EXISTS" = "1" ]; then
            echo "Snapshot for $SNAPSHOT_TIMESTAMP already exists, skipping..."
        else
            echo "Creating snapshot for $SNAPSHOT_TIMESTAMP..."
            
            # Run the SQL script for this specific timestamp
            clickhouse-client $CH_PARAMS \
                --queries-file "$SQL_FILE" \
                --param_snapshot_timestamp="$SNAPSHOT_TIMESTAMP" \
                --progress \
                --time
            
            # Verify creation
            CREATED_ROWS=$(clickhouse-client $CH_PARAMS --query "
            SELECT count(*) 
            FROM wms_inventory_snapshot 
            WHERE snapshot_timestamp = '$SNAPSHOT_TIMESTAMP'")
            
            echo "Created $CREATED_ROWS rows for snapshot $SNAPSHOT_TIMESTAMP"
            SNAPSHOT_COUNT=$((SNAPSHOT_COUNT + 1))
        fi
        
        # Move to next date based on interval using ClickHouse date functions
        NEXT_DATE=$(clickhouse-client $CH_PARAMS --query "
        SELECT formatDateTime(
            addDays(parseDateTimeBestEffort('$CURRENT_DATE'), $INTERVAL_DAYS), 
            '%Y-%m-%d'
        )")
        CURRENT_DATE="$NEXT_DATE"
    done
    
    echo ""
    echo "Created $SNAPSHOT_COUNT new snapshots"
    
    echo ""
    echo "=========================================="
    echo "Snapshot build complete!"
    echo "=========================================="
    
    # Show final statistics
    clickhouse-client $CH_PARAMS --query "
    SELECT 
        'Total Snapshots: ' || toString(count(DISTINCT snapshot_timestamp)) || 
        CASE 
            WHEN count(DISTINCT snapshot_timestamp) > 0 
            THEN ', Date Range: ' || formatDateTime(min(snapshot_timestamp), '%Y-%m-%d') || 
                 ' to ' || formatDateTime(max(snapshot_timestamp), '%Y-%m-%d')
            ELSE ' (no snapshots exist yet)'
        END as summary
    FROM wms_inventory_snapshot"
fi