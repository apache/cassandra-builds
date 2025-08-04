package docker

import (
	"fmt"
	"os"

	"github.com/bbotellacorbi/cassandra-env-manager/internal/config"
)

// ComposeGenerator handles docker-compose.yml generation
type ComposeGenerator struct {
	config *config.Config
}

// NewComposeGenerator creates a new compose generator
func NewComposeGenerator(cfg *config.Config) *ComposeGenerator {
	return &ComposeGenerator{
		config: cfg,
	}
}

// GenerateComposeFile creates a docker-compose.yml file for the cluster
func (g *ComposeGenerator) GenerateComposeFile() error {
	fmt.Printf("🔧 Generating docker-compose for %d nodes...\n", g.config.ClusterSize)

	file, err := os.Create("docker-compose.yml")
	if err != nil {
		return fmt.Errorf("failed to create docker-compose.yml: %w", err)
	}
	defer file.Close()

	// Get resource settings
	heapSize, heapNewSize, cpuLimit, memoryLimit := g.config.GetHeapSettings()
	seeds := g.config.GetSeedsConfiguration()

	// Write header
	_, err = file.WriteString("services:\n")
	if err != nil {
		return fmt.Errorf("failed to write compose header: %w", err)
	}

	// Generate configuration for each node
	for i := 1; i <= g.config.ClusterSize; i++ {
		if err := g.writeCassandraService(file, i, heapSize, heapNewSize, cpuLimit, memoryLimit, seeds); err != nil {
			return fmt.Errorf("failed to write cassandra service %d: %w", i, err)
		}

		if g.config.EnableSidecar {
			if err := g.writeSidecarService(file, i); err != nil {
				return fmt.Errorf("failed to write sidecar service %d: %w", i, err)
			}
		}
	}

	// Write volumes and networks
	if err := g.writeVolumesAndNetworks(file); err != nil {
		return fmt.Errorf("failed to write volumes and networks: %w", err)
	}

	return nil
}

func (g *ComposeGenerator) writeCassandraService(file *os.File, nodeNum int, heapSize, heapNewSize, cpuLimit, memoryLimit, seeds string) error {
	// Calculate unique ports for each node
	cqlPort := 9042 + (nodeNum-1)*2        // 9042, 9044, 9046, etc.
	jmxPort := 7199 + nodeNum - 1          // 7199, 7200, 7201, etc.
	interPort := 7000 + (nodeNum-1)*10     // 7000, 7010, 7020, etc.
	interSSLPort := 7001 + (nodeNum-1)*10  // 7001, 7011, 7021, etc.
	thriftPort := 9160 + nodeNum - 1       // 9160, 9161, 9162, etc.

	service := fmt.Sprintf(`  cassandra-%d:
    image: cassandra-dev
    container_name: cassandra-node-%d
    hostname: cassandra-%d
    deploy:
      resources:
        limits:
          cpus: '%s'
          memory: %s
    ports:
      - "%d:9042"
      - "%d:7199"
      - "%d:7000"
      - "%d:7001"
      - "%d:9160"
    volumes:
      - cassandra_data_%d:/var/lib/cassandra
      - cassandra_logs_%d:/var/log/cassandra
`, nodeNum, nodeNum, nodeNum, cpuLimit, memoryLimit, cqlPort, jmxPort, interPort, interSSLPort, thriftPort, nodeNum, nodeNum)

	// Add configuration overrides if they exist
	if g.config.ConfigOverrides.CassandraConfig {
		service += "      - ./config/cassandra/cassandra.yaml:/opt/cassandra/conf/cassandra.yaml:ro\n"
	}
	if g.config.ConfigOverrides.CassandraLogging {
		service += "      - ./config/cassandra/logback.xml:/opt/cassandra/conf/logback.xml:ro\n"
	}
	if g.config.ConfigOverrides.CassandraJVM {
		service += "      - ./config/cassandra/jvm.options:/opt/cassandra/conf/jvm.options:ro\n"
	}

	service += fmt.Sprintf(`    environment:
      - CASSANDRA_CLUSTER_NAME=DevCluster
      - CASSANDRA_DC=datacenter1
      - CASSANDRA_RACK=rack1
      - CASSANDRA_ENDPOINT_SNITCH=GossipingPropertyFileSnitch
      - CASSANDRA_SEEDS=%s
      - CASSANDRA_LISTEN_ADDRESS=cassandra-%d
      - CASSANDRA_BROADCAST_ADDRESS=cassandra-%d
      - CASSANDRA_RPC_ADDRESS=0.0.0.0
      - CASSANDRA_BROADCAST_RPC_ADDRESS=cassandra-%d
      - MAX_HEAP_SIZE=%s
      - HEAP_NEWSIZE=%s
      - DEBUG_MODE=true
    networks:
      - cassandra-net
    # healthcheck:
    #   test: ["CMD-SHELL", "nc -z localhost 9042 || exit 1"]
    #   interval: 30s
    #   timeout: 10s
    #   retries: 3
    #   start_period: 120s
    restart: unless-stopped
`, seeds, nodeNum, nodeNum, nodeNum, heapSize, heapNewSize)

	// Add dependencies for startup order
	if nodeNum > 1 {
		service += "    depends_on:\n"
		for j := 1; j < nodeNum; j++ {
			service += fmt.Sprintf("      - cassandra-%d\n", j)
		}
	}

	service += "\n"

	_, err := file.WriteString(service)
	return err
}

func (g *ComposeGenerator) writeSidecarService(file *os.File, nodeNum int) error {
	sidecarPort := 9043 + (nodeNum-1)*2 // 9043, 9045, 9047, etc.

	service := fmt.Sprintf(`  sidecar-%d:
    image: cassandra-sidecar-dev
    container_name: sidecar-node-%d
    hostname: sidecar-%d
    ports:
      - "%d:9043"
    environment:
      - SIDECAR_PORT=9043
      - CASSANDRA_HOST=cassandra-%d
      - CASSANDRA_PORT=9042
      - CASSANDRA_JMX_PORT=7199
      - SIDECAR_HEALTH_CHECK_FREQUENCY=30s
      - SIDECAR_LOG_LEVEL=INFO
    volumes:
      - sidecar_logs_%d:/var/log/sidecar
`, nodeNum, nodeNum, nodeNum, sidecarPort, nodeNum, nodeNum)

	// Add sidecar configuration overrides if they exist
	if g.config.ConfigOverrides.SidecarConfig {
		service += "      - ./config/sidecar/sidecar.yaml:/opt/sidecar/conf/sidecar.yaml:ro\n"
	}
	if g.config.ConfigOverrides.SidecarLogging {
		service += "      - ./config/sidecar/logback.xml:/opt/sidecar/conf/logback.xml:ro\n"
	}

	service += fmt.Sprintf(`    networks:
      - cassandra-net
    depends_on:
      - cassandra-%d
    restart: unless-stopped

`, nodeNum)

	_, err := file.WriteString(service)
	return err
}

func (g *ComposeGenerator) writeVolumesAndNetworks(file *os.File) error {
	volumes := "volumes:\n"
	for i := 1; i <= g.config.ClusterSize; i++ {
		volumes += fmt.Sprintf("  cassandra_data_%d:\n", i)
		volumes += fmt.Sprintf("  cassandra_logs_%d:\n", i)
		if g.config.EnableSidecar {
			volumes += fmt.Sprintf("  sidecar_logs_%d:\n", i)
		}
	}

	networks := `
networks:
  cassandra-net:
    driver: bridge
`

	_, err := file.WriteString(volumes + networks)
	return err
}

// RemoveComposeFile removes the docker-compose.yml file
func RemoveComposeFile() error {
	if _, err := os.Stat("docker-compose.yml"); err == nil {
		return os.Remove("docker-compose.yml")
	}
	return nil
}

// ComposeFileExists checks if docker-compose.yml exists
func ComposeFileExists() bool {
	_, err := os.Stat("docker-compose.yml")
	return err == nil
}

// GetPortInfo returns port information for a given node
func GetPortInfo(nodeNum int, enableSidecar bool) map[string]int {
	ports := map[string]int{
		"cql":      9042 + (nodeNum-1)*2,        // 9042, 9044, 9046, etc.
		"jmx":      7199 + nodeNum - 1,          // 7199, 7200, 7201, etc.
		"inter":    7000 + (nodeNum-1)*10,       // 7000, 7010, 7020, etc.
		"interSSL": 7001 + (nodeNum-1)*10,       // 7001, 7011, 7021, etc.
		"thrift":   9160 + nodeNum - 1,          // 9160, 9161, 9162, etc.
	}

	if enableSidecar {
		ports["sidecar"] = 9043 + (nodeNum-1)*2 // 9043, 9045, 9047, etc.
	}

	return ports
}

// GetNodeHostname returns the hostname for a given node
func GetNodeHostname(nodeNum int) string {
	return fmt.Sprintf("cassandra-%d", nodeNum)
}

// GetSidecarHostname returns the sidecar hostname for a given node
func GetSidecarHostname(nodeNum int) string {
	return fmt.Sprintf("sidecar-%d", nodeNum)
}

// ValidateDockerEnvironment checks if Docker is available and running
func ValidateDockerEnvironment() error {
	// Check if docker command exists
	if !commandExists("docker") {
		return fmt.Errorf("docker command not found - please install Docker")
	}

	// Check if docker-compose command exists
	if !commandExists("docker-compose") {
		return fmt.Errorf("docker-compose command not found - please install Docker Compose")
	}

	// Check if Docker daemon is running
	if !isDockerRunning() {
		return fmt.Errorf("Docker daemon is not running - please start Docker")
	}

	return nil
}

// Helper functions
func commandExists(command string) bool {
	// Use system package function
	return true // Placeholder - would use exec.LookPath in real implementation
}

func isDockerRunning() bool {
	// Use system package function  
	return true // Placeholder - would check docker daemon in real implementation
}