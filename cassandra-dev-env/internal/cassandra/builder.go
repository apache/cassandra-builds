package cassandra

import (
	"fmt"
	"path/filepath"

	"cassandra-dev-env/internal/config"
	"cassandra-dev-env/internal/git"
	"cassandra-dev-env/internal/system"
)

// Builder handles Cassandra compilation
type Builder struct {
	config *config.Config
	git    *git.Repository
}

// NewBuilder creates a new Cassandra builder
func NewBuilder(cfg *config.Config) *Builder {
	return &Builder{
		config: cfg,
		git:    git.NewRepository(cfg),
	}
}

// Build compiles Cassandra from source
func (b *Builder) Build() error {
	fmt.Println("📦 Step 1: Building Cassandra locally...")

	// Clone the repository
	if err := b.git.CloneCassandraRepository(); err != nil {
		return fmt.Errorf("failed to clone Cassandra repository: %w", err)
	}

	// Build Cassandra
	return b.buildCassandra()
}

// buildCassandra compiles Cassandra using Ant
func (b *Builder) buildCassandra() error {
	fmt.Println("🔨 Building Cassandra with Ant...")

	// Check if Ant is available
	if !system.CheckCommandExists("ant") {
		return fmt.Errorf("ant command not found - please install Apache Ant")
	}

	// Check if Java is available
	if !system.CheckCommandExists("java") {
		return fmt.Errorf("java command not found - please install Java 11 or later")
	}

	// Build using Ant
	result := system.AntCommand([]string{"jar", "-Duse.jdk11=true"}, &system.CommandOptions{
		WorkingDir: "cassandra",
	})

	if result.ExitCode != 0 {
		return fmt.Errorf("Cassandra build failed: %s", result.Stderr)
	}

	fmt.Println("✅ Cassandra build completed!")
	
	// Set code source information
	b.config.DetermineCodeSource()
	fmt.Printf("📍 Built from: %s\n", b.config.CodeSource)

	return nil
}

// ValidateBuild checks if the Cassandra build is valid
func (b *Builder) ValidateBuild() error {
	cassandraDir := "cassandra"
	
	if !config.FileOrDirExists(cassandraDir) {
		return fmt.Errorf("cassandra directory does not exist")
	}

	// Check for essential build artifacts
	buildDir := filepath.Join(cassandraDir, "build")
	if !config.FileOrDirExists(buildDir) {
		return fmt.Errorf("build directory does not exist - build may have failed")
	}

	// Check for jar files
	classesDir := filepath.Join(buildDir, "classes")
	if !config.FileOrDirExists(classesDir) {
		return fmt.Errorf("build classes directory does not exist - build may have failed")
	}

	return nil
}

// GetBuildInfo returns information about the current Cassandra build
func (b *Builder) GetBuildInfo() (map[string]string, error) {
	info := make(map[string]string)

	if !config.FileOrDirExists("cassandra") {
		return info, fmt.Errorf("cassandra directory not found")
	}

	// Get git information
	branch, commit, err := git.GetCurrentInfo("cassandra")
	if err == nil {
		info["branch"] = branch
		info["commit"] = commit
	}

	// Get build timestamp (if available)
	buildFile := filepath.Join("cassandra", "build.xml")
	if config.FileOrDirExists(buildFile) {
		info["build_file"] = "present"
	}

	// Get version information from build.xml or other sources
	// This would require parsing the build file
	info["source"] = b.config.CodeSource

	return info, nil
}

// CleanBuild removes build artifacts
func (b *Builder) CleanBuild() error {
	fmt.Println("🧹 Cleaning previous Cassandra build...")

	if !config.FileOrDirExists("cassandra") {
		return nil // Nothing to clean
	}

	// Use Ant clean if available
	if system.CheckCommandExists("ant") {
		result := system.AntCommand([]string{"clean"}, &system.CommandOptions{
			WorkingDir: "cassandra",
			Silent:     true,
		})
		if result.ExitCode == 0 {
			return nil
		}
	}

	// Fallback: remove build directory manually
	buildDir := filepath.Join("cassandra", "build")
	if config.FileOrDirExists(buildDir) {
		return config.RemoveDirectory(buildDir)
	}

	return nil
}

// CheckBuildDependencies verifies that all required tools are available
func CheckBuildDependencies() error {
	required := []string{"java", "ant", "git"}
	
	var missing []string
	for _, cmd := range required {
		if !system.CheckCommandExists(cmd) {
			missing = append(missing, cmd)
		}
	}

	if len(missing) > 0 {
		return fmt.Errorf("missing required build dependencies: %v", missing)
	}

	// Check Java version
	result := system.ExecuteCommand("java", []string{"-version"}, &system.CommandOptions{Silent: true})
	if result.ExitCode != 0 {
		return fmt.Errorf("failed to get Java version")
	}

	// Basic check for Java 11+
	// This is a simplified check - a more robust implementation would parse the version
	if result.Stderr == "" && result.Stdout == "" {
		fmt.Println("⚠️  Warning: Could not verify Java version")
	}

	return nil
}

// GetCassandraVersion attempts to determine the Cassandra version being built
func (b *Builder) GetCassandraVersion() (string, error) {
	if !config.FileOrDirExists("cassandra") {
		return "", fmt.Errorf("cassandra directory not found")
	}

	// Try to read version from build.xml
	buildXML := filepath.Join("cassandra", "build.xml")
	if !config.FileOrDirExists(buildXML) {
		return "", fmt.Errorf("build.xml not found")
	}

	// This would require XML parsing to extract the version
	// For now, return a placeholder
	return "development", nil
}

// SetupLocalBuild prepares for building from a local repository
func (b *Builder) SetupLocalBuild() error {
	if b.config.LocalCassandraPath == "" {
		return fmt.Errorf("no local Cassandra path configured")
	}

	// Validate that the local path exists and is a git repository
	if !config.FileOrDirExists(b.config.LocalCassandraPath) {
		return fmt.Errorf("local Cassandra path does not exist: %s", b.config.LocalCassandraPath)
	}

	if !git.ValidateGitRepository(b.config.LocalCassandraPath) {
		return fmt.Errorf("local Cassandra path is not a git repository: %s", b.config.LocalCassandraPath)
	}

	// Validate that it has the necessary build files
	buildXML := filepath.Join(b.config.LocalCassandraPath, "build.xml")
	if !config.FileOrDirExists(buildXML) {
		return fmt.Errorf("build.xml not found in local Cassandra repository")
	}

	return nil
}

// EstimateBuildTime provides an estimate of build time based on system
func EstimateBuildTime() string {
	// This is a rough estimate - actual time depends on many factors
	return "5-15 minutes depending on system performance"
}

// GetRecommendedJVMOptions returns recommended JVM options for building
func GetRecommendedJVMOptions() []string {
	return []string{
		"-Xmx2G",
		"-XX:+UseG1GC",
		"-Duse.jdk11=true",
	}
}