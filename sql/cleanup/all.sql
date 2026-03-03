-- Cleanup all test resources
-- Order matters: drop dependent objects first

-- Sinks (no dependencies)
DROP SINK IF EXISTS kafka_sink_plain_json;
DROP SINK IF EXISTS kafka_sink_upsert_json;
DROP SINK IF EXISTS kafka_sink_avro;
DROP SINK IF EXISTS kafka_sink_from_source;

-- Materialized views (depend on sources/tables)
DROP MATERIALIZED VIEW IF EXISTS mv_kafka_source_stats;
DROP MATERIALIZED VIEW IF EXISTS user_event_stats;

-- Sources (may have MV dependencies, dropped above)
DROP SOURCE IF EXISTS kafka_source_user_events;
DROP SOURCE IF EXISTS kafka_source_avro;

-- Tables
DROP TABLE IF EXISTS kafka_table_user_events;
DROP TABLE IF EXISTS user_events;
