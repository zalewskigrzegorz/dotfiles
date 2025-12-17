# Docker/Podman Compatibility Layer
# Allows switching between Docker and Podman without modifying codebase
# Supports both v1 (docker-compose) and v2 (docker compose) syntax
#
# Initialize USE_PODMAN environment variable in env.nu or set it manually:
#   $env.USE_PODMAN = false  # default: docker
#   $env.USE_PODMAN = true   # use podman

# Switch to Podman runtime
# Sets up podman environment variables and switches to podman
# Usage: use-podman
export def use-podman [] {
    # Initialize USE_PODMAN if not set
    if not ("USE_PODMAN" in $env) {
        $env.USE_PODMAN = false
    }
    
    # Ensure XDG_RUNTIME_DIR is set (required for podman socket detection)
    if not ("XDG_RUNTIME_DIR" in $env) {
        let xdg_runtime = ($env.HOME | path join ".local" "run")
        $env.XDG_RUNTIME_DIR = $xdg_runtime
    }

    # Detect podman socket location
    # Try rootless first (most common on macOS/Linux)
    let rootless_sock = ($env.XDG_RUNTIME_DIR | path join "podman" "podman.sock")
    let rootful_sock = "/var/run/podman/podman.sock"
    
    let podman_sock = if ($rootless_sock | path exists) {
        $"unix://($rootless_sock)"
    } else if ($rootful_sock | path exists) {
        $"unix://($rootful_sock)"
    } else {
        # On macOS with podman machine, socket might be in different location
        # Try common macOS podman machine socket location
        let macos_sock = ($env.HOME | path join ".local" "share" "containers" "podman" "machine" "podman-machine-default" "podman.sock")
        if ($macos_sock | path exists) {
            $"unix://($macos_sock)"
        } else {
            # Default to rootless socket path (podman will create it if needed)
            $"unix://($rootless_sock)"
        }
    }

    # Set environment variables for podman
    $env.USE_PODMAN = true
    $env.DOCKER_HOST = $podman_sock
    $env.CONTAINER_HOST = $podman_sock
    
    # Export variables so shell scripts can pick them up
    # In nushell, environment variables set with $env are automatically exported to child processes
    
    print $"✓ Switched to Podman"
    print $"  Socket: ($podman_sock)"
    print $"  USE_PODMAN: ($env.USE_PODMAN)"
    print $"  DOCKER_HOST: ($env.DOCKER_HOST)"
}

# Switch to Docker runtime
# Resets to docker environment
# Usage: use-docker
export def use-docker [] {
    # Initialize USE_PODMAN if not set
    if not ("USE_PODMAN" in $env) {
        $env.USE_PODMAN = false
    }
    
    # Reset to docker defaults
    $env.USE_PODMAN = false
    
    # Set DOCKER_HOST to docker default
    # On macOS, Docker Desktop typically uses /var/run/docker.sock
    # But it might also use socket forwarding, so we'll unset it to use defaults
    $env.DOCKER_HOST = ""
    
    # Clean up podman-specific vars
    $env.CONTAINER_HOST = ""
    
    print $"✓ Switched to Docker"
    print $"  USE_PODMAN: ($env.USE_PODMAN)"
    print "  DOCKER_HOST: default"
}

# Show current runtime status
# Displays current runtime (docker/podman), socket location, and relevant environment variables
# Usage: docker-status
export def docker-status [] {
    # Initialize USE_PODMAN if not set
    if not ("USE_PODMAN" in $env) {
        $env.USE_PODMAN = false
    }
    
    let runtime = if $env.USE_PODMAN {
        "Podman"
    } else {
        "Docker"
    }
    
    let socket = if ("DOCKER_HOST" in $env) and ($env.DOCKER_HOST != "") {
        $env.DOCKER_HOST
    } else {
        "default (system)"
    }
    
    print $"Runtime: ($runtime)"
    print $"USE_PODMAN: ($env.USE_PODMAN)"
    print $"DOCKER_HOST: ($socket)"
    
    if ("CONTAINER_HOST" in $env) and ($env.CONTAINER_HOST != "") {
        print $"CONTAINER_HOST: ($env.CONTAINER_HOST)"
    }
}

# Docker wrapper function
# Intercepts docker commands and routes to podman or docker based on USE_PODMAN
# Handles both regular docker commands and "docker compose" (v2 syntax)
# Usage: docker <command> [args...]
# Note: Using 'def' instead of 'export def' to avoid module naming conflict
def docker [...args] {
    # Initialize USE_PODMAN if not set
    if not ("USE_PODMAN" in $env) {
        $env.USE_PODMAN = false
    }
    
    if $env.USE_PODMAN {
        # Check if first argument is "compose" (v2 syntax)
        if ($args | length) > 0 and ($args | first) == "compose" {
            # Route "docker compose" to "podman compose"
            let compose_args = ($args | skip 1)
            podman compose ...$compose_args
        } else {
            # Route other docker commands to podman
            podman ...$args
        }
    } else {
        # Route to system docker
        # Use ^docker to avoid recursion
        ^docker ...$args
    }
}

# Docker-compose wrapper function (v1 syntax)
# Intercepts docker-compose commands and routes to podman compose or docker-compose
# Usage: docker-compose <command> [args...]
# Note: Using 'def' instead of 'export def' to avoid module naming conflict
def docker-compose [...args] {
    # Initialize USE_PODMAN if not set
    if not ("USE_PODMAN" in $env) {
        $env.USE_PODMAN = false
    }
    
    if $env.USE_PODMAN {
        # Route to "podman compose"
        podman compose ...$args
    } else {
        # Route to system docker-compose
        # Use ^docker-compose to avoid recursion
        ^docker-compose ...$args
    }
}
