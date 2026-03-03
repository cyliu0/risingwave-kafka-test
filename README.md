# RisingWave Kafka Integration Test Suite

A comprehensive test suite for RisingWave's Kafka source and sink features, including JSON and Avro formats with Schema Registry support.

## Overview

This test suite validates:
- **Kafka Source**: Stream data from Kafka into RisingWave
- **Kafka Sink**: Write data from RisingWave to Kafka
- **Formats**: JSON, Avro, Upsert
- **Security**: SASL/SSL authentication
- **Schema Registry**: Avro schema management

## Architecture

```
┌─────────────────┐         ┌──────────────────┐         ┌─────────────────┐
│   Kafka Topic   │────────▶│  RisingWave      │────────▶│   Kafka Topic   │
│  (Source Data)  │         │  - Source/Table  │         │  (Sink Results) │
└─────────────────┘         │  - Materialized  │         └─────────────────┘
                            │    Views         │
                            │  - Sink          │
                            └──────────────────┘
                                     │
                                     ▼
                            ┌──────────────────┐
                            │  Query Results   │
                            └──────────────────┘
```

## Quick Start

### 1. Configure Environment

Edit `scripts/env.sh` or set environment variables:

```bash
export RW_HOST="your-risingwave-host"
export RW_PORT="4566"
export RW_DB="dev"
export RW_USER="your-username"
export RW_PASSWORD="your-password"

export KAFKA_BROKER="your-kafka-broker:9093"
export KAFKA_USERNAME="your-kafka-username"
export KAFKA_PASSWORD="your-kafka-password"

# For Avro tests
export SCHEMA_REGISTRY_URL="https://your-schema-registry"
```

### 2. Run Tests

```bash
# Test 1: JSON Sink (RisingWave → Kafka)
./scripts/run_test.sh sink

# Test 2: JSON Source (Kafka → RisingWave)
./scripts/run_test.sh source

# Test 3: Avro Sink with Schema Registry
./scripts/run_test.sh avro

# Test 4: End-to-End (Kafka → RisingWave → Kafka)
./scripts/run_test.sh e2e

# Test 5: Verify all data
./scripts/run_test.sh verify

# Test 6: Run all tests
./scripts/run_test.sh all
```

### 3. Cleanup

```bash
# Clean up RisingWave resources
./scripts/run_test.sh cleanup
```

**Note:** Cleanup removes RisingWave resources (tables, sources, sinks, MVs). Kafka topics are not affected.

## Project Structure

```
.
├── README.md              # This file
├── scripts/
│   ├── env.sh            # Environment configuration
│   ├── lib.sh            # Common functions
│   └── run_test.sh       # Unified test runner
└── sql/
    ├── sink/setup.sql    # Sink test SQL
    ├── source/setup.sql  # Source test SQL
    ├── avro/setup.sql    # Avro test SQL
    └── cleanup/all.sql   # Cleanup SQL
```

### File Details

| File | Purpose |
|------|---------|
| `scripts/env.sh` | Configuration for RW, Kafka, Schema Registry |
| `scripts/lib.sh` | Shared functions (logging, SQL execution, verification) |
| `scripts/run_test.sh` | Main test runner (sink/source/avro/e2e/cleanup) |
| `sql/sink/setup.sql` | Creates tables, MVs, and JSON sinks |
| `sql/source/setup.sql` | Creates Kafka source, table, and MV |
| `sql/avro/setup.sql` | Creates Avro sink and source |
| `sql/cleanup/all.sql` | Drops all test resources |

## Test Scenarios

### 1. JSON Sink Test

Tests writing data from RisingWave materialized views to Kafka in JSON format.

**Features tested:**
- PLAIN (append-only) format
- UPSERT (key-based deduplication) format
- SASL_SSL security

### 2. JSON Source Test

Tests reading data from Kafka into RisingWave.

**Features tested:**
- `CREATE SOURCE` (streaming, non-persisted)
- `CREATE TABLE` (persisted with primary key)
- Metadata inclusion (offset, timestamp, partition, key)
- Real-time materialized views on streaming data

### 3. Avro Test

Tests Avro format with Confluent Schema Registry.

**Features tested:**
- Avro schema registration
- Schema evolution
- Binary data serialization
- Source and sink with Schema Registry

### 4. End-to-End Test

Tests the complete pipeline:
```
Kafka Source → RisingWave MV → Kafka Sink
```

## Configuration Reference

### RisingWave Connection

| Variable | Description | Default |
|----------|-------------|---------|
| `RW_HOST` | RisingWave host | `localhost` |
| `RW_PORT` | RisingWave port | `4566` |
| `RW_DB` | Database name | `dev` |
| `RW_USER` | Username | `root` |
| `RW_PASSWORD` | Password | (empty) |

### Kafka Connection

| Variable | Description | Example |
|----------|-------------|---------|
| `KAFKA_BROKER` | Bootstrap servers | `host:9093` |
| `KAFKA_USERNAME` | SASL username | `user@tenant` |
| `KAFKA_PASSWORD` | SASL password | `token` |

### Schema Registry (Avro)

| Variable | Description | Example |
|----------|-------------|---------|
| `SCHEMA_REGISTRY_URL` | Registry URL | `https://sr.example.com` |

## Security

All connections use SASL_SSL with PLAIN authentication:
- Kafka: `SASL_SSL` + `SASL/PLAIN`
- Schema Registry: Basic Auth (username/password)
- Certificate verification disabled for testing (set `enable.ssl.certificate.verification=false`)

## Troubleshooting

### Connection Issues

```bash
# Test RisingWave connection
psql postgresql://user:pass@host:4566/dev -c "SELECT 1;"

# Test Kafka connection
kcat -L -b kafka-broker:9093 -X security.protocol=SASL_SSL \
  -X sasl.mechanism=PLAIN -X sasl.username=user -X sasl.password=pass

# Test Schema Registry
curl -u user:pass https://schema-registry/subjects
```

### Data Not Flowing

1. Check source/sink status: `SHOW SOURCES;` / `SHOW SINKS;`
2. Verify topic exists: `kcat -L -b broker`
3. Check message format (JSON must be valid)
4. Review RisingWave logs for errors

### Schema Registry Errors

- Verify credentials work with `curl`
- Check Schema Registry is accessible from RisingWave
- Ensure topic name matches schema subject pattern

## Requirements

- `psql` (PostgreSQL client)
- `kcat` (Kafka client)
- `curl` (for Schema Registry tests)
- Bash 4.0+

## Extending Tests

### Add a New Test

1. Create SQL file in `sql/<category>/`
2. Add test function in `scripts/lib.sh` if needed
3. Add command handler in `scripts/run_test.sh`

Example:
```bash
# In run_test.sh
test_custom() {
    exec_sql "$SQL_DIR/custom/setup.sql" "Custom test"
    # Add verification logic
}

# In main() case statement
custom) test_custom ;;
```

### Environment Variables

All sensitive configs are externalized to `env.sh`:
- No hardcoded credentials in test scripts
- Easy to override per environment
- Support for CI/CD secret injection

## Resources

- [RisingWave Kafka Source Docs](https://docs.risingwave.com/ingestion/sources/kafka)
- [RisingWave Kafka Sink Docs](https://docs.risingwave.com/integrations/destinations/apache-kafka)
- [StreamNative Documentation](https://docs.streamnative.io/)
