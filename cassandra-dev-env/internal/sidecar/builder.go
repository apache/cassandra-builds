package sidecar

import (
	"fmt"
	"path/filepath"

	"cassandra-dev-env/internal/config"
	"cassandra-dev-env/internal/git"
	"cassandra-dev-env/internal/system"
)

// Builder handles Cassandra Sidecar compilation
type Builder struct {
	config *config.Config
	git    *git.Repository
}

// NewBuilder creates a new Sidecar builder
func NewBuilder(cfg *config.Config) *Builder {
	return &Builder{
		config: cfg,
		git:    git.NewRepository(cfg),
	}
}

// Build compiles Cassandra Sidecar from source
func (b *Builder) Build() error {
	if !b.config.EnableSidecar {
		return nil // Sidecar not enabled, skip build
	}

	fmt.Println("📦 Building Cassandra Sidecar locally...")

	// Clone the repository
	if err := b.git.CloneSidecarRepository(); err != nil {
		return fmt.Errorf("failed to clone Sidecar repository: %w", err)
	}

	// Build Sidecar
	return b.buildSidecar()
}

// buildSidecar compiles Sidecar using Gradle
func (b *Builder) buildSidecar() error {
	fmt.Println("🔨 Building Sidecar with Gradle...")

	// Check if the gradlew script exists
	gradlewPath := filepath.Join("cassandra-sidecar", "gradlew")
	if !config.FileOrDirExists(gradlewPath) {
		return fmt.Errorf("gradlew script not found in cassandra-sidecar directory")
	}

	// Make gradlew executable
	result := system.ExecuteCommand("chmod", []string{"+x", "./gradlew"}, &system.CommandOptions{
		WorkingDir: "cassandra-sidecar",
		Silent:     true,
	})
	if result.ExitCode != 0 {
		fmt.Println("⚠️  Warning: Could not make gradlew executable")
	}

	// Execute build-dtest-jars.sh script before gradle build (required for trunk branch)
	dtestScript := filepath.Join("cassandra-sidecar", "scripts", "build-dtest-jars.sh")
	if config.FileOrDirExists(dtestScript) {
		fmt.Println("🔧 Running build-dtest-jars.sh script...")
		
		// Make the script executable
		result = system.ExecuteCommand("chmod", []string{"+x", "./scripts/build-dtest-jars.sh"}, &system.CommandOptions{
			WorkingDir: "cassandra-sidecar",
			Silent:     true,
		})
		if result.ExitCode != 0 {
			fmt.Println("⚠️  Warning: Could not make build-dtest-jars.sh executable")
		}

		// Execute the dtest jars build script
		result = system.ExecuteCommand("./scripts/build-dtest-jars.sh", []string{}, &system.CommandOptions{
			WorkingDir: "cassandra-sidecar",
		})
		
		if result.ExitCode != 0 {
			return fmt.Errorf("build-dtest-jars.sh script failed: %s", result.Stderr)
		}
		
		fmt.Println("✅ build-dtest-jars.sh completed successfully")
	} else {
		fmt.Println("ℹ️  build-dtest-jars.sh not found, skipping (may not be needed for this branch)")
	}

	// Build using Gradle (skip tests and integration tests like the original script)
	result = system.ExecuteCommand("./gradlew", []string{"build", "-x", "test", "-x", "integrationTest", "-x", "check"}, &system.CommandOptions{
		WorkingDir: "cassandra-sidecar",
		Env:        []string{"skipIntegrationTest=true"},
	})

	if result.ExitCode != 0 {
		return fmt.Errorf("Sidecar build failed: %s", result.Stderr)
	}

	fmt.Println("✅ Sidecar build completed!")
	
	// Set sidecar code source information
	b.config.DetermineCodeSource()
	fmt.Printf("📍 Sidecar built from: %s\n", b.config.SidecarCodeSource)

	return nil
}

// ValidateBuild checks if the Sidecar build is valid
func (b *Builder) ValidateBuild() error {
	if !b.config.EnableSidecar {
		return nil // Sidecar not enabled, nothing to validate
	}

	sidecarDir := "cassandra-sidecar"
	
	if !config.FileOrDirExists(sidecarDir) {
		return fmt.Errorf("cassandra-sidecar directory does not exist")
	}

	// Check for essential build artifacts
	buildDir := filepath.Join(sidecarDir, "build")
	if !config.FileOrDirExists(buildDir) {
		return fmt.Errorf("sidecar build directory does not exist - build may have failed")
	}

	// Check for jar files in build/libs
	libsDir := filepath.Join(buildDir, "libs")
	if !config.FileOrDirExists(libsDir) {
		return fmt.Errorf("sidecar build libs directory does not exist - build may have failed")
	}

	return nil
}

// GetBuildInfo returns information about the current Sidecar build
func (b *Builder) GetBuildInfo() (map[string]string, error) {
	info := make(map[string]string)

	if !b.config.EnableSidecar {
		info["enabled"] = "false"
		return info, nil
	}

	info["enabled"] = "true"

	if !config.FileOrDirExists("cassandra-sidecar") {
		return info, fmt.Errorf("cassandra-sidecar directory not found")
	}

	// Get git information
	branch, commit, err := git.GetCurrentInfo("cassandra-sidecar")
	if err == nil {
		info["branch"] = branch
		info["commit"] = commit
	}

	// Get build timestamp (if available)
	gradleBuild := filepath.Join("cassandra-sidecar", "build.gradle")
	if config.FileOrDirExists(gradleBuild) {
		info["build_file"] = "present"
	}

	info["source"] = b.config.SidecarCodeSource

	return info, nil
}

// CleanBuild removes Sidecar build artifacts
func (b *Builder) CleanBuild() error {
	if !b.config.EnableSidecar {
		return nil // Sidecar not enabled, nothing to clean
	}

	fmt.Println("🧹 Cleaning previous Sidecar build...")

	if !config.FileOrDirExists("cassandra-sidecar") {
		return nil // Nothing to clean
	}

	// Use Gradle clean if gradlew is available
	gradlewPath := filepath.Join("cassandra-sidecar", "gradlew")
	if config.FileOrDirExists(gradlewPath) {
		result := system.GradlewCommand([]string{"clean"}, &system.CommandOptions{
			WorkingDir: "cassandra-sidecar",
			Silent:     true,
		})
		if result.ExitCode == 0 {
			return nil
		}
	}

	// Fallback: remove build directory manually
	buildDir := filepath.Join("cassandra-sidecar", "build")
	if config.FileOrDirExists(buildDir) {
		return config.RemoveDirectory(buildDir)
	}

	return nil
}

// CheckBuildDependencies verifies that all required tools are available for Sidecar
func CheckBuildDependencies() error {
	// Sidecar uses Gradle wrapper, so we primarily need Java and Git
	required := []string{"java", "git"}
	
	var missing []string
	for _, cmd := range required {
		if !system.CheckCommandExists(cmd) {
			missing = append(missing, cmd)
		}
	}

	if len(missing) > 0 {
		return fmt.Errorf("missing required Sidecar build dependencies: %v", missing)
	}

	// Check Java version (Sidecar typically requires Java 11+)
	result := system.ExecuteCommand("java", []string{"-version"}, &system.CommandOptions{Silent: true})
	if result.ExitCode != 0 {
		return fmt.Errorf("failed to get Java version for Sidecar build")
	}

	return nil
}

// GetSidecarVersion attempts to determine the Sidecar version being built
func (b *Builder) GetSidecarVersion() (string, error) {
	if !b.config.EnableSidecar {
		return "", fmt.Errorf("sidecar not enabled")
	}

	if !config.FileOrDirExists("cassandra-sidecar") {
		return "", fmt.Errorf("cassandra-sidecar directory not found")
	}

	// Try to read version from gradle.properties or build.gradle
	gradleProps := filepath.Join("cassandra-sidecar", "gradle.properties")
	if config.FileOrDirExists(gradleProps) {
		// This would require parsing the properties file
		// For now, return a placeholder
		return "development", nil
	}

	return "development", nil
}

// SetupLocalBuild prepares for building from a local Sidecar repository
func (b *Builder) SetupLocalBuild() error {
	if !b.config.EnableSidecar {
		return nil // Sidecar not enabled, nothing to setup
	}

	if b.config.LocalSidecarPath == "" {
		return fmt.Errorf("no local Sidecar path configured")
	}

	// Validate that the local path exists and is a git repository
	if !config.FileOrDirExists(b.config.LocalSidecarPath) {
		return fmt.Errorf("local Sidecar path does not exist: %s", b.config.LocalSidecarPath)
	}

	if !git.ValidateGitRepository(b.config.LocalSidecarPath) {
		return fmt.Errorf("local Sidecar path is not a git repository: %s", b.config.LocalSidecarPath)
	}

	// Validate that it has the necessary build files
	buildGradle := filepath.Join(b.config.LocalSidecarPath, "build.gradle")
	gradlew := filepath.Join(b.config.LocalSidecarPath, "gradlew")
	
	if !config.FileOrDirExists(buildGradle) {
		return fmt.Errorf("build.gradle not found in local Sidecar repository")
	}

	if !config.FileOrDirExists(gradlew) {
		return fmt.Errorf("gradlew not found in local Sidecar repository")
	}

	return nil
}

// EstimateBuildTime provides an estimate of Sidecar build time
func EstimateBuildTime() string {
	// Sidecar builds are generally faster than Cassandra
	return "2-8 minutes depending on system performance"
}

// GetRecommendedJVMOptions returns recommended JVM options for building Sidecar
func GetRecommendedJVMOptions() []string {
	return []string{
		"-Xmx2G",
		"-XX:+UseG1GC",
		"-Dorg.gradle.daemon=true",
		"-Dorg.gradle.parallel=true",
	}
}

// RunSidecarTests runs the Sidecar test suite
func (b *Builder) RunSidecarTests() error {
	if !b.config.EnableSidecar {
		return nil // Sidecar not enabled, nothing to test
	}

	if !config.FileOrDirExists("cassandra-sidecar") {
		return fmt.Errorf("cassandra-sidecar directory not found")
	}

	fmt.Println("🧪 Running Sidecar tests...")

	result := system.GradlewCommand([]string{"test"}, &system.CommandOptions{
		WorkingDir: "cassandra-sidecar",
	})

	if result.ExitCode != 0 {
		return fmt.Errorf("Sidecar tests failed: %s", result.Stderr)
	}

	fmt.Println("✅ Sidecar tests passed!")
	return nil
}

// GetTestResults returns information about the last test run
func (b *Builder) GetTestResults() (map[string]interface{}, error) {
	if !b.config.EnableSidecar {
		return nil, fmt.Errorf("sidecar not enabled")
	}

	results := make(map[string]interface{})
	
	// Check if test results exist
	testResultsDir := filepath.Join("cassandra-sidecar", "build", "test-results", "test")
	if config.FileOrDirExists(testResultsDir) {
		results["test_results_available"] = true
		// This would require parsing test result XML files
		results["location"] = testResultsDir
	} else {
		results["test_results_available"] = false
	}

	return results, nil
}