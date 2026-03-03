#!/bin/bash
# Environment configuration for RisingWave and Kafka

# Load environment variables from .env file if it exists
if [ -f "$(dirname "${BASH_SOURCE[0]}")/../.env" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/../.env"
fi

# RisingWave connection settings
export RW_HOST="${RW_HOST:-}"
export RW_PORT="${RW_PORT:-4566}"
export RW_DB="${RW_DB:-dev}"
export RW_USER="${RW_USER:-}"
export RW_PASSWORD="${RW_PASSWORD:-}"

# Kafka connection settings
export KAFKA_BROKER="${KAFKA_BROKER:-}"

# Kafka SASL Authentication
export KAFKA_USERNAME="${KAFKA_USERNAME:-}"
export KAFKA_PASSWORD="${KAFKA_PASSWORD:-}"

# Schema Registry settings (for Avro format)
export SCHEMA_REGISTRY_URL="${SCHEMA_REGISTRY_URL:-}"

# Build connection strings
if [ -n "$RW_PASSWORD" ]; then
    export RW_PSQL_URL="postgresql://${RW_USER}:${RW_PASSWORD}@${RW_HOST}:${RW_PORT}/${RW_DB}"
else
    export RW_PSQL_URL="postgresql://${RW_USER}@${RW_HOST}:${RW_PORT}/${RW_DB}"
fi

# Colors for output
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export NC='\033[0m'

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required commands are available
check_prerequisites() {
    local missing=()
    
    if ! command -v psql &> /dev/null; then
        missing+=("psql")
    fi
    
    if ! command -v kcat &> /dev/null && ! command -v kafka-console-consumer &> /dev/null; then
        missing+=("kcat or kafka-console-consumer")
    fi
    
    if [ ${#missing[@]} -ne 0 ]; then
        echo_error "Missing required tools: ${missing[*]}"
        echo "Please install:"
        echo "  - psql (PostgreSQL client)"
        echo "  - kcat (Kafka consumer)"
        exit 1
    fi
    
    echo_info "Prerequisites check passed"
}
