package main

import (
	"cassandra-dev-env/internal/system"
	"fmt"
	"os"

	"cassandra-dev-env/internal/cassandra"
	"cassandra-dev-env/internal/config"
	"cassandra-dev-env/internal/docker"
	"cassandra-dev-env/internal/sidecar"

	"github.com/spf13/cobra"
)

var version = "1.0.0"

func main() {
	if err := newRootCommand().Execute(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

func newRootCommand() *cobra.Command {
	cfg := config.NewConfig()

	rootCmd := &cobra.Command{
		Use:   "cassandra-env-manager",
		Short: "🚀 Cassandra Development Environment Manager",
		Long: `Cassandra Development Environment Manager
=============================================

A comprehensive Apache Cassandra development environment management tool 
using Docker Compose, built from the latest source code. The environment 
supports multi-node clusters, Cassandra Sidecar integration, and complete 
lifecycle management.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runMain(cfg)
		},
	}

	// Environment Management flags
	rootCmd.PersistentFlags().BoolVar(&cfg.StatusOnly, "status", false, "Show environment status and cluster info")
	rootCmd.PersistentFlags().BoolVar(&cfg.StopOnly, "stop", false, "Stop running environment")
	rootCmd.PersistentFlags().BoolVar(&cfg.Teardown, "teardown", false, "Completely tear down environment and clean up")
	rootCmd.PersistentFlags().StringVar(&cfg.LogsService, "logs", "", "Show logs for specific service (or list services)")

	// Build and Deploy flags
	rootCmd.PersistentFlags().BoolVarP(&cfg.CleanBuild, "clean", "c", false, "Clean rebuild (remove cassandra directory first)")
	rootCmd.PersistentFlags().BoolVarP(&cfg.BuildOnly, "build", "b", false, "Only build, don't start services")
	rootCmd.PersistentFlags().BoolVarP(&cfg.StartOnly, "start-only", "s", false, "Only start services (assumes already built)")
	rootCmd.PersistentFlags().BoolVar(&cfg.NoAutoTeardown, "no-auto-teardown", false, "Skip automatic cleanup before setup (not recommended)")

	// Code Source flags
	rootCmd.PersistentFlags().StringVar(&cfg.Branch, "branch", "trunk", "Use specific branch")
	rootCmd.PersistentFlags().StringVar(&cfg.Commit, "commit", "", "Use specific commit hash")
	rootCmd.PersistentFlags().StringVar(&cfg.PR, "pr", "", "Use specific pull request number")
	rootCmd.PersistentFlags().StringVar(&cfg.LocalCassandraPath, "local-cassandra", "", "Use local Cassandra repository path")

	// Cluster flags
	rootCmd.PersistentFlags().IntVar(&cfg.ClusterSize, "nodes", 3, "Number of Cassandra nodes in cluster")

	// Sidecar flags
	rootCmd.PersistentFlags().BoolVar(&cfg.EnableSidecar, "sidecar", false, "Enable Cassandra Sidecar deployment")
	rootCmd.PersistentFlags().StringVar(&cfg.SidecarBranch, "sidecar-branch", "trunk", "Use specific sidecar branch")
	rootCmd.PersistentFlags().StringVar(&cfg.SidecarCommit, "sidecar-commit", "", "Use specific sidecar commit hash")
	rootCmd.PersistentFlags().StringVar(&cfg.SidecarPR, "sidecar-pr", "", "Use specific sidecar pull request number")
	rootCmd.PersistentFlags().StringVar(&cfg.LocalSidecarPath, "local-sidecar", "", "Use local Sidecar repository path")

	// SSL settings
	rootCmd.PersistentFlags().BoolVar(&cfg.EnableSsl, "enable-ssl", false, "Enable SSL for Cassandra")
	rootCmd.PersistentFlags().StringVar(&cfg.ClientAuthMode, "client-auth-mode", "NONE", "Enable client authentication (NONE, REQUEST, REQUIRED)")
	// Add subcommands
	rootCmd.AddCommand(newVersionCommand())

	return rootCmd
}

func newVersionCommand() *cobra.Command {
	return &cobra.Command{
		Use:   "version",
		Short: "Print version information",
		Run: func(cmd *cobra.Command, args []string) {
			fmt.Printf("cassandra-env-manager version %s\n", version)
		},
	}
}

func runMain(cfg config.Config) error {
	fmt.Println("🚀 Cassandra Development Environment Manager")
	fmt.Println("=============================================")

	// Validate configuration
	if err := cfg.Validate(); err != nil {
		return fmt.Errorf("configuration validation failed: %w", err)
	}

	// Route to appropriate handler based on flags
	switch {
	case cfg.StatusOnly:
		return handleStatus(cfg)
	case cfg.StopOnly:
		return handleStop(cfg)
	case cfg.StartOnly:
		return handleStart(cfg)
	case cfg.Teardown:
		return handleTeardown(cfg)
	case cfg.LogsService != "":
		return handleLogs(cfg)
	case cfg.BuildOnly:
		return handleBuildOnly(cfg)
	default:
		return handleFullSetup(cfg)
	}
}

func handleStatus(cfg config.Config) error {
	dockerOps := docker.NewOperations(&cfg)
	return dockerOps.ShowStatus()
}

func handleStop(cfg config.Config) error {
	dockerOps := docker.NewOperations(&cfg)
	return dockerOps.StopServices()
}

func handleStart(cfg config.Config) error {
	// For start-only, determine current code source from existing directories
	cfg.DetermineCodeSource()

	dockerOps := docker.NewOperations(&cfg)
	if err := dockerOps.StartExistingServices(); err != nil {
		return err
	}

	return showClusterInfo(cfg)
}

func handleTeardown(cfg config.Config) error {
	dockerOps := docker.NewOperations(&cfg)
	return dockerOps.TeardownEnvironment(false)
}

func handleLogs(cfg config.Config) error {
	dockerOps := docker.NewOperations(&cfg)
	return dockerOps.ShowLogs(cfg.LogsService)
}

func handleBuildOnly(cfg config.Config) error {
	// Auto-teardown before setting up if requested
	if !cfg.NoAutoTeardown {
		dockerOps := docker.NewOperations(&cfg)
		if err := dockerOps.AutoTeardown(); err != nil {
			return fmt.Errorf("auto-teardown failed: %w", err)
		}
	}

	// Build Cassandra
	cassandraBuilder := cassandra.NewBuilder(&cfg)
	if err := cassandraBuilder.Build(); err != nil {
		return fmt.Errorf("Cassandra build failed: %w", err)
	}

	// Build Sidecar if enabled
	if cfg.EnableSidecar {
		sidecarBuilder := sidecar.NewBuilder(&cfg)
		if err := sidecarBuilder.Build(); err != nil {
			return fmt.Errorf("Sidecar build failed: %w", err)
		}
	}

	// Check configuration overrides
	if err := cfg.CheckConfigOverrides(); err != nil {
		return fmt.Errorf("configuration override check failed: %w", err)
	}

	// optionally build SSL certificates
	if cfg.EnableSsl {
		env := []string{
			"ENABLE_SSL=true",
			fmt.Sprintf("SSL_CLIENT_AUTH=%s", cfg.ClientAuthMode),
		}
		var cmdResult = system.ExecuteCommand("./generate-ssl-certs.sh", []string{},
			&system.CommandOptions{
				Env: env,
			})
		if cmdResult.ExitCode != 0 {
			return fmt.Errorf("failed to generate ssl certificates: %w", cmdResult)
		}
	}

	// Generate docker-compose file
	composeGen := docker.NewComposeGenerator(&cfg)
	if err := composeGen.GenerateComposeFile(); err != nil {
		return fmt.Errorf("docker-compose generation failed: %w", err)
	}

	// Build Docker images
	dockerOps := docker.NewOperations(&cfg)
	if err := dockerOps.BuildImages(); err != nil {
		return fmt.Errorf("Docker image build failed: %w", err)
	} else {
		return err
	}
}

func handleFullSetup(cfg config.Config) error {
	if err := handleBuildOnly(cfg); err != nil {
		return fmt.Errorf("Docker image build failed: %w", err)
	}
	dockerOps := docker.NewOperations(&cfg)
	// Start services
	if err := dockerOps.StartServices(); err != nil {
		return fmt.Errorf("service startup failed: %w", err)
	}

	return showClusterInfo(cfg)
}

func showClusterInfo(cfg config.Config) error {
	if !docker.ComposeFileExists() {
		return nil
	}

	fmt.Println("")
	fmt.Println("🎉 Cassandra cluster is running!")
	fmt.Printf("   - Cluster Name: DevCluster\n")
	fmt.Printf("   - Nodes: %d\n", cfg.ClusterSize)
	if cfg.EnableSidecar {
		fmt.Println("   - Sidecar: Enabled")
	}

	fmt.Println("")
	fmt.Println("📋 Node access:")
	for i := 1; i <= cfg.ClusterSize; i++ {
		ports := docker.GetPortInfo(i, cfg.EnableSidecar)
		if cfg.EnableSidecar {
			fmt.Printf("   Node %d: CQL port %d, JMX port %d, Sidecar port %d\n", i, ports["cql"], ports["jmx"], ports["sidecar"])
		} else {
			fmt.Printf("   Node %d: CQL port %d, JMX port %d\n", i, ports["cql"], ports["jmx"])
		}
	}

	fmt.Println("")
	fmt.Println("📋 Useful commands:")
	fmt.Println("   Connect to Node 1: COMPOSE_BAKE=false docker-compose exec cassandra-1 cqlsh -u cassandra -p cassandra")
	fmt.Println("   Check status:      cassandra-env-manager --status")
	fmt.Println("   View logs:         cassandra-env-manager --logs cassandra-1")
	fmt.Println("   Stop cluster:      cassandra-env-manager --stop")
	fmt.Println("   Teardown:          cassandra-env-manager --teardown")
	if cfg.EnableSidecar {
		fmt.Println("   Sidecar API:       curl http://localhost:9043/health")
	}

	return nil
}
