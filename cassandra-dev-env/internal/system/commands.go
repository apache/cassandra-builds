package system

import (
	"bufio"
	"context"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strings"
	"time"
)

// CommandResult holds the result of a command execution
type CommandResult struct {
	ExitCode int
	Stdout   string
	Stderr   string
	Error    error
}

// CommandOptions configures how a command should be executed
type CommandOptions struct {
	WorkingDir string
	Env        []string
	Timeout    time.Duration
	Silent     bool
}

// ExecuteCommand runs a system command and returns the result
func ExecuteCommand(command string, args []string, opts *CommandOptions) *CommandResult {
	if opts == nil {
		opts = &CommandOptions{}
	}

	// Create context with timeout if specified
	var ctx context.Context
	var cancel context.CancelFunc
	if opts.Timeout > 0 {
		ctx, cancel = context.WithTimeout(context.Background(), opts.Timeout)
		defer cancel()
	} else {
		ctx = context.Background()
	}

	// Create command
	cmd := exec.CommandContext(ctx, command, args...)

	// Set working directory if specified
	if opts.WorkingDir != "" {
		cmd.Dir = opts.WorkingDir
	}

	// Set environment if specified
	if len(opts.Env) > 0 {
		cmd.Env = append(os.Environ(), opts.Env...)
	}

	// Capture stdout and stderr
	var stdoutBuf, stderrBuf strings.Builder
	
	if opts.Silent {
		cmd.Stdout = &stdoutBuf
		cmd.Stderr = &stderrBuf
	} else {
		// Stream output to both capture and console
		cmd.Stdout = io.MultiWriter(os.Stdout, &stdoutBuf)
		cmd.Stderr = io.MultiWriter(os.Stderr, &stderrBuf)
	}

	// Execute command
	err := cmd.Run()
	exitCode := 0
	if err != nil {
		if exitError, ok := err.(*exec.ExitError); ok {
			exitCode = exitError.ExitCode()
		} else {
			exitCode = -1
		}
	}

	return &CommandResult{
		ExitCode: exitCode,
		Stdout:   stdoutBuf.String(),
		Stderr:   stderrBuf.String(),
		Error:    err,
	}
}

// ExecuteCommandStreaming runs a command and streams output in real-time
func ExecuteCommandStreaming(command string, args []string, opts *CommandOptions) error {
	if opts == nil {
		opts = &CommandOptions{}
	}

	cmd := exec.Command(command, args...)

	if opts.WorkingDir != "" {
		cmd.Dir = opts.WorkingDir
	}

	if len(opts.Env) > 0 {
		cmd.Env = append(os.Environ(), opts.Env...)
	}

	// Create pipes for streaming output
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return fmt.Errorf("failed to create stdout pipe: %w", err)
	}

	stderr, err := cmd.StderrPipe()
	if err != nil {
		return fmt.Errorf("failed to create stderr pipe: %w", err)
	}

	// Start command
	if err := cmd.Start(); err != nil {
		return fmt.Errorf("failed to start command: %w", err)
	}

	// Stream stdout
	go func() {
		scanner := bufio.NewScanner(stdout)
		for scanner.Scan() {
			if !opts.Silent {
				fmt.Println(scanner.Text())
			}
		}
	}()

	// Stream stderr
	go func() {
		scanner := bufio.NewScanner(stderr)
		for scanner.Scan() {
			if !opts.Silent {
				fmt.Fprintf(os.Stderr, "%s\n", scanner.Text())
			}
		}
	}()

	// Wait for command to complete
	return cmd.Wait()
}

// DockerCommand executes a docker command
func DockerCommand(args []string, opts *CommandOptions) *CommandResult {
	return ExecuteCommand("docker", args, opts)
}

// DockerComposeCommand executes a docker-compose command
func DockerComposeCommand(args []string, opts *CommandOptions) *CommandResult {
	env := []string{"COMPOSE_BAKE=false"}
	if opts != nil && len(opts.Env) > 0 {
		env = append(env, opts.Env...)
	}
	if opts == nil {
		opts = &CommandOptions{}
	}
	opts.Env = env
	return ExecuteCommand("docker-compose", args, opts)
}

// GitCommand executes a git command
func GitCommand(args []string, opts *CommandOptions) *CommandResult {
	return ExecuteCommand("git", args, opts)
}

// AntCommand executes an ant command
func AntCommand(args []string, opts *CommandOptions) *CommandResult {
	return ExecuteCommand("ant", args, opts)
}

// GradlewCommand executes a gradlew command
func GradlewCommand(args []string, opts *CommandOptions) *CommandResult {
	return ExecuteCommand("./gradlew", args, opts)
}

// CheckCommandExists checks if a command is available in the system PATH
func CheckCommandExists(command string) bool {
	_, err := exec.LookPath(command)
	return err == nil
}

// RequireCommands checks that all required commands are available
func RequireCommands(commands []string) error {
	var missing []string
	for _, cmd := range commands {
		if !CheckCommandExists(cmd) {
			missing = append(missing, cmd)
		}
	}

	if len(missing) > 0 {
		return fmt.Errorf("required commands not found: %s", strings.Join(missing, ", "))
	}

	return nil
}

// GetDockerContainerIDs returns container IDs matching the given filter
func GetDockerContainerIDs(filter string) ([]string, error) {
	result := DockerCommand([]string{"ps", "-q", "--filter=" + filter}, &CommandOptions{Silent: true})
	if result.ExitCode != 0 {
		return nil, fmt.Errorf("failed to get container IDs: %s", result.Stderr)
	}

	var ids []string
	lines := strings.Split(strings.TrimSpace(result.Stdout), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line != "" {
			ids = append(ids, line)
		}
	}

	return ids, nil
}

// IsDockerRunning checks if Docker daemon is running
func IsDockerRunning() bool {
	result := DockerCommand([]string{"version"}, &CommandOptions{Silent: true})
	return result.ExitCode == 0
}