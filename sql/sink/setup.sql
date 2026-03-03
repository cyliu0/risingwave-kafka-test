-- Sink Test: Create source table, MV, and sinks

-- 1. Source table
CREATE TABLE IF NOT EXISTS user_events (
    user_id BIGINT,
    event_type VARCHAR,
    page_url VARCHAR,
    session_id VARCHAR,
    event_timestamp TIMESTAMP,
    duration_ms BIGINT
);

-- 2. Materialized view
CREATE MATERIALIZED VIEW IF NOT EXISTS user_event_stats AS
SELECT 
    user_id,
    event_type,
    DATE_TRUNC('minute', event_timestamp) as window_start,
    COUNT(*) as event_count,
    AVG(duration_ms) as avg_duration_ms,
    MIN(event_timestamp) as first_event,
    MAX(event_timestamp) as last_event
FROM user_events
GROUP BY user_id, event_type, DATE_TRUNC('minute', event_timestamp);

-- 3. PLAIN JSON sink
CREATE SINK IF NOT EXISTS kafka_sink_plain_json
FROM user_event_stats
WITH (
    connector = 'kafka',
    properties.bootstrap.server = '${KAFKA_BROKER}',
    topic = 'risingwave-sink-plain-json',
    properties.message.timeout.ms = '30000',
    properties.security.protocol = 'SASL_SSL',
    properties.sasl.mechanism = 'PLAIN',
    properties.sasl.username = '${KAFKA_USERNAME}',
    properties.sasl.password = '${KAFKA_PASSWORD}',
    properties.enable.ssl.certificate.verification = 'false'
)
FORMAT PLAIN ENCODE JSON (force_append_only = 'true');

-- 4. UPSERT JSON sink
CREATE SINK IF NOT EXISTS kafka_sink_upsert_json
FROM user_event_stats
WITH (
    connector = 'kafka',
    properties.bootstrap.server = '${KAFKA_BROKER}',
    topic = 'risingwave-sink-upsert-json',
    primary_key = 'user_id,event_type,window_start',
    properties.security.protocol = 'SASL_SSL',
    properties.sasl.mechanism = 'PLAIN',
    properties.sasl.username = '${KAFKA_USERNAME}',
    properties.sasl.password = '${KAFKA_PASSWORD}',
    properties.enable.ssl.certificate.verification = 'false'
)
FORMAT UPSERT ENCODE JSON;

-- 5. Insert test data
INSERT INTO user_events VALUES
    (1, 'page_view', '/home', 'sess_001', '2024-01-15 10:00:00', 5000),
    (1, 'page_view', '/products', 'sess_001', '2024-01-15 10:00:15', 8000),
    (2, 'page_view', '/home', 'sess_002', '2024-01-15 10:00:05', 3000),
    (1, 'click', '/products', 'sess_001', '2024-01-15 10:00:20', 100),
    (2, 'page_view', '/about', 'sess_002', '2024-01-15 10:00:30', 2000),
    (3, 'page_view', '/home', 'sess_003', '2024-01-15 10:01:00', 4500),
    (1, 'page_view', '/contact', 'sess_001', '2024-01-15 10:01:10', 6000),
    (2, 'click', '/about', 'sess_002', '2024-01-15 10:01:20', 150);
