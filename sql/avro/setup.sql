-- Avro Test: Create Avro-compatible MV, sink and source with Schema Registry

-- 1. Create Avro-compatible materialized view (casts timestamps to BIGINT)
CREATE MATERIALIZED VIEW IF NOT EXISTS user_event_stats_avro AS
SELECT 
    user_id,
    event_type,
    CAST(EXTRACT(EPOCH FROM window_start) * 1000000 AS BIGINT) as window_start_us,
    event_count,
    avg_duration_ms,
    CAST(EXTRACT(EPOCH FROM first_event) * 1000000 AS BIGINT) as first_event_us,
    CAST(EXTRACT(EPOCH FROM last_event) * 1000000 AS BIGINT) as last_event_us
FROM user_event_stats;

-- 2. Avro sink from Avro-compatible MV
CREATE SINK IF NOT EXISTS kafka_sink_avro
FROM user_event_stats_avro
WITH (
    connector = 'kafka',
    properties.bootstrap.server = '${KAFKA_BROKER}',
    topic = 'risingwave-sink-avro',
    primary_key = 'user_id,event_type,window_start_us',
    properties.message.timeout.ms = '30000',
    properties.security.protocol = 'SASL_SSL',
    properties.sasl.mechanism = 'PLAIN',
    properties.sasl.username = '${KAFKA_USERNAME}',
    properties.sasl.password = '${KAFKA_PASSWORD}',
    properties.enable.ssl.certificate.verification = 'false'
)
FORMAT UPSERT ENCODE AVRO (
    schema.registry = '${SCHEMA_REGISTRY_URL}',
    schema.registry.username = '${KAFKA_USERNAME}',
    schema.registry.password = '${KAFKA_PASSWORD}'
);

-- 3. Avro source (reads back the Avro data)
CREATE SOURCE IF NOT EXISTS kafka_source_avro
WITH (
    connector = 'kafka',
    topic = 'risingwave-sink-avro',
    properties.bootstrap.server = '${KAFKA_BROKER}',
    scan.startup.mode = 'earliest',
    properties.security.protocol = 'SASL_SSL',
    properties.sasl.mechanism = 'PLAIN',
    properties.sasl.username = '${KAFKA_USERNAME}',
    properties.sasl.password = '${KAFKA_PASSWORD}',
    properties.enable.ssl.certificate.verification = 'false'
)
FORMAT PLAIN ENCODE AVRO (
    schema.registry = '${SCHEMA_REGISTRY_URL}',
    schema.registry.username = '${KAFKA_USERNAME}',
    schema.registry.password = '${KAFKA_PASSWORD}'
);
