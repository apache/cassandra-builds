package docker

import (
	"fmt"
	"regexp"
	"strconv"
	"strings"
	"time"

	"cassandra-dev-env/internal/config"
	"cassandra-dev-env/internal/system"
)

// Operations handles Docker operations
type Operations struct {
	config *config.Config
}

// NewOperations creates a new Docker operations handler
func NewOperations(cfg *config.Config) *Operations {
	return &Operations{
		config: cfg,
	}
}

// BuildImages builds the Docker images for Cassandra and Sidecar
func (ops *Operations) BuildImages() error {
	fmt.Println("🐳 Step 2: Building Docker images...")

	// Build unified Cassandra image (includes Sidecar when enabled)
	fmt.Println("🐳 Building unified Cassandra Docker image...")
	if ops.config.EnableSidecar {
		fmt.Println("   - Including Cassandra Sidecar in unified container")
	}
	result := system.DockerCommand([]string{"build", "-t", "cassandra-dev", "."}, nil)
	if result.ExitCode != 0 {
		return fmt.Errorf("failed to build Cassandra Docker image: %s", result.Stderr)
	}

	fmt.Println("✅ Docker images built!")
	return nil
}

// StartServices starts all services using docker-compose
func (ops *Operations) StartServices() error {
	fmt.Printf("🚀 Step 3: Starting %d node(s)...\n", ops.config.ClusterSize)

	// Start services
	result := system.DockerComposeCommand([]string{"up", "-d"}, nil)
	if result.ExitCode != 0 {
		return fmt.Errorf("failed to start services: %s", result.Stderr)
	}

	fmt.Println("⏳ Waiting for Cassandra cluster to be ready...")
	fmt.Println("   This may take a few minutes for multi-node clusters...")

	// Initial wait time based on cluster size
	waitTime := time.Duration(60+ops.config.ClusterSize*30) * time.Second
	time.Sleep(waitTime)

	fmt.Println("🔍 Checking cluster status...")
	return ops.WaitForClusterReady()
}

// StopServices stops all services
func (ops *Operations) StopServices() error {
	fmt.Println("🛑 Stopping Cassandra development environment...")

	if !ComposeFileExists() {
		return fmt.Errorf("no docker-compose.yml found. Environment may not be running")
	}

	result := system.DockerComposeCommand([]string{"stop"}, nil)
	if result.ExitCode != 0 {
		return fmt.Errorf("failed to stop services: %s", result.Stderr)
	}

	fmt.Println("✅ Environment stopped successfully!")
	fmt.Println("💡 Use --start to restart the environment")
	return nil
}

// StartExistingServices starts previously stopped services
func (ops *Operations) StartExistingServices() error {
	fmt.Println("🚀 Starting Cassandra development environment...")

	if !ComposeFileExists() {
		return fmt.Errorf("no docker-compose.yml found. Please run a full setup first")
	}

	result := system.DockerComposeCommand([]string{"start"}, nil)
	if result.ExitCode != 0 {
		return fmt.Errorf("failed to start services: %s", result.Stderr)
	}

	fmt.Println("✅ Environment started successfully!")
	return nil
}

// TeardownEnvironment completely removes all containers, images, and volumes
func (ops *Operations) TeardownEnvironment(silent bool) error {
	if silent {
		fmt.Println("🧹 Cleaning up existing environment...")
	} else {
		fmt.Println("🧹 Tearing down Cassandra development environment...")
	}

	// Stop and remove containers if compose file exists
	if ComposeFileExists() {
		if silent {
			fmt.Println("   🛑 Stopping and removing existing containers...")
		} else {
			fmt.Println("   🛑 Stopping and removing containers...")
		}

		result := system.DockerComposeCommand([]string{"--project-name", ops.config.ProjectName, "down", "-v", "--remove-orphans"}, &system.CommandOptions{Silent: true})
		if result.ExitCode != 0 && !silent {
			fmt.Printf("   ⚠️  Warning: docker-compose down failed: %s\n", result.Stderr)
		}
	}

	// Remove Docker images
	if !silent {
		fmt.Println("   🗑️  Removing Docker images...")
	}
	system.DockerCommand([]string{"rmi", "-f", "cassandra-dev"}, &system.CommandOptions{Silent: true})
	system.DockerCommand([]string{"rmi", "cassandra-sidecar-dev"}, &system.CommandOptions{Silent: true})

	// Clean up unused volumes and networks
	if !silent {
		fmt.Println("   🧽 Cleaning up unused Docker resources...")
	}
	system.DockerCommand([]string{"volume", "prune", "-f"}, &system.CommandOptions{Silent: true})
	system.DockerCommand([]string{"network", "prune", "-f"}, &system.CommandOptions{Silent: true})

	// Remove containers by name pattern
	if silent {
		fmt.Println("   🛑 Cleaning up any existing containers...")
	} else {
		fmt.Println("   ⚠️  Cleaning up containers by name...")
	}

	// Get and remove cassandra containers
	if containerIDs, err := system.GetDockerContainerIDs("name=cassandra-node"); err == nil {
		if len(containerIDs) > 0 {
			args := append([]string{"rm", "-f"}, containerIDs...)
			system.DockerCommand(args, &system.CommandOptions{Silent: true})
		}
	}

	// Get and remove sidecar containers
	if containerIDs, err := system.GetDockerContainerIDs("name=sidecar-node"); err == nil {
		if len(containerIDs) > 0 {
			args := append([]string{"rm", "-f"}, containerIDs...)
			system.DockerCommand(args, &system.CommandOptions{Silent: true})
		}
	}

	// Clean up dead containers
	if containerIDs, err := system.GetDockerContainerIDs("status=dead"); err == nil {
		if len(containerIDs) > 0 {
			args := append([]string{"rm", "-f"}, containerIDs...)
			system.DockerCommand(args, &system.CommandOptions{Silent: true})
		}
	}

	// Clean up Docker cache
	if silent {
		fmt.Println("   🧽 Clearing Docker Compose cache...")
	} else {
		fmt.Println("   🧽 Clearing Docker Compose cache and state files...")
	}

	// Clean up project-specific volumes
	result := system.DockerCommand([]string{"volume", "ls", "-q", "--filter", "name=cassandra-env"}, &system.CommandOptions{Silent: true})
	if result.ExitCode == 0 && strings.TrimSpace(result.Stdout) != "" {
		volumes := strings.Split(strings.TrimSpace(result.Stdout), "\n")
		args := append([]string{"volume", "rm"}, volumes...)
		system.DockerCommand(args, &system.CommandOptions{Silent: true})
	}

	result = system.DockerCommand([]string{"volume", "ls", "-q", "--filter", "name=cassandra"}, &system.CommandOptions{Silent: true})
	if result.ExitCode == 0 && strings.TrimSpace(result.Stdout) != "" {
		volumes := strings.Split(strings.TrimSpace(result.Stdout), "\n")
		args := append([]string{"volume", "rm"}, volumes...)
		system.DockerCommand(args, &system.CommandOptions{Silent: true})
	}

	// System cleanup
	//system.DockerCommand([]string{"system", "prune", "-a", "-f", "--volumes"}, &system.CommandOptions{Silent: true})

	// Remove compose file
	if ComposeFileExists() {
		if !silent {
			fmt.Println("   📄 Removing generated docker-compose.yml...")
		}
		RemoveComposeFile()
	}

	if silent {
		fmt.Println("   ✅ Environment cleaned up successfully!")
	} else {
		fmt.Println("✅ Environment teardown completed!")
	}

	return nil
}

// WaitForClusterReady waits for the cluster to be fully ready
func (ops *Operations) WaitForClusterReady() error {
	maxChecks := 12 // 12 attempts = 2 minutes
	attempt := 1
	clusterReady := false

	fmt.Println("⏳ Waiting for cluster to be fully initialized...")

	for attempt <= maxChecks && !clusterReady {
		// Use CQL to check cluster membership - more reliable than nodetool with auth
		// Check system.peers for other nodes, plus local node = total cluster size
		result := system.DockerComposeCommand([]string{"exec", "-T", "cassandra-1", "cqlsh", "localhost", "-u", "cassandra", "-p", "cassandra_test_env_password",
			"-e", "SELECT COUNT(*) FROM system.peers"}, &system.CommandOptions{Silent: true})

		if result.ExitCode == 0 {
			// Parse peer count from CQL output
			lines := strings.Split(strings.TrimSpace(result.Stdout), "\n")
			var peerCount int
			for _, line := range lines {
				line = strings.TrimSpace(line)
				// Look for numeric result (skip headers and separators)
				if matched, _ := regexp.MatchString(`^\d+$`, line); matched {
					if count, err := strconv.Atoi(line); err == nil {
						peerCount = count
						break
					}
				}
			}

			// Total cluster size = peer count + local node
			totalNodes := peerCount + 1

			if totalNodes == ops.config.ClusterSize {
				clusterReady = true
				fmt.Printf("✅ Cluster is ready! All %d nodes are connected\n", ops.config.ClusterSize)
			} else {
				fmt.Printf("⏳ Cluster still initializing (attempt %d/%d): %d/%d nodes connected\n", attempt, maxChecks, totalNodes, ops.config.ClusterSize)
			}
		} else {
			// Fallback: try to connect to CQL without checking peers
			// TODO: Generate a GUID for the password so it's not embedded in source, and display it for the user each time we start up the cluster?
			pingResult := system.DockerComposeCommand([]string{"exec", "-T", "cassandra-1", "cqlsh", "localhost", "-e", "-u", "cassandra", "-p", "cassandra_test_env_password",
				"SELECT release_version FROM system.local"}, &system.CommandOptions{Silent: true})
			if pingResult.ExitCode == 0 {
				fmt.Printf("⏳ Cluster still initializing (attempt %d/%d): CQL ready, waiting for gossip\n", attempt, maxChecks)
			} else {
				fmt.Printf("⏳ Cluster still initializing (attempt %d/%d): CQL not ready\n", attempt, maxChecks)
			}
		}

		if !clusterReady {
			time.Sleep(10 * time.Second)
			attempt++
		}
	}

	if clusterReady {
		fmt.Println("")
		fmt.Printf("🎉 Cassandra %d-node cluster is running!\n", ops.config.ClusterSize)
		fmt.Printf("   - Code Source: %s\n", ops.config.CodeSource)
		if ops.config.EnableSidecar {
			fmt.Printf("   - Sidecar Source: %s\n", ops.config.SidecarCodeSource)
		}
		return nil
	}

	fmt.Println("⚠️  Cluster is starting but not fully ready yet. This is normal for multi-node clusters.")
	fmt.Println("   You can check the status later with: --status")
	fmt.Println("   Or check logs with: --logs cassandra-1")
	return nil
}

// ShowStatus displays the current environment status
func (ops *Operations) ShowStatus() error {
	fmt.Println("📊 Cassandra Development Environment Status")
	fmt.Println("============================================")

	if !ComposeFileExists() {
		fmt.Println("❌ No docker-compose.yml found - environment not set up")
		return nil
	}

	fmt.Println("📄 Configuration: docker-compose.yml exists")

	// Show container status
	fmt.Println("")
	fmt.Println("🐳 Container Status:")
	result := system.DockerComposeCommand([]string{"ps"}, nil)
	if result.ExitCode != 0 {
		fmt.Printf("   Error getting container status: %s\n", result.Stderr)
	}

	// Show resource usage
	fmt.Println("")
	fmt.Println("📈 Resource Usage:")
	containerIDs, err := system.GetDockerContainerIDs("name=cassandra-node")
	if err == nil {
		sidecarIDs, _ := system.GetDockerContainerIDs("name=sidecar-node")
		allIDs := append(containerIDs, sidecarIDs...)

		if len(allIDs) > 0 {
			args := append([]string{"stats", "--no-stream", "--format", "table {{.Container}}\\t{{.CPUPerc}}\\t{{.MemUsage}}\\t{{.NetIO}}"}, allIDs...)
			result := system.DockerCommand(args, nil)
			if result.ExitCode != 0 {
				fmt.Println("   No containers running")
			}
		} else {
			fmt.Println("   No containers running")
		}
	}

	// Show volumes
	fmt.Println("")
	fmt.Println("💾 Volumes:")
	result = system.DockerCommand([]string{"volume", "ls", "--filter=name=cassandra", "--filter=name=sidecar", "--format", "table {{.Name}}\\t{{.Driver}}"}, nil)
	if result.ExitCode != 0 {
		fmt.Printf("   Error getting volumes: %s\n", result.Stderr)
	}

	// Show cluster status
	fmt.Println("")
	fmt.Println("🔍 Cluster Status:")
	containerIDs, err = system.GetDockerContainerIDs("name=cassandra-node-1")
	if err == nil && len(containerIDs) > 0 {
		// Use CQL to check cluster membership - consistent with WaitForClusterReady
		result = system.DockerComposeCommand([]string{"exec", "-T", "cassandra-1", "cqlsh", "localhost", "-e", "SELECT COUNT(*) FROM system.peers"}, &system.CommandOptions{Silent: true})

		if result.ExitCode == 0 {
			// Parse peer count from CQL output
			lines := strings.Split(strings.TrimSpace(result.Stdout), "\n")
			var peerCount int
			for _, line := range lines {
				line = strings.TrimSpace(line)
				if matched, _ := regexp.MatchString(`^\d+$`, line); matched {
					if count, err := strconv.Atoi(line); err == nil {
						peerCount = count
						break
					}
				}
			}

			totalNodes := peerCount + 1 // peer count + local node
			fmt.Printf("   Connected nodes: %d\n", totalNodes)

			// Also show local and peer info for debugging
			localResult := system.DockerComposeCommand([]string{"exec", "-T", "cassandra-1", "cqlsh", "localhost", "-e", "SELECT listen_address, rpc_address, release_version FROM system.local"}, &system.CommandOptions{Silent: true})
			if localResult.ExitCode == 0 {
				fmt.Println("   Local node:")
				fmt.Print("   " + localResult.Stdout)
			}

			if peerCount > 0 {
				peerResult := system.DockerComposeCommand([]string{"exec", "-T", "cassandra-1", "cqlsh", "localhost", "-e", "SELECT peer, rpc_address, release_version FROM system.peers"}, &system.CommandOptions{Silent: true})
				if peerResult.ExitCode == 0 {
					fmt.Println("   Peer nodes:")
					fmt.Print("   " + peerResult.Stdout)
				}
			}
		} else {
			fmt.Println("   Cluster not ready yet or still starting")
		}
	} else {
		fmt.Println("   Cassandra containers not running")
	}

	return nil
}

// ShowLogs displays logs for a specific service
func (ops *Operations) ShowLogs(service string) error {
	if !ComposeFileExists() {
		return fmt.Errorf("no docker-compose.yml found - environment not set up")
	}

	if service == "" {
		fmt.Println("Available services:")
		result := system.DockerComposeCommand([]string{"ps", "--services"}, nil)
		if result.ExitCode != 0 {
			return fmt.Errorf("failed to get services: %s", result.Stderr)
		}
		fmt.Println("")
		fmt.Println("Use --logs SERVICE_NAME to view specific service logs")
		return nil
	}

	fmt.Printf("📋 Viewing logs for %s...\n", service)
	return system.ExecuteCommandStreaming("docker-compose", []string{"logs", "-f", service}, &system.CommandOptions{
		Env: []string{"COMPOSE_BAKE=false"},
	})
}

// AutoTeardown performs automatic cleanup if there's an existing environment
func (ops *Operations) AutoTeardown() error {
	// Check if there's an existing environment
	hasCompose := ComposeFileExists()

	// Check for existing containers
	containerIDs, _ := system.GetDockerContainerIDs("name=cassandra-node")
	sidecarIDs, _ := system.GetDockerContainerIDs("name=sidecar-node")
	hasContainers := len(containerIDs) > 0 || len(sidecarIDs) > 0

	if hasCompose || hasContainers {
		return ops.TeardownEnvironment(true)
	}

	return nil
}
