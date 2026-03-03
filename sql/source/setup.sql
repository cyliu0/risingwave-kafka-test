-- Source Test: Create Kafka source, table, and MV

-- 1. Kafka source (non-persisted)
CREATE SOURCE IF NOT EXISTS kafka_source_user_events (
    user_id BIGINT,
    event_type VARCHAR,
    page_url VARCHAR,
    session_id VARCHAR,
    event_timestamp TIMESTAMP,
    duration_ms BIGINT
)
INCLUDE key AS kafka_key
INCLUDE partition AS kafka_partition
INCLUDE offset AS kafka_offset
INCLUDE timestamp AS kafka_timestamp
WITH (
    connector = 'kafka',
    topic = 'risingwave-test-source-topic',
    properties.bootstrap.server = '${KAFKA_BROKER}',
    scan.startup.mode = 'latest',
    properties.security.protocol = 'SASL_SSL',
    properties.sasl.mechanism = 'PLAIN',
    properties.sasl.username = '${KAFKA_USERNAME}',
    properties.sasl.password = '${KAFKA_PASSWORD}',
    properties.enable.ssl.certificate.verification = 'false'
) FORMAT PLAIN ENCODE JSON;

-- 2. Kafka table (persisted)
CREATE TABLE IF NOT EXISTS kafka_table_user_events (
    user_id BIGINT,
    event_type VARCHAR,
    page_url VARCHAR,
    session_id VARCHAR,
    event_timestamp TIMESTAMP,
    duration_ms BIGINT
)
INCLUDE key AS kafka_key
INCLUDE partition AS kafka_partition
INCLUDE offset AS kafka_offset
INCLUDE timestamp AS kafka_timestamp
WITH (
    connector = 'kafka',
    topic = 'risingwave-test-source-topic',
    properties.bootstrap.server = '${KAFKA_BROKER}',
    scan.startup.mode = 'latest',
    properties.security.protocol = 'SASL_SSL',
    properties.sasl.mechanism = 'PLAIN',
    properties.sasl.username = '${KAFKA_USERNAME}',
    properties.sasl.password = '${KAFKA_PASSWORD}',
    properties.enable.ssl.certificate.verification = 'false'
) FORMAT PLAIN ENCODE JSON;

-- 3. Materialized view from source
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_kafka_source_stats AS
SELECT 
    user_id,
    event_type,
    DATE_TRUNC('minute', event_timestamp) as window_start,
    COUNT(*) as event_count,
    AVG(duration_ms) as avg_duration_ms,
    MIN(event_timestamp) as first_event,
    MAX(event_timestamp) as last_event,
    MAX(kafka_offset) as latest_offset,
    MAX(kafka_timestamp) as kafka_message_time
FROM kafka_source_user_events
WHERE user_id IS NOT NULL
GROUP BY user_id, event_type, DATE_TRUNC('minute', event_timestamp);
