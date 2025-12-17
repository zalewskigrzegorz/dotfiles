# Docker/Podman Compatibility Layer
# Allows switching between Docker and Podman without modifying codebase
# Supports both v1 (docker-compose) and v2 (docker compose) syntax

# Helper function to ensure USE_PODMAN is initialized
def ensure-use-podman [] {
    if not ("USE_PODMAN" in $env) {
        $env.USE_PODMAN = false
    }
}

# Switch to Podman runtime
# Sets up podman environment variables and switches to podman
# Usage: use-podman
export def use-podman [] {
    ensure-use-podman
    
    # Ensure XDG_RUNTIME_DIR is set (should already be set via fix-macos-path.nu)
    if not ("XDG_RUNTIME_DIR" in $env) {
        let xdg_runtime = ($env.HOME | path join ".local" "run")
        $env.XDG_RUNTIME_DIR = $xdg_runtime
    }

    # Detect podman socket location
    # Try rootless first (most common on macOS)
    let rootless_socket = ($env.XDG_RUNTIME_DIR | path join "podman" "podman.sock")
    let rootful_socket = "/var/run/podman/podman.sock"
    
    let podman_socket = if ($rootless_socket | path exists) {
        $"unix://($rootless_socket)"
    } else if ($rootful_socket | path exists) {
        $"unix://($rootful_socket)"
    } else {
        # On macOS with podman machine, socket might be forwarded
        # Try to detect via podman context or use default
        try {
            let context = (podman context ls --format json | from json | where current == true | first)
            if ($context | is-not-empty) {
                $context.socket
            } else {
                $"unix://($rootless_socket)"
            }
        } catch {
            # Fallback to rootless socket path
            $"unix://($rootless_socket)"
        }
    }

    # Set environment variables for podman
    $env.USE_PODMAN = true
    $env.DOCKER_HOST = $podman_socket
    $env.CONTAINER_HOST = $podman_socket
    
    print $"✓ Switched to Podman"
    print $"  Socket: ($podman_socket)"
    print $"  USE_PODMAN: ($env.USE_PODMAN)"
}

# Switch back to Docker runtime
# Resets environment to use Docker
# Usage: use-docker
export def use-docker [] {
    ensure-use-podman
    
    # Reset to docker defaults
    $env.USE_PODMAN = false
    
    # Docker Desktop on macOS typically uses:
    # - /var/run/docker.sock (requires root)
    # - Or socket forwarding via Docker Desktop
    # Leave DOCKER_HOST unset to use Docker's default detection
    hide DOCKER_HOST
    hide CONTAINER_HOST
    
    print $"✓ Switched to Docker"
    print $"  USE_PODMAN: ($env.USE_PODMAN)"
}

# Show current Docker/Podman runtime status
# Displays current runtime, socket location, and relevant environment variables
# Usage: docker-status
export def docker-status [] {
    ensure-use-podman
    
    let use_podman = if ("USE_PODMAN" in $env) {
        $env.USE_PODMAN
    } else {
        false
    }
    
    let runtime = if $use_podman {
        "Podman"
    } else {
        "Docker"
    }
    
    let socket = if ("DOCKER_HOST" in $env) and ($env.DOCKER_HOST | is-not-empty) {
        $env.DOCKER_HOST
    } else {
        "default (system detection)"
    }
    
    print $"Runtime: ($runtime)"
    print $"Socket: ($socket)"
    print $"USE_PODMAN: ($use_podman)"
    print $"DOCKER_HOST: (if ('DOCKER_HOST' in $env) { $env.DOCKER_HOST } else { 'not set' })"
    print $"CONTAINER_HOST: (if ('CONTAINER_HOST' in $env) { $env.CONTAINER_HOST } else { 'not set' })"
}

# Docker wrapper function
# Intercepts docker commands and routes to podman or docker based on USE_PODMAN
# Handles both regular docker commands and "docker compose" (v2 syntax)
# Usage: docker [args...]
export def --wrapped docker [...args] {
    ensure-use-podman
    
    let use_podman = if ("USE_PODMAN" in $env) { $env.USE_PODMAN } else { false }
    
    if $use_podman {
        # Check if first argument is "compose" (v2 syntax)
        if ($args | length) > 0 and ($args | first) == "compose" {
            # Route to podman compose
            let compose_args = ($args | skip 1)
            podman compose ...$compose_args
        } else {
            # Route to podman
            podman ...$args
        }
    } else {
        # Use system docker
        # Check if first argument is "compose" (v2 syntax)
        if ($args | length) > 0 and ($args | first) == "compose" {
            # Route to docker compose (v2)
            let compose_args = ($args | skip 1)
            ^docker compose ...$compose_args
        } else {
            # Route to docker
            ^docker ...$args
        }
    }
}

# Docker Compose wrapper function (v1 syntax)
# Intercepts docker-compose commands and routes to podman compose or docker-compose
# Usage: docker-compose [args...]
export def --wrapped docker-compose [...args] {
    ensure-use-podman
    
    let use_podman = if ("USE_PODMAN" in $env) { $env.USE_PODMAN } else { false }
    
    if $use_podman {
        # Route to podman compose
        podman compose ...$args
    } else {
        # Route to docker-compose (v1)
        ^docker-compose ...$args
    }
}

