#!/bin/bash

# Cassandra Sidecar Docker Entrypoint Script
# Configures and starts the Cassandra Sidecar

set -e

# Configurar variables de entorno por defecto
SIDECAR_PORT=${SIDECAR_PORT:-9043}
CASSANDRA_HOST=${CASSANDRA_HOST:-cassandra-1}
CASSANDRA_PORT=${CASSANDRA_PORT:-9042}
CASSANDRA_JMX_PORT=${CASSANDRA_JMX_PORT:-7199}
SIDECAR_HEALTH_CHECK_FREQUENCY=${SIDECAR_HEALTH_CHECK_FREQUENCY:-30s}
SIDECAR_LOG_LEVEL=${SIDECAR_LOG_LEVEL:-INFO}

echo "🚀 Starting Cassandra Sidecar..."
echo "   Port: $SIDECAR_PORT"
echo "   Target Cassandra: $CASSANDRA_HOST:$CASSANDRA_PORT"
echo "   JMX Port: $CASSANDRA_JMX_PORT"
echo "   Health Check: $SIDECAR_HEALTH_CHECK_FREQUENCY"
echo "   Log Level: $SIDECAR_LOG_LEVEL"

# Función para esperar que Cassandra esté listo
wait_for_cassandra() {
    local max_attempts=60  # Increased from 30 to 60 (5 minutes total)
    local attempt=1
    
    echo "⏳ Waiting for Cassandra node $CASSANDRA_HOST to be ready..."
    while [ $attempt -le $max_attempts ]; do
        if nc -z $CASSANDRA_HOST $CASSANDRA_PORT 2>/dev/null; then
            echo "✅ Cassandra node $CASSANDRA_HOST is ready"
            return 0
        fi
        echo "⏳ Cassandra node $CASSANDRA_HOST not ready (attempt $attempt/$max_attempts)"
        sleep 5
        attempt=$((attempt + 1))
    done
    
    echo "❌ Timeout waiting for Cassandra node $CASSANDRA_HOST"
    return 1
}

# Wait a bit for Cassandra to start up (multi-node clusters take longer)
echo "⏳ Giving Cassandra time to initialize..."
sleep 30

# Esperar a que Cassandra esté listo
wait_for_cassandra

# Crear directorio de configuración
mkdir -p /opt/sidecar/conf

# Generar configuración del sidecar
cat > /opt/sidecar/conf/sidecar.yaml << EOF
cassandra_instances:
  - id: 1
    host: $CASSANDRA_HOST
    port: $CASSANDRA_PORT
    data_center: datacenter1
    rack: rack1
    jmx_host: $CASSANDRA_HOST
    jmx_port: $CASSANDRA_JMX_PORT
    jmx_ssl_enabled: false
    storage_dir: /var/lib/cassandra
    data_dirs:
      - /var/lib/cassandra/data
    staging_dir: /tmp/sidecar-staging

sidecar:
  host: 0.0.0.0
  port: $SIDECAR_PORT
  health_check_frequency: $SIDECAR_HEALTH_CHECK_FREQUENCY
  
logging:
  level: $SIDECAR_LOG_LEVEL
  loggers:
    org.apache.cassandra.sidecar: $SIDECAR_LOG_LEVEL
    io.vertx: WARN
    org.apache.cassandra: INFO

server:
  request_idle_timeout_millis: 300000
  request_timeout_millis: 300000
EOF

echo "✅ Sidecar configuration created"

# Crear directorio de logs y staging
mkdir -p /opt/sidecar/logs
mkdir -p /tmp/sidecar-staging

echo "🚀 Starting Cassandra Sidecar service..."

# Ejecutar el sidecar
exec /opt/sidecar/bin/cassandra-sidecar \
    --config-file /opt/sidecar/conf/sidecar.yaml