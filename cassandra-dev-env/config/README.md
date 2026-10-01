# Configuration Override README

This directory contains configuration templates and overrides for Cassandra and Sidecar components.

## Usage

### Cassandra Configuration Override

1. **Main Configuration**: Copy `cassandra.yaml.example` to `cassandra.yaml` and modify as needed
2. **Logging Configuration**: Copy `logback.xml.example` to `logback.xml` and modify as needed
3. **JVM Options**: Create `jvm.options` file for JVM tuning parameters

### Sidecar Configuration Override

1. **Main Configuration**: Copy `sidecar.yaml.example` to `sidecar.yaml` and modify as needed
2. **Logging Configuration**: Create `logback.xml` for sidecar logging configuration

## File Structure

```
config/
├── cassandra/
│   ├── cassandra.yaml.example    # Cassandra main configuration template
│   ├── logback.xml.example       # Cassandra logging configuration template
│   ├── cassandra.yaml           # Your custom Cassandra configuration (optional)
│   ├── logback.xml              # Your custom logging configuration (optional)
│   └── jvm.options              # Your custom JVM options (optional)
└── sidecar/
    ├── sidecar.yaml.example     # Sidecar configuration template
    ├── sidecar.yaml            # Your custom sidecar configuration (optional)
    └── logback.xml             # Your custom sidecar logging configuration (optional)
```

## How It Works

- The setup script automatically detects configuration files in these directories
- If custom configuration files exist, they are mounted into the containers
- If no custom files exist, the default configurations are used
- Configuration files are mounted as read-only volumes

## Examples

### Enable Authentication in Cassandra

Create `config/cassandra/cassandra.yaml`:
```yaml
authenticator: PasswordAuthenticator
authorizer: CassandraAuthorizer
role_manager: CassandraRoleManager
```

### Increase JVM Heap Size

Create `config/cassandra/jvm.options`:
```
-Xms2G
-Xmx2G
-XX:+UseG1GC
-XX:G1HeapRegionSize=16m
```

### Enable Debug Logging

Create `config/cassandra/logback.xml` with DEBUG level logging for specific packages.

### Custom Sidecar Configuration

Create `config/sidecar/sidecar.yaml`:
```yaml
sidecar:
  host: 0.0.0.0
  port: 9043
  health_check_frequency: 10s

logging:
  level: DEBUG
  loggers:
    org.apache.cassandra.sidecar: DEBUG
```

## Notes

- Configuration files are node-specific when using multi-node clusters
- Environment variables in the docker-compose setup take precedence over some configuration values
- Always backup your custom configurations before upgrading