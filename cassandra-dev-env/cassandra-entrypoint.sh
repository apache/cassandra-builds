#!/bin/bash

# Unified Cassandra + Sidecar Docker Entrypoint Script
# Configures and starts both Cassandra and Sidecar in the same container

# set -e

# Configurar variables de entorno si no están definidas
CASSANDRA_CLUSTER_NAME=${CASSANDRA_CLUSTER_NAME:-"DevCluster"}
CASSANDRA_DC=${CASSANDRA_DC:-"datacenter1"}
CASSANDRA_RACK=${CASSANDRA_RACK:-"rack1"}
CASSANDRA_ENDPOINT_SNITCH=${CASSANDRA_ENDPOINT_SNITCH:-"GossipingPropertyFileSnitch"}
CASSANDRA_SEEDS=${CASSANDRA_SEEDS:-"cassandra-1"}
CASSANDRA_LISTEN_ADDRESS=${CASSANDRA_LISTEN_ADDRESS:-"$(hostname -i)"}
CASSANDRA_BROADCAST_ADDRESS=${CASSANDRA_BROADCAST_ADDRESS:-"$CASSANDRA_LISTEN_ADDRESS"}
CASSANDRA_RPC_ADDRESS=${CASSANDRA_RPC_ADDRESS:-"0.0.0.0"}
CASSANDRA_BROADCAST_RPC_ADDRESS=${CASSANDRA_BROADCAST_RPC_ADDRESS:-"localhost"}
MAX_HEAP_SIZE=${MAX_HEAP_SIZE:-"1G"}
HEAP_NEWSIZE=${HEAP_NEWSIZE:-"256M"}
DEBUG_MODE=${DEBUG_MODE:-"false"}

# Sidecar configuration variables
ENABLE_SIDECAR=${ENABLE_SIDECAR:-"true"}
SIDECAR_PORT=${SIDECAR_PORT:-9043}
SIDECAR_HEALTH_CHECK_FREQUENCY=${SIDECAR_HEALTH_CHECK_FREQUENCY:-30s}
SIDECAR_LOG_LEVEL=${SIDECAR_LOG_LEVEL:-DEBUG}

# SSL/mTLS configuration variables
ENABLE_SSL=${ENABLE_SSL:-"true"}
SSL_CERT_DIR=${SSL_CERT_DIR:-"/opt/ssl-certs"}
SSL_KEYSTORE_PASSWORD=${SSL_KEYSTORE_PASSWORD:-"cassandra"}
SSL_TRUSTSTORE_PASSWORD=${SSL_TRUSTSTORE_PASSWORD:-"cassandra"}
SSL_CLIENT_AUTH=${SSL_CLIENT_AUTH:-"REQUIRED"}  # NONE, REQUEST, REQUIRED

echo "🚀 Configuring unified Cassandra + Sidecar node..."
echo "   Sidecar Enabled: $ENABLE_SIDECAR"
echo "   SSL/mTLS Enabled: $ENABLE_SSL"
echo "   Cluster: $CASSANDRA_CLUSTER_NAME"
echo "   Seeds: $CASSANDRA_SEEDS"
echo "   Listen Address: $CASSANDRA_LISTEN_ADDRESS"
echo "   Broadcast Address: $CASSANDRA_BROADCAST_ADDRESS"
echo "   RPC Address: $CASSANDRA_RPC_ADDRESS"
echo "   Broadcast RPC Address: $CASSANDRA_BROADCAST_RPC_ADDRESS"
echo "   Network: $(hostname -I | tr -d ' \n')"
echo "   Hostname: $(hostname)"
if [ "$ENABLE_SIDECAR" = "true" ]; then
    echo "   Sidecar Port: $SIDECAR_PORT"
    echo "   Sidecar Health Check: $SIDECAR_HEALTH_CHECK_FREQUENCY"
    if [ "$ENABLE_SSL" = "true" ]; then
        echo "   SSL Certificates: $SSL_CERT_DIR"
        echo "   SSL Client Auth: $SSL_CLIENT_AUTH"
    fi
fi

# Add environment variable to enable remote JMX for Sidecar connectivity
export LOCAL_JMX=no
export JVM_OPTS="$JVM_OPTS -Djava.rmi.server.hostname=localhost"

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

# Configure authentication to use password authentication
sed -i "s/class_name: AllowAllAuthenticator/class_name: PasswordAuthenticator/" "$CONFIG_FILE"
sed -i "s/authenticator: AllowAllAuthenticator/authenticator: PasswordAuthenticator/" "$CONFIG_FILE"
sed -i "s/authorizer: AllowAllAuthorizer/authorizer: CassandraAuthorizer/" "$CONFIG_FILE"

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

echo "✅ Configuration complete. Starting services..."

# Configure debug mode if enabled
if [ "$DEBUG_MODE" = "true" ]; then
    echo "🐛 Debug mode enabled - using verbose logging"
    export CASSANDRA_LOGBACK_CONFIG_FILE="/opt/cassandra/conf/logback-debug.xml"
fi

# Function to configure Cassandra for SSL
configure_cassandra_ssl() {
    if [ "$ENABLE_SSL" != "true" ]; then
        return 0
    fi

    echo "🔐 Configuring Cassandra for SSL client connections..."

    local config_file="/opt/cassandra/conf/cassandra.yaml"

    # Enable native transport SSL
    if ! grep -q "client_encryption_options:" "$config_file"; then
        echo "Adding SSL client encryption configuration to cassandra.yaml"
        cat >> "$config_file" << EOF

# Client-side SSL configuration for native transport
client_encryption_options:
    enabled: true
    optional: false
    keystore: $SSL_CERT_DIR/server-keystore.p12
    keystore_password: $SSL_KEYSTORE_PASSWORD
    truststore: $SSL_CERT_DIR/truststore.p12
    truststore_password: $SSL_TRUSTSTORE_PASSWORD
    protocol: TLS
    store_type: PKCS12
    cipher_suites: [TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384, TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256, TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256]
    require_client_auth: true
EOF
    else
        echo "✅ SSL client encryption already configured in cassandra.yaml"
    fi

    echo "✅ Cassandra SSL configuration complete"
}

# Function to generate sidecar configuration
generate_sidecar_config() {
    if [ "$ENABLE_SIDECAR" != "true" ]; then
        return 0
    fi

    echo "🔧 Generating Sidecar configuration..."

    # Create sidecar configuration directory
    mkdir -p /opt/sidecar/conf
    mkdir -p /opt/sidecar/logs
    mkdir -p /tmp/sidecar-staging

    # Get current container IP
    local container_ip=$(hostname -i | awk '{print $1}')

    # For sidecar connection, use localhost instead of container IP for internal connectivity
    local sidecar_host="localhost"

    # Build contact points list for multi-node cluster dynamically
    # Use localhost for sidecar internal connections
    local contact_points_yaml=""

    # Parse seeds and current node to build contact points
    # First add all seed nodes
    IFS=',' read -ra SEED_ARRAY <<< "$CASSANDRA_SEEDS"
    for seed in "${SEED_ARRAY[@]}"; do
        seed=$(echo "$seed" | xargs)  # trim whitespace
        if [ -n "$seed" ]; then
            # Try to resolve the seed hostname to IP
            local seed_ip=""
            if seed_ip=$(getent hosts "$seed" 2>/dev/null | awk '{print $1}' | head -1); then
                contact_points_yaml="${contact_points_yaml}    - \"$seed_ip\"\n"
                echo "ℹ️  Added seed $seed -> $seed_ip to contact points"
            else
                echo "⚠️  Could not resolve seed $seed, skipping"
            fi
        fi
    done

    # Add current node if it's not already in seeds
    local current_in_seeds=false
    for seed in "${SEED_ARRAY[@]}"; do
        seed=$(echo "$seed" | xargs)
        if [ "$seed" = "$CASSANDRA_LISTEN_ADDRESS" ]; then
            current_in_seeds=true
            break
        fi
    done

    if [ "$current_in_seeds" = false ]; then
        contact_points_yaml="${contact_points_yaml}    - \"$container_ip\"\n"
        echo "ℹ️  Added current node $CASSANDRA_LISTEN_ADDRESS -> $container_ip to contact points"
    fi

    # If no contact points were built, fall back to current container only
    if [ -z "$contact_points_yaml" ]; then
        contact_points_yaml="    - \"$container_ip\"\n"
        echo "⚠️  No seeds resolved, using current container IP only"
    fi

    # Generate sidecar.yaml
    cat > /opt/sidecar/conf/sidecar.yaml << EOF
cassandra_instances:
  - id: 1
    host: localhost
    port: 9042
    data_center: $CASSANDRA_DC
    rack: $CASSANDRA_RACK
    jmx_host: localhost
    jmx_port: 7199
    jmx_ssl_enabled: false
    jmx_role: cassandra
    jmx_role_password: cassandra
    storage_dir: /var/lib/cassandra
    data_dirs:
      - /var/lib/cassandra/data
    staging_dir: /tmp/sidecar-staging

sidecar:
  host: 0.0.0.0
  port: $SIDECAR_PORT
  health_check_frequency: $SIDECAR_HEALTH_CHECK_FREQUENCY

sidecar_instances:
  - id: 1
    host: localhost
    port: $SIDECAR_PORT
  - id: 2
    host: $CASSANDRA_LISTEN_ADDRESS
    port: $SIDECAR_PORT

logging:
  level: $SIDECAR_LOG_LEVEL
  loggers:
    org.apache.cassandra.sidecar: $SIDECAR_LOG_LEVEL
    io.vertx: INFO
    org.apache.cassandra: INFO
    com.datastax.driver: DEBUG

server:
  request_idle_timeout_millis: 300000
  request_timeout_millis: 300000

driver_parameters:
  contact_points:
EOF

    # Add contact points to the YAML file
    printf "%b" "$contact_points_yaml" >> /opt/sidecar/conf/sidecar.yaml

    # Add the rest of the driver configuration
    # Sidecar always connects to Cassandra via HTTP (no SSL)
    cat >> /opt/sidecar/conf/sidecar.yaml << EOF
  contact_points:
    - "localhost:9042"
  num_connections: 6
  local_dc: $CASSANDRA_DC
  username: cassandra
  password: cassandra_test_env_password
EOF

    # Add SSL configuration for Sidecar server endpoints if enabled
    if [ "$ENABLE_SSL" = "true" ]; then
        cat >> /opt/sidecar/conf/sidecar.yaml << EOF

# SSL Configuration for Sidecar HTTPS endpoints
ssl:
  enabled: true
  use_openssl: false
  handshake_timeout: 10s
  client_auth: $SSL_CLIENT_AUTH
  accepted_protocols:
    - TLSv1.2
    - TLSv1.3
  cipher_suites:
    - TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
    - TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256
    - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
    - TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA
    - TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA
  keystore:
    type: PKCS12
    path: "$SSL_CERT_DIR/server-keystore.p12"
    password: "$SSL_KEYSTORE_PASSWORD"
    check_interval: 5m
  truststore:
    type: PKCS12
    path: "$SSL_CERT_DIR/truststore.p12"
    password: "$SSL_TRUSTSTORE_PASSWORD"
EOF

        # Add access control configuration for mTLS authentication
        cat >> /opt/sidecar/conf/sidecar.yaml << EOF

# Access Control Configuration for mTLS authentication
access_control:
  enabled: true
  authenticators:
    - class_name: org.apache.cassandra.sidecar.acl.authentication.MutualTlsAuthenticationHandlerFactory
      parameters:
        certificate_validator: io.vertx.ext.auth.mtls.impl.CertificateValidatorImpl
        certificate_identity_extractor: org.apache.cassandra.sidecar.acl.authentication.CassandraIdentityExtractor
  admin_identities:
    - spiffe://cassandra/sidecar/admin
EOF
        echo "✅ SSL configuration and mTLS access control added to Sidecar endpoints"
    fi

    echo "✅ Sidecar configuration generated with contact points from: [$contact_points_yaml]"
}

# Function to initialize authentication
initialize_auth() {
    echo "🔐 Initializing Cassandra authentication..."

    # Wait for Cassandra to be ready for CQL connections
    local max_attempts=60
    local attempt=1

    echo "⏳ Waiting for Cassandra CQL to be ready for authentication setup..."
    while [ $attempt -le $max_attempts ]; do
        if nc -z localhost 9042 2>/dev/null; then
            echo "✅ Cassandra CQL port is ready"
            break
        fi
        echo "⏳ Cassandra CQL not ready (attempt $attempt/$max_attempts)"
        sleep 5
        attempt=$((attempt + 1))
    done

    if [ $attempt -gt $max_attempts ]; then
        echo "❌ Timeout waiting for Cassandra CQL"
        return 1
    fi

    # Wait a bit more for Cassandra to fully initialize
    sleep 15

    # Try to connect and set up authentication
    echo "🔐 Setting up default cassandra user..."

    # First, try to connect as the default cassandra user (this should work initially)
    # and change its password to 'cassandra'
    for i in {1..10}; do
        if cqlsh -u cassandra -p cassandra localhost -e "ALTER USER cassandra WITH PASSWORD 'cassandra_test_env_password';" 2>/dev/null; then
            echo "✅ Successfully configured cassandra user password"
            return 0
        else
            echo "⏳ Waiting for authentication system to be ready (attempt $i/10)..."
            sleep 10
        fi
    done

    echo "⚠️  Could not set up authentication - this might be normal for non-seed nodes"
    return 0
}

# Function to start sidecar
start_sidecar() {
    if [ "$ENABLE_SIDECAR" != "true" ]; then
        return 0
    fi

    echo "🚀 Starting Cassandra Sidecar..."

    # Wait for Cassandra to be fully ready before starting sidecar
    local max_attempts=60
    local attempt=1

    echo "⏳ Waiting for Cassandra CQL to be ready..."
    while [ $attempt -le $max_attempts ]; do
        if nc -z localhost 9042 2>/dev/null; then
            echo "✅ Cassandra CQL is ready"
            break
        fi
        echo "⏳ Cassandra CQL not ready (attempt $attempt/$max_attempts)"
        sleep 5
        attempt=$((attempt + 1))
    done

    if [ $attempt -gt $max_attempts ]; then
        echo "❌ Timeout waiting for Cassandra CQL - will try to start Sidecar anyway"
    fi

    # Additional wait to ensure cluster is fully initialized
    echo "⏳ Waiting additional time for cluster initialization..."
    sleep 15  # Reduced from 30 to 15 seconds

    # Test sidecar binary before starting
    if [ ! -x "/opt/sidecar/bin/cassandra-sidecar" ]; then
        echo "❌ Sidecar binary not found or not executable"
        return 1
    fi

    # Test configuration file
    if [ ! -f "/opt/sidecar/conf/sidecar.yaml" ]; then
        echo "❌ Sidecar configuration file not found"
        return 1
    fi

    echo "ℹ️ Starting Sidecar (non-blocking)..."
    # Start sidecar in background without hanging the main process
    (
        # Run sidecar with localhost hostname override to avoid 'cassandra-1' hostname in service discovery
        export HOSTNAME=localhost
        /opt/sidecar/bin/cassandra-sidecar \
            -Djava.net.preferIPv4Stack=true \
            -Dvertx.hostname=localhost \
            -Dsidecar.hostname=localhost \
            --config-file /opt/sidecar/conf/sidecar.yaml >> /opt/sidecar/logs/sidecar.log 2>&1
    ) &
    local sidecar_pid=$!

    echo "✅ Sidecar startup initiated with PID: $sidecar_pid"
    echo $sidecar_pid > /tmp/sidecar.pid

    # Give it a moment and check if it's still running
    sleep 2
    if kill -0 $sidecar_pid 2>/dev/null; then
        echo "✅ Sidecar process is running"
    else
        echo "⚠️ Sidecar process may have failed - check logs later"
    fi
}

# Function to handle shutdown
shutdown_handler() {
    echo "🛑 Received shutdown signal..."

    # Stop sidecar if running
    if [ -f /tmp/sidecar.pid ]; then
        local sidecar_pid=$(cat /tmp/sidecar.pid)
        if kill -0 $sidecar_pid 2>/dev/null; then
            echo "🛑 Stopping Sidecar (PID: $sidecar_pid)..."
            kill $sidecar_pid
            wait $sidecar_pid 2>/dev/null
        fi
        rm -f /tmp/sidecar.pid
    fi

    # Cassandra will be stopped by the main process exit
    echo "🛑 Shutdown complete"
    exit 0
}

# Set up signal handlers
trap shutdown_handler SIGTERM SIGINT

# Configure Cassandra for SSL if enabled
configure_cassandra_ssl

# Generate sidecar configuration if enabled
generate_sidecar_config

# Start Cassandra in background
echo "🚀 Starting Cassandra..."
/opt/cassandra/bin/cassandra > /opt/cassandra/logs/cassandra.log 2>&1 &
cassandra_pid=$!
echo "✅ Cassandra started with PID: $cassandra_pid"

# Initialize authentication (only for seed nodes to avoid conflicts)
if [ "$CASSANDRA_LISTEN_ADDRESS" = "cassandra-1" ]; then
    initialize_auth
fi

# Start sidecar if enabled
start_sidecar

# Wait for Cassandra process and handle shutdown
echo "✅ Both services started. Monitoring Cassandra Java process..."
while true; do
    # Check if Cassandra Java process is running
    if pgrep -f "org.apache.cassandra.service.CassandraDaemon" > /dev/null; then
        sleep 10
    else
        echo "❌ Cassandra Java process has exited. Container will shut down."
        exit 1
    fi
done
