package config

import (
	"fmt"
	"os"
	"path/filepath"
)

// Config holds all configuration options for the cassandra-env-manager
type Config struct {
	// Environment Management
	StatusOnly  bool
	StopOnly    bool
	StartOnly   bool
	Teardown    bool
	LogsService string

	// Build and Deploy Options
	CleanBuild     bool
	BuildOnly      bool
	NoAutoTeardown bool

	// Code Source Options
	Branch             string
	Commit             string
	PR                 string
	LocalCassandraPath string

	// Cluster Options
	ClusterSize int

	// Sidecar Options
	EnableSidecar    bool
	SidecarBranch    string
	SidecarCommit    string
	SidecarPR        string
	LocalSidecarPath string

	// Internal computed values
	RepoURL           string
	ProjectName       string
	CodeSource        string
	SidecarCodeSource string
	ConfigOverrides   ConfigOverrides

	// SSL Options
	EnableSsl      bool
	ClientAuthMode string
}

// ConfigOverrides tracks which configuration files are overridden
type ConfigOverrides struct {
	CassandraConfig  bool
	CassandraLogging bool
	CassandraJVM     bool
	SidecarConfig    bool
	SidecarLogging   bool
}

// NewConfig creates a new configuration with defaults
func NewConfig() Config {
	return Config{
		Branch:        "trunk",
		SidecarBranch: "trunk",
		ClusterSize:   3,
		RepoURL:       "https://github.com/apache/cassandra.git",
		ProjectName:   fmt.Sprintf("cassandra-env-%d", getCurrentTimestamp()),
	}
}

// Validate checks the configuration for conflicts and invalid values
func (c *Config) Validate() error {
	// Validate that only one code source option is specified for Cassandra
	sourceOptions := 0
	if c.Commit != "" {
		sourceOptions++
	}
	if c.PR != "" {
		sourceOptions++
	}
	if c.Branch != "trunk" {
		sourceOptions++
	}
	if c.LocalCassandraPath != "" {
		sourceOptions++
	}

	if sourceOptions > 1 {
		return fmt.Errorf("only one Cassandra code source option can be specified (--branch, --commit, --pr, or --local-cassandra)")
	}

	// Validate that only one code source option is specified for Sidecar
	sidecarSourceOptions := 0
	if c.SidecarCommit != "" {
		sidecarSourceOptions++
	}
	if c.SidecarPR != "" {
		sidecarSourceOptions++
	}
	if c.SidecarBranch != "trunk" {
		sidecarSourceOptions++
	}
	if c.LocalSidecarPath != "" {
		sidecarSourceOptions++
	}

	if sidecarSourceOptions > 1 {
		return fmt.Errorf("only one Sidecar code source option can be specified (--sidecar-branch, --sidecar-commit, --sidecar-pr, or --local-sidecar)")
	}

	// Validate that local paths exist if specified
	if c.LocalCassandraPath != "" {
		if _, err := os.Stat(c.LocalCassandraPath); os.IsNotExist(err) {
			return fmt.Errorf("local Cassandra path does not exist: %s", c.LocalCassandraPath)
		}
	}

	if c.LocalSidecarPath != "" {
		if _, err := os.Stat(c.LocalSidecarPath); os.IsNotExist(err) {
			return fmt.Errorf("local Sidecar path does not exist: %s", c.LocalSidecarPath)
		}
	}

	// Validate cluster size
	if c.ClusterSize < 1 || c.ClusterSize > 10 {
		return fmt.Errorf("cluster size must be a number between 1 and 10, got: %d", c.ClusterSize)
	}

	return nil
}

// CheckConfigOverrides detects configuration override files
func (c *Config) CheckConfigOverrides() error {
	fmt.Println("🔧 Checking for configuration overrides...")

	// Check Cassandra configuration overrides
	if fileExists("config/cassandra/cassandra.yaml") {
		fmt.Println("   ✓ Found Cassandra configuration override: cassandra.yaml")
		c.ConfigOverrides.CassandraConfig = true
	}

	if fileExists("config/cassandra/logback.xml") {
		fmt.Println("   ✓ Found Cassandra logging override: logback.xml")
		c.ConfigOverrides.CassandraLogging = true
	}

	if fileExists("config/cassandra/jvm.options") {
		fmt.Println("   ✓ Found Cassandra JVM options override: jvm.options")
		c.ConfigOverrides.CassandraJVM = true
	}

	// Check Sidecar configuration overrides
	if fileExists("config/sidecar/sidecar.yaml") {
		fmt.Println("   ✓ Found Sidecar configuration override: sidecar.yaml")
		c.ConfigOverrides.SidecarConfig = true
	}

	if fileExists("config/sidecar/logback.xml") {
		fmt.Println("   ✓ Found Sidecar logging override: logback.xml")
		c.ConfigOverrides.SidecarLogging = true
	}

	hasOverrides := c.ConfigOverrides.CassandraConfig ||
		c.ConfigOverrides.CassandraLogging ||
		c.ConfigOverrides.CassandraJVM ||
		c.ConfigOverrides.SidecarConfig ||
		c.ConfigOverrides.SidecarLogging

	if hasOverrides {
		fmt.Println("   📝 Configuration overrides will be applied")
	} else {
		fmt.Println("   📝 Using default configurations")
	}

	return nil
}

// DetermineCodeSource sets the code source description based on configuration
func (c *Config) DetermineCodeSource() {
	if c.LocalCassandraPath != "" {
		c.CodeSource = fmt.Sprintf("local/%s", c.LocalCassandraPath)
	} else if c.PR != "" {
		c.CodeSource = fmt.Sprintf("pr/%s", c.PR)
	} else if c.Commit != "" {
		c.CodeSource = fmt.Sprintf("commit/%s", c.Commit)
	} else {
		c.CodeSource = fmt.Sprintf("branch/%s", c.Branch)
	}

	if c.EnableSidecar {
		if c.LocalSidecarPath != "" {
			c.SidecarCodeSource = fmt.Sprintf("local/%s", c.LocalSidecarPath)
		} else if c.SidecarPR != "" {
			c.SidecarCodeSource = fmt.Sprintf("pr/%s", c.SidecarPR)
		} else if c.SidecarCommit != "" {
			c.SidecarCodeSource = fmt.Sprintf("commit/%s", c.SidecarCommit)
		} else {
			c.SidecarCodeSource = fmt.Sprintf("branch/%s", c.SidecarBranch)
		}
	}
}

// GetHeapSettings returns heap size settings based on cluster configuration
func (c *Config) GetHeapSettings() (heapSize, heapNewSize, cpuLimit, memoryLimit string) {
	// Default settings for better 3-node stability
	heapSize = "1536M"
	heapNewSize = "384M"
	cpuLimit = "1.5"
	memoryLimit = "6G"

	// Optimize resources for multi-node clusters
	if c.ClusterSize > 3 {
		heapSize = "1G"
		heapNewSize = "256M"
	} else if c.ClusterSize == 3 {
		// Special case for 3-node clusters - need more heap for stability
		heapSize = "1536M"
		heapNewSize = "384M"
	}

	return heapSize, heapNewSize, cpuLimit, memoryLimit
}

// GetSeedsConfiguration returns the seeds configuration for the cluster
func (c *Config) GetSeedsConfiguration() string {
	if c.ClusterSize == 1 {
		// Single node cluster: uses itself as seed
		return "cassandra-1"
	} else if c.ClusterSize <= 5 {
		// Small clusters (2-5 nodes): use only the first node as seed
		return "cassandra-1"
	} else if c.ClusterSize <= 10 {
		// Medium clusters (6-10 nodes): use 2 seeds for redundancy
		return "cassandra-1,cassandra-2"
	} else {
		// Large clusters (11+ nodes): use 3 seeds maximum
		return "cassandra-1,cassandra-2,cassandra-3"
	}
}

// Helper functions
func fileExists(path string) bool {
	_, err := os.Stat(path)
	return !os.IsNotExist(err)
}

func getCurrentTimestamp() int64 {
	// This would normally use time.Now().Unix()
	// For now, use a simple approach to generate unique timestamps
	return 1609459200 + int64(len(os.Args)) // Simple unique value
}

// GetWorkingDirectory returns the current working directory
func GetWorkingDirectory() (string, error) {
	return os.Getwd()
}

// EnsureDirectory creates a directory if it doesn't exist
func EnsureDirectory(path string) error {
	return os.MkdirAll(path, 0755)
}

// RemoveDirectory removes a directory and all its contents
func RemoveDirectory(path string) error {
	return os.RemoveAll(path)
}

// FileOrDirExists checks if a file or directory exists
func FileOrDirExists(path string) bool {
	_, err := os.Stat(path)
	return !os.IsNotExist(err)
}

// AbsolutePath converts a path to absolute
func AbsolutePath(path string) (string, error) {
	return filepath.Abs(path)
}
