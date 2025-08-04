#!/bin/bash

# Cassandra Docker Entrypoint Script
# Configures Cassandra for multi-node cluster deployment

set -e

# Configurar variables de entorno si no están definidas
CASSANDRA_CLUSTER_NAME=${CASSANDRA_CLUSTER_NAME:-"DevCluster"}
CASSANDRA_DC=${CASSANDRA_DC:-"datacenter1"}
CASSANDRA_RACK=${CASSANDRA_RACK:-"rack1"}
CASSANDRA_ENDPOINT_SNITCH=${CASSANDRA_ENDPOINT_SNITCH:-"GossipingPropertyFileSnitch"}
CASSANDRA_SEEDS=${CASSANDRA_SEEDS:-"cassandra-1"}
CASSANDRA_LISTEN_ADDRESS=${CASSANDRA_LISTEN_ADDRESS:-"$(hostname -i)"}
CASSANDRA_BROADCAST_ADDRESS=${CASSANDRA_BROADCAST_ADDRESS:-"$CASSANDRA_LISTEN_ADDRESS"}
CASSANDRA_RPC_ADDRESS=${CASSANDRA_RPC_ADDRESS:-"0.0.0.0"}
CASSANDRA_BROADCAST_RPC_ADDRESS=${CASSANDRA_BROADCAST_RPC_ADDRESS:-"$CASSANDRA_LISTEN_ADDRESS"}
MAX_HEAP_SIZE=${MAX_HEAP_SIZE:-"1G"}
HEAP_NEWSIZE=${HEAP_NEWSIZE:-"256M"}
DEBUG_MODE=${DEBUG_MODE:-"false"}

echo "🚀 Configuring Cassandra node..."
echo "   Cluster: $CASSANDRA_CLUSTER_NAME"
echo "   Seeds: $CASSANDRA_SEEDS"
echo "   Listen Address: $CASSANDRA_LISTEN_ADDRESS"
echo "   Broadcast Address: $CASSANDRA_BROADCAST_ADDRESS"
echo "   RPC Address: $CASSANDRA_RPC_ADDRESS"
echo "   Broadcast RPC Address: $CASSANDRA_BROADCAST_RPC_ADDRESS"
echo "   Network: $(hostname -I | tr -d ' \n')"
echo "   Hostname: $(hostname)"

# Configurar cassandra.yaml
CONFIG_FILE="/opt/cassandra/conf/cassandra.yaml"

# Backup original config
if [ ! -f "$CONFIG_FILE.original" ]; then
    cp "$CONFIG_FILE" "$CONFIG_FILE.original"
fi

# Aplicar configuraciones
sed -i "s/^cluster_name:.*/cluster_name: '$CASSANDRA_CLUSTER_NAME'/" "$CONFIG_FILE"
sed -i "s/^.*seeds:.*/          - seeds: \"$CASSANDRA_SEEDS\"/" "$CONFIG_FILE"
sed -i "s/^listen_address:.*/listen_address: $CASSANDRA_LISTEN_ADDRESS/" "$CONFIG_FILE"
sed -i "s/^broadcast_address:.*/broadcast_address: $CASSANDRA_BROADCAST_ADDRESS/" "$CONFIG_FILE"
sed -i "s/^rpc_address:.*/rpc_address: $CASSANDRA_RPC_ADDRESS/" "$CONFIG_FILE"
sed -i "s/^# broadcast_rpc_address:.*/broadcast_rpc_address: $CASSANDRA_BROADCAST_RPC_ADDRESS/" "$CONFIG_FILE"
sed -i "s/^broadcast_rpc_address:.*/broadcast_rpc_address: $CASSANDRA_BROADCAST_RPC_ADDRESS/" "$CONFIG_FILE"
sed -i "s/^endpoint_snitch:.*/endpoint_snitch: $CASSANDRA_ENDPOINT_SNITCH/" "$CONFIG_FILE"

# Ensure system keyspaces are initialized
# Add flag to ensure system keyspaces (including system_auth) are created on first startup
sed -i "s/^# auto_bootstrap:.*/auto_bootstrap: false/" "$CONFIG_FILE"
echo "auto_bootstrap: false" >> "$CONFIG_FILE"

# Configurar datacenter y rack
RACK_DC_FILE="/opt/cassandra/conf/cassandra-rackdc.properties"
cat > "$RACK_DC_FILE" << EOF
dc=$CASSANDRA_DC
rack=$CASSANDRA_RACK
EOF

# Configurar JVM heap
JVM_OPTS_FILE="/opt/cassandra/conf/jvm11-server.options"
if [ -f "$JVM_OPTS_FILE" ]; then
    # Backup original
    if [ ! -f "$JVM_OPTS_FILE.original" ]; then
        cp "$JVM_OPTS_FILE" "$JVM_OPTS_FILE.original"
    fi
    
    # Actualizar heap settings
    sed -i "s/^-Xms.*/-Xms$MAX_HEAP_SIZE/" "$JVM_OPTS_FILE"
    sed -i "s/^-Xmx.*/-Xmx$MAX_HEAP_SIZE/" "$JVM_OPTS_FILE"
    # Only set HEAP_NEWSIZE if it's defined and not empty
    if [ -n "$HEAP_NEWSIZE" ]; then
        sed -i "s/^-Xmn.*/-Xmn$HEAP_NEWSIZE/" "$JVM_OPTS_FILE"
    else
        # Comment out any existing -Xmn line
        sed -i "s/^-Xmn.*/#-Xmn (auto-configured)/" "$JVM_OPTS_FILE"
    fi
    
    # Disable memory-intensive flags for low memory environments
    sed -i "s/^-XX:+AlwaysPreTouch/# -XX:+AlwaysPreTouch/" "$JVM_OPTS_FILE"
fi

# Crear directorio de logs si no existe
mkdir -p /opt/cassandra/logs

# Función para verificar conectividad de red
verify_network() {
    local max_attempts=10
    local attempt=1
    
    echo "🔍 Verifying network connectivity..."
    while [ $attempt -le $max_attempts ]; do
        if ping -c 1 cassandra-1 >/dev/null 2>&1; then
            echo "✅ Network connectivity verified"
            return 0
        fi
        echo "⏳ Waiting for network connectivity (attempt $attempt/$max_attempts)"
        sleep 5
        attempt=$((attempt + 1))
    done
    
    echo "❌ Network connectivity timeout"
    return 1
}

# Función para esperar que un nodo seed esté listo
wait_for_seed() {
    local seed_host=$1
    local max_attempts=60
    local attempt=1
    
    echo "🌱 Waiting for seed node $seed_host to be ready..."
    while [ $attempt -le $max_attempts ]; do
        if nc -z $seed_host 7000 2>/dev/null; then
            echo "✅ Seed node $seed_host is ready"
            return 0
        fi
        echo "⏳ Seed node $seed_host not ready (attempt $attempt/$max_attempts)"
        sleep 5
        attempt=$((attempt + 1))
    done
    
    echo "❌ Timeout waiting for seed node $seed_host"
    return 1
}

# Verificar conectividad de red primero
verify_network || exit 1

# Estrategia de startup coordinado basada en el rol del nodo
if [ "$CASSANDRA_LISTEN_ADDRESS" = "cassandra-1" ]; then
    echo "🌱 Starting as PRIMARY SEED NODE"
    echo "   - No wait time required"
    echo "   - Other nodes will connect to this node"
elif [ "$CASSANDRA_LISTEN_ADDRESS" = "cassandra-2" ]; then
    echo "🌿 Starting as SECONDARY SEED NODE"
    echo "   - Waiting for primary seed to be ready..."
    wait_for_seed "cassandra-1"
    sleep 30  # Additional time for primary seed to stabilize
else
    echo "🌾 Starting as REGULAR NODE"
    echo "   - Waiting for seed nodes to be ready..."
    
    # Esperar por el nodo seed primario
    wait_for_seed "cassandra-1"
    
    # Si hay seeds adicionales, esperar por ellos también
    if [[ "$CASSANDRA_SEEDS" == *"cassandra-2"* ]]; then
        wait_for_seed "cassandra-2"
    fi
    
    # Tiempo adicional para que el cluster se estabilice
    sleep 30
fi

echo "✅ Configuration complete. Starting Cassandra..."

# Configure debug mode if enabled
if [ "$DEBUG_MODE" = "true" ]; then
    echo "🐛 Debug mode enabled - using verbose logging"
    export CASSANDRA_LOGBACK_CONFIG_FILE="/opt/cassandra/conf/logback-debug.xml"
fi

# Ejecutar Cassandra
exec /opt/cassandra/bin/cassandra -f