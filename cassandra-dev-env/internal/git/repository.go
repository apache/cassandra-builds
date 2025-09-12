package git

import (
	"fmt"
	"os"
	"path/filepath"

	"cassandra-dev-env/internal/config"
	"cassandra-dev-env/internal/system"
)

// Repository handles git repository operations
type Repository struct {
	config *config.Config
}

// NewRepository creates a new git repository handler
func NewRepository(cfg *config.Config) *Repository {
	return &Repository{
		config: cfg,
	}
}

// CloneCassandraRepository clones the Cassandra repository based on configuration
func (r *Repository) CloneCassandraRepository() error {
	// Always clean when switching to avoid git conflicts
	if config.FileOrDirExists("cassandra") {
		fmt.Println("🧹 Cleaning previous repository for fresh checkout...")
		if err := config.RemoveDirectory("cassandra"); err != nil {
			return fmt.Errorf("failed to remove existing cassandra directory: %w", err)
		}
	}

	if r.config.LocalCassandraPath != "" {
		return r.copyLocalRepository("cassandra", r.config.LocalCassandraPath)
	}

	if r.config.PR != "" {
		return r.clonePR("cassandra", r.config.RepoURL, r.config.PR)
	}

	if r.config.Commit != "" {
		return r.cloneCommit("cassandra", r.config.RepoURL, r.config.Commit)
	}

	return r.cloneBranch("cassandra", r.config.RepoURL, r.config.Branch)
}

// CloneSidecarRepository clones the Sidecar repository based on configuration
func (r *Repository) CloneSidecarRepository() error {
	if !r.config.EnableSidecar {
		return nil
	}

	// Always clean when switching to avoid git conflicts
	if config.FileOrDirExists("cassandra-sidecar") {
		fmt.Println("🧹 Cleaning previous sidecar repository for fresh checkout...")
		if err := config.RemoveDirectory("cassandra-sidecar"); err != nil {
			return fmt.Errorf("failed to remove existing cassandra-sidecar directory: %w", err)
		}
	}

	sidecarRepoURL := "https://github.com/apache/cassandra-sidecar.git"

	if r.config.LocalSidecarPath != "" {
		return r.copyLocalRepository("cassandra-sidecar", r.config.LocalSidecarPath)
	}

	if r.config.SidecarPR != "" {
		return r.clonePR("cassandra-sidecar", sidecarRepoURL, r.config.SidecarPR)
	}

	if r.config.SidecarCommit != "" {
		return r.cloneCommit("cassandra-sidecar", sidecarRepoURL, r.config.SidecarCommit)
	}

	return r.cloneBranch("cassandra-sidecar", sidecarRepoURL, r.config.SidecarBranch)
}

// copyLocalRepository copies a local repository to the target directory
func (r *Repository) copyLocalRepository(targetDir, sourcePath string) error {
	fmt.Printf("📂 Using local repository: %s\n", sourcePath)
	fmt.Printf("📥 Copying local repository to %s...\n", targetDir)

	// Use cp -r to copy the repository
	result := system.ExecuteCommand("cp", []string{"-r", sourcePath, targetDir}, nil)
	if result.ExitCode != 0 {
		return fmt.Errorf("failed to copy local repository: %s", result.Stderr)
	}

	return nil
}

// cloneBranch clones a specific branch
func (r *Repository) cloneBranch(targetDir, repoURL, branch string) error {
	fmt.Printf("🌿 Using branch %s\n", branch)
	fmt.Printf("📥 Cloning repository to %s...\n", targetDir)

	args := []string{"clone", "--depth", "1", "--branch", branch, repoURL, targetDir}
	result := system.GitCommand(args, nil)
	if result.ExitCode != 0 {
		return fmt.Errorf("failed to clone branch %s: %s", branch, result.Stderr)
	}

	return nil
}

// cloneCommit clones a repository and checks out a specific commit
func (r *Repository) cloneCommit(targetDir, repoURL, commit string) error {
	fmt.Printf("📍 Using commit %s\n", commit)
	fmt.Printf("📥 Cloning repository to %s...\n", targetDir)

	// Clone the full repository (can't use --depth with specific commit)
	result := system.GitCommand([]string{"clone", repoURL, targetDir}, nil)
	if result.ExitCode != 0 {
		return fmt.Errorf("failed to clone repository: %s", result.Stderr)
	}

	// Change to the repository directory and checkout the commit
	result = system.GitCommand([]string{"checkout", commit}, &system.CommandOptions{
		WorkingDir: targetDir,
	})
	if result.ExitCode != 0 {
		return fmt.Errorf("failed to checkout commit %s: %s", commit, result.Stderr)
	}

	return nil
}

// clonePR clones a repository and checks out a specific pull request
func (r *Repository) clonePR(targetDir, repoURL, pr string) error {
	fmt.Printf("🔀 Using Pull Request #%s\n", pr)
	fmt.Printf("📥 Cloning repository to %s...\n", targetDir)

	// Clone the repository
	result := system.GitCommand([]string{"clone", repoURL, targetDir}, nil)
	if result.ExitCode != 0 {
		return fmt.Errorf("failed to clone repository: %s", result.Stderr)
	}

	// Fetch the PR and checkout
	workingDir := &system.CommandOptions{WorkingDir: targetDir}

	result = system.GitCommand([]string{"fetch", "origin", fmt.Sprintf("pull/%s/head:pr-%s", pr, pr)}, workingDir)
	if result.ExitCode != 0 {
		return fmt.Errorf("failed to fetch PR #%s: %s", pr, result.Stderr)
	}

	result = system.GitCommand([]string{"checkout", fmt.Sprintf("pr-%s", pr)}, workingDir)
	if result.ExitCode != 0 {
		return fmt.Errorf("failed to checkout PR #%s: %s", pr, result.Stderr)
	}

	return nil
}

// GetCurrentInfo returns information about the current checkout
func GetCurrentInfo(repoDir string) (branch, commit string, err error) {
	if !config.FileOrDirExists(repoDir) {
		return "", "", fmt.Errorf("repository directory %s does not exist", repoDir)
	}

	workingDir := &system.CommandOptions{
		WorkingDir: repoDir,
		Silent:     true,
	}

	// Get current branch
	result := system.GitCommand([]string{"branch", "--show-current"}, workingDir)
	if result.ExitCode == 0 {
		branch = result.Stdout
	} else {
		branch = "unknown"
	}

	// Get current commit
	result = system.GitCommand([]string{"rev-parse", "--short", "HEAD"}, workingDir)
	if result.ExitCode == 0 {
		commit = result.Stdout
	} else {
		commit = "unknown"
	}

	return branch, commit, nil
}

// ValidateGitRepository checks if a directory is a valid git repository
func ValidateGitRepository(path string) bool {
	if !config.FileOrDirExists(path) {
		return false
	}

	gitDir := filepath.Join(path, ".git")
	return config.FileOrDirExists(gitDir)
}

// IsGitAvailable checks if git command is available
func IsGitAvailable() bool {
	result := system.ExecuteCommand("git", []string{"--version"}, &system.CommandOptions{Silent: true})
	return result.ExitCode == 0
}

// CleanRepository removes git-related temporary files and resets the repository
func CleanRepository(repoDir string) error {
	if !ValidateGitRepository(repoDir) {
		return nil // Not a git repository, nothing to clean
	}

	workingDir := &system.CommandOptions{
		WorkingDir: repoDir,
		Silent:     true,
	}

	// Reset any changes
	system.GitCommand([]string{"reset", "--hard", "HEAD"}, workingDir)

	// Clean untracked files
	system.GitCommand([]string{"clean", "-fd"}, workingDir)

	return nil
}

// GetRemoteURL returns the remote URL of a git repository
func GetRemoteURL(repoDir string) (string, error) {
	if !ValidateGitRepository(repoDir) {
		return "", fmt.Errorf("not a valid git repository: %s", repoDir)
	}

	result := system.GitCommand([]string{"remote", "get-url", "origin"}, &system.CommandOptions{
		WorkingDir: repoDir,
		Silent:     true,
	})

	if result.ExitCode != 0 {
		return "", fmt.Errorf("failed to get remote URL: %s", result.Stderr)
	}

	return result.Stdout, nil
}

// GetCommitInfo returns detailed information about the current commit
func GetCommitInfo(repoDir string) (hash, message, author string, err error) {
	if !ValidateGitRepository(repoDir) {
		return "", "", "", fmt.Errorf("not a valid git repository: %s", repoDir)
	}

	workingDir := &system.CommandOptions{
		WorkingDir: repoDir,
		Silent:     true,
	}

	// Get commit hash
	result := system.GitCommand([]string{"rev-parse", "HEAD"}, workingDir)
	if result.ExitCode == 0 {
		hash = result.Stdout
	}

	// Get commit message
	result = system.GitCommand([]string{"log", "-1", "--pretty=format:%s"}, workingDir)
	if result.ExitCode == 0 {
		message = result.Stdout
	}

	// Get commit author
	result = system.GitCommand([]string{"log", "-1", "--pretty=format:%an"}, workingDir)
	if result.ExitCode == 0 {
		author = result.Stdout
	}

	return hash, message, author, nil
}

// CreateGitIgnoreEntry adds entries to .gitignore
func CreateGitIgnoreEntry(entries []string) error {
	gitignorePath := ".gitignore"

	// Check if .gitignore exists
	var content string
	if config.FileOrDirExists(gitignorePath) {
		// Read existing content
		file, err := os.ReadFile(gitignorePath)
		if err != nil {
			return fmt.Errorf("failed to read .gitignore: %w", err)
		}
		content = string(file)
	}

	// Add new entries
	content += "\n# Temporary build directories created by cassandra-env-manager\n"
	for _, entry := range entries {
		content += entry + "\n"
	}

	// Write back to file
	err := os.WriteFile(gitignorePath, []byte(content), 0644)
	if err != nil {
		return fmt.Errorf("failed to write .gitignore: %w", err)
	}

	return nil
}
