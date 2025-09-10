# Cassandra Development Environment Manager

A comprehensive Apache Cassandra development environment management tool using Docker Compose, built from the latest source code. The environment supports multi-node clusters, Cassandra Sidecar integration, and complete lifecycle management.

## Requirements

- **Go 1.21+** (for building from source)
- **Docker Desktop** with **at least 8GB memory allocation** (16GB+ recommended for multi-node clusters)
- **Docker Compose**
- **Java 11** (OpenJDK)
- **Apache Ant**
- **Git**

### Docker Desktop Configuration

**Important**: Cassandra clusters require significant memory. Before starting:

1. Open Docker Desktop → Settings → Resources → Advanced
2. Set **Memory** to at least **8GB** (16GB recommended for 3+ node clusters)
3. Set **CPUs** to at least **4** (6-8 recommended)
4. Apply & Restart Docker Desktop

**Memory allocation per configuration:**
- Single node: 6GB container memory + 1536M heap
- 3-node cluster: 6GB container memory per node + 1536M heap each
- Larger clusters: 6GB container memory per node + optimized heap sizing

## Installation

### Option 1: Use Pre-built Binary

Download the pre-built binary for your platform from the releases page.

### Option 2: Build from Source

```bash
# Clone the repository
git clone <repository-url>
cd cassandra-env

# Build for current platform
make build

# Or build manually
go build -o cassandra-env-manager ./cmd
```

### Cross-Platform Builds

```bash
# Build for all platforms
make build-all

# Build for specific platforms
make build-linux    # Linux AMD64
make build-darwin   # macOS AMD64  
make build-windows  # Windows AMD64
```

## Usage

The tool provides a unified interface for managing Cassandra development environments:

### Environment Management Commands

```bash
# Setup new environment
./cassandra-env-manager                    # Full setup with 3-node cluster

# Environment lifecycle
./cassandra-env-manager --status           # Check environment status
./cassandra-env-manager --stop             # Stop running environment
./cassandra-env-manager --start            # Start stopped environment
./cassandra-env-manager --teardown         # Complete cleanup

# Monitoring and debugging
./cassandra-env-manager --logs cassandra-1 # View logs for specific service
./cassandra-env-manager --logs             # List available services
```

### Build and Deploy Options

```bash
# Build options
./cassandra-env-manager --build            # Build only, don't start
./cassandra-env-manager --clean            # Clean rebuild
./cassandra-env-manager --start-only       # Start existing environment

# Code source options
./cassandra-env-manager --branch cassandra-4.1     # Use specific branch
./cassandra-env-manager --commit abc123            # Use specific commit
./cassandra-env-manager --pr 2845                  # Use specific pull request
./cassandra-env-manager --local-cassandra /path    # Use local Cassandra repository
./cassandra-env-manager --local-sidecar /path      # Use local Sidecar repository

# Cluster configuration
./cassandra-env-manager --nodes 5          # 5-node cluster
./cassandra-env-manager --nodes 1          # Single node

# Sidecar integration
./cassandra-env-manager --sidecar          # Enable Cassandra Sidecar
./cassandra-env-manager --sidecar-branch trunk     # Use specific sidecar branch
./cassandra-env-manager --sidecar-commit abc123    # Use specific sidecar commit
./cassandra-env-manager --sidecar-pr 123           # Use specific sidecar pull request
```

### Usage Examples

```bash
# Environment Management
./cassandra-env-manager                    # Full setup with 3-node cluster
./cassandra-env-manager --status           # Check environment status
./cassandra-env-manager --stop             # Stop the environment
./cassandra-env-manager --start            # Start the environment
./cassandra-env-manager --teardown         # Complete cleanup
./cassandra-env-manager --logs cassandra-1 # View logs for cassandra-1

# Setup and Configuration
./cassandra-env-manager --nodes 5          # 5-node cluster with trunk
./cassandra-env-manager --nodes 1          # Single node cluster
./cassandra-env-manager --branch cassandra-4.1 # Use cassandra-4.1 branch
./cassandra-env-manager --commit abc123    # Use specific commit
./cassandra-env-manager --pr 2845          # Use pull request #2845
./cassandra-env-manager --sidecar --nodes 2 # 2-node cluster with sidecar

# Local Development
./cassandra-env-manager --local-cassandra /path/to/cassandra # Use local Cassandra repo
./cassandra-env-manager --local-sidecar /path/to/sidecar     # Use local Sidecar repo
./cassandra-env-manager --local-cassandra /path/to/cassandra --local-sidecar /path/to/sidecar # Use both local repos

# Development Workflow
./cassandra-env-manager --nodes 1 --build  # Build single node environment
./cassandra-env-manager --start            # Start the built environment
./cassandra-env-manager --status           # Check status
./cassandra-env-manager --logs cassandra-1 # Monitor logs
./cassandra-env-manager --teardown         # Clean up when done
```

## Features

### Core Capabilities
- ✅ **Multi-node cluster support**: Configurable cluster size (1-10 nodes)
- ✅ **Unified container architecture**: Single container per node running both Cassandra and Sidecar
- ✅ **Built-in authentication**: Password-based authentication enabled by default
- ✅ **mTLS support**: Optional mutual TLS authentication for secure communication
- ✅ **Dynamic configuration**: Automatic Docker Compose generation
- ✅ **Code source flexibility**: Support for branches, commits, PRs, and local repositories
- ✅ **Cassandra Sidecar integration**: Optional REST API deployment
- ✅ **Configuration overrides**: Custom Cassandra and Sidecar configurations
- ✅ **Cross-platform compatibility**: Single binary runs on Linux, macOS, and Windows
- ✅ **Resource optimization**: Adaptive memory/CPU allocation based on cluster size

### Enhanced Features
- **Automatic repository cleanup**: Prevents git conflicts when switching versions
- **Coordinated startup**: Proper seed node strategy for reliable cluster formation
- **Real-time monitoring**: Environment status, cluster health, and resource usage
- **Enhanced logging**: Detailed startup progress and comprehensive diagnostics
- **Type safety**: Compile-time error checking with structured error handling
- **Better performance**: Efficient process management and improved I/O operations

## Configuration Override System

The environment manager supports configuration overrides for both Cassandra and Sidecar components:

### Override Files

Place custom configuration files in the `config/` directory:

```
config/
├── cassandra/
│   ├── cassandra.yaml           # Custom Cassandra configuration
│   ├── logback.xml              # Custom logging configuration
│   └── jvm.options              # Custom JVM options
└── sidecar/
    ├── sidecar.yaml             # Custom Sidecar configuration
    └── logback.xml              # Custom Sidecar logging
```

### Configuration Examples

**Custom authentication settings:**
```yaml
# config/cassandra/cassandra.yaml
# Authentication is enabled by default with PasswordAuthenticator
# Default credentials: cassandra/cassandra
authenticator: PasswordAuthenticator
authorizer: CassandraAuthorizer
role_manager: CassandraRoleManager
```

**Increase JVM heap size:**
```
# config/cassandra/jvm.options
-Xms2G
-Xmx2G
-XX:+UseG1GC
-XX:G1HeapRegionSize=16m
```

**Custom Sidecar configuration:**
```yaml
# config/sidecar/sidecar.yaml
sidecar:
  host: 0.0.0.0
  port: 9043
  health_check_frequency: 10s

logging:
  level: DEBUG
  loggers:
    org.apache.cassandra.sidecar: DEBUG
```

## Authentication

The environment is configured with **password authentication enabled by default** for both CQL and JMX connections:

### Default Credentials
- **Username**: `cassandra`
- **Password**: `cassandra`

### Connection Examples
```bash
# CQL connection (cqlsh)
COMPOSE_BAKE=false docker-compose exec cassandra-1 cqlsh -u cassandra -p cassandra

# JMX connection (nodetool)
COMPOSE_BAKE=false docker-compose exec cassandra-1 nodetool -u cassandra -pw cassandra status

# Sidecar health check (no authentication required for health endpoints)
curl http://localhost:9043/api/v1/cassandra/native/__health?instanceId=1
curl http://localhost:9043/api/v1/cassandra/jmx/__health?instanceId=1
```

### Changing Default Credentials
To use different credentials, update the configuration in your custom `config/cassandra/cassandra.yaml`:

```yaml
# After cluster startup, connect and change password:
# COMPOSE_BAKE=false docker-compose exec cassandra-1 cqlsh -u cassandra -p cassandra
# ALTER USER cassandra WITH PASSWORD 'new_password';
```

## mTLS (Mutual TLS) Configuration

The environment supports **optional mTLS authentication** for secure communication between Sidecar and Cassandra:

### Enabling mTLS

Set environment variables to enable SSL/mTLS:

```bash
# Enable mTLS for the entire cluster
export ENABLE_SSL=true
export SSL_CLIENT_AUTH=REQUIRED  # Options: NONE, REQUEST, REQUIRED

# Optional: Custom certificate passwords (default: cassandra)
export SSL_KEYSTORE_PASSWORD=your_keystore_password
export SSL_TRUSTSTORE_PASSWORD=your_truststore_password

# Start cluster with mTLS enabled
./cassandra-env-manager --sidecar --nodes 3
```

### mTLS Features

- **Automatic Certificate Generation**: CA, server, and client certificates auto-generated on first startup
- **PKCS12 Format**: Modern certificate format compatible with both Cassandra and Sidecar
- **Shared Certificates**: Single certificate set shared across all cluster nodes
- **Client Authentication**: Configurable client authentication modes (NONE/REQUEST/REQUIRED)
- **Strong Cipher Suites**: TLS 1.2/1.3 with secure cipher suites

### Certificate Details

When mTLS is enabled, certificates are automatically generated with:

- **Certificate Authority (CA)**: Self-signed root CA for the cluster
- **Server Certificate**: For Cassandra native transport SSL
- **Client Certificate**: For Sidecar-to-Cassandra authentication  
- **Truststore**: Contains CA certificate for validation
- **Validity**: 365 days (configurable in generation script)
- **SANs**: Includes localhost, cassandra-1 through cassandra-5, and IP addresses

### Connection Examples with mTLS

```bash
# Sidecar health endpoints (HTTPS with client certificate validation)
curl --cert /opt/ssl-certs/client-cert.pem \
     --key /opt/ssl-certs/client-key.pem \
     --cacert /opt/ssl-certs/ca-cert.pem \
     https://localhost:9043/api/v1/cassandra/native/__health?instanceId=1

# CQL connection with SSL (requires SSL-enabled cqlsh or driver)
# Note: Standard cqlsh requires SSL configuration in cqlshrc
```

### Custom Certificates

To use custom certificates instead of auto-generated ones:

1. Place your certificates in `/opt/ssl-certs/` directory:
   - `server-keystore.p12` - Server certificate and key
   - `client-keystore.p12` - Client certificate and key  
   - `truststore.p12` - CA certificates for validation

2. Set appropriate passwords via environment variables

3. Restart the cluster

### Troubleshooting mTLS

```bash
# Check certificate generation logs
./cassandra-env-manager --logs cassandra-1 | grep -i ssl

# Verify certificates exist
COMPOSE_BAKE=false docker-compose exec cassandra-1 ls -la /opt/ssl-certs/

# Check SSL configuration
COMPOSE_BAKE=false docker-compose exec cassandra-1 grep -A 10 "client_encryption_options" /opt/cassandra/conf/cassandra.yaml

# View certificate details
COMPOSE_BAKE=false docker-compose exec cassandra-1 openssl x509 -in /opt/ssl-certs/server-cert.pem -text -noout
```

## Working with the Cluster

The tool automatically generates a Cassandra cluster with the specified number of nodes. Each node has unique ports:

**Port mapping:**
- Node 1: CQL 9042, JMX 7199, Inter-node 7000-7001, Thrift 9160, Sidecar 9043
- Node 2: CQL 9044, JMX 7200, Inter-node 7010-7011, Thrift 9161, Sidecar 9045
- Node N: CQL 9042+(N-1)*2, JMX 7199+(N-1), Inter-node 7000+(N-1)*10, Sidecar 9043+(N-1)*2

### Common Operations

```bash
# Connect to node 1 (authentication required)
COMPOSE_BAKE=false docker-compose exec cassandra-1 cqlsh -u cassandra -p cassandra

# View cluster status
./cassandra-env-manager --status

# Check cluster health from any node (JMX authentication required)
COMPOSE_BAKE=false docker-compose exec cassandra-1 nodetool -u cassandra -pw cassandra status

# Monitor logs
./cassandra-env-manager --logs cassandra-1

# Verify sidecar (if enabled)
curl http://localhost:9043/health

# Connect to sidecar of node 2
curl http://localhost:9045/health
```

## Cassandra Sidecar Integration

The project includes optional support for [Cassandra Sidecar](https://github.com/apache/cassandra-sidecar), providing REST APIs for Cassandra operations.

### Sidecar Features
- **REST API**: Endpoints for administration and monitoring operations
- **Unified deployment**: Sidecar runs alongside Cassandra in the same container
- **Automatic configuration**: Automatically connects to localhost Cassandra with authentication
- **Health endpoints**: Native and JMX health checks available
- **Code flexibility**: Supports specific branches, commits, and pull requests
- **Local development**: Supports local sidecar repositories

### Sidecar Usage

```bash
# Enable sidecar with trunk
./cassandra-env-manager --sidecar

# Single node with sidecar
./cassandra-env-manager --nodes 1 --sidecar

# Use specific sidecar branch
./cassandra-env-manager --sidecar --sidecar-branch cassandra-sidecar-1.0

# Use specific sidecar commit
./cassandra-env-manager --sidecar --sidecar-commit abc123

# Use sidecar pull request
./cassandra-env-manager --sidecar --sidecar-pr 123

# Local sidecar development
./cassandra-env-manager --local-sidecar /path/to/sidecar --sidecar
```

## Architecture

The Go implementation is organized into several packages:

- `cmd/` - CLI entry point and command handling
- `internal/config/` - Configuration management and validation
- `internal/docker/` - Docker Compose generation and container operations
- `internal/git/` - Git repository management
- `internal/cassandra/` - Cassandra build system integration
- `internal/sidecar/` - Sidecar build system integration
- `internal/system/` - Cross-platform command execution

## Development

### Typical Development Session

```bash
# 1. Setup environment
./cassandra-env-manager --nodes 1 --sidecar

# 2. Check status
./cassandra-env-manager --status

# 3. Monitor logs during development
./cassandra-env-manager --logs cassandra-1

# 4. Stop environment when taking a break
./cassandra-env-manager --stop

# 5. Resume work
./cassandra-env-manager --start

# 6. Clean up when done
./cassandra-env-manager --teardown
```

### Update Cassandra

To update to the latest version of trunk:

```bash
./cassandra-env-manager --teardown
./cassandra-env-manager --clean
```

## Project Structure

```
cassandra-env/
├── cassandra-env-manager       # Go binary (main tool)
├── Dockerfile                  # Unified Cassandra + Sidecar Docker image
├── cassandra-entrypoint.sh     # Unified container entrypoint script
├── docker-compose.yml          # Service configuration (generated)
├── cmd/                        # CLI entry point
├── internal/                   # Go packages
│   ├── config/                # Configuration management
│   ├── docker/                # Docker operations
│   ├── git/                   # Git repository management
│   ├── cassandra/             # Cassandra build integration
│   ├── sidecar/               # Sidecar build integration
│   └── system/                # System command execution
├── config/                     # Configuration overrides
│   ├── README.md              # Configuration documentation
│   ├── cassandra/             # Cassandra configuration overrides
│   └── sidecar/               # Sidecar configuration overrides
├── cassandra/                  # Cassandra source code (generated)
├── cassandra-sidecar/          # Sidecar source code (generated)
├── Makefile                    # Build automation
└── README.md                   # This file
```

## Exposed Ports

- **9042**: CQL native transport port (for connecting with drivers)
- **7000**: Inter-node communication
- **7001**: Inter-node communication (SSL)
- **7199**: JMX
- **9160**: Thrift (deprecated)
- **9043+**: Sidecar API ports (when enabled)

## Volumes

- `cassandra_data_N`: Persistent Cassandra data for node N
- `cassandra_logs_N`: Cassandra logs for node N
- `sidecar_logs_N`: Sidecar logs for node N (when enabled)

## Configuration

The cluster is configured with:
- Cluster name: DevCluster
- Datacenter: datacenter1
- Rack: rack1
- Snitch: GossipingPropertyFileSnitch
- Authentication: PasswordAuthenticator (enabled)
- Default credentials: cassandra/cassandra
- JMX authentication: cassandra/cassandra

## Troubleshooting

### Common Issues

- **Build errors**: Ensure Go 1.21+ is installed and `make build` completes successfully
- **Memory errors**: Adjust Docker Desktop resources (minimum 8GB)
- **Port conflicts**: Check that ports are not already in use by other services
- **Stale containers**: Use `--teardown` to completely clean up the environment
- **Docker issues**: Ensure Docker Desktop is running and accessible

### Environment Issues

```bash
# Check environment status
./cassandra-env-manager --status

# View logs for troubleshooting
./cassandra-env-manager --logs cassandra-1

# Complete cleanup and restart
./cassandra-env-manager --teardown
./cassandra-env-manager --clean
```

### Performance Optimization

- **Resource allocation**: Adjust Docker Desktop memory/CPU limits
- **Cluster size**: Use fewer nodes for development (--nodes 1)
- **Local repositories**: Use --local-cassandra and --local-sidecar for faster builds
- **Build caching**: Use --build option to avoid unnecessary rebuilds

## Contributing

1. Ensure Go 1.21+ is installed
2. Run tests: `go test ./...`
3. Format code: `go fmt ./...`
4. Build and test: `make build && ./cassandra-env-manager --help`
5. Test all major workflows before submitting changes

## License

This project maintains the same license as Apache Cassandra.