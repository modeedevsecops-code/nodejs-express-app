#!/bin/bash

# Log file for recording the setup process
LOG_FILE="/var/log/isolated_env_setup.log"

# Log function to log messages with timestamps
log_message() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Error handling function to stop execution on error
handle_error() {
    log_message "Error: $1"
    exit 1
}

# Step 1: Create the minimal filesystem
create_filesystem() {
    log_message "Creating minimal filesystem..."
    # Create the directories for the isolated environment
    mkdir -p /isolated_env/{bin,lib,lib64,etc,proc,sys,dev} || handle_error "Failed to create filesystem"
    log_message "Filesystem created successfully."
}

# Step 2: Set up namespaces (PID, User, Mount, Network)
setup_namespaces() {
    log_message "Setting up namespaces (PID, User, Mount, Network)..."
    # PID namespace
    unshare --pid --fork /bin/true || handle_error "Failed to set up PID namespace"
    # User namespace
    unshare --user --map-root-user /bin/true || handle_error "Failed to set up User namespace"
    # Mount namespace
    unshare --mount --fork /bin/true || handle_error "Failed to set up Mount namespace"
    # Network namespace
    ip netns add isolated_net_ns || handle_error "Failed to set up Network namespace"
    log_message "Namespaces set up successfully."
}

# Step 3: Mount the necessary system files into the isolated environment
mount_system_files() {
    log_message "Mounting system files into isolated environment..."
    mount --bind /proc /isolated_env/proc || handle_error "Failed to mount /proc"
    mount --bind /sys /isolated_env/sys || handle_error "Failed to mount /sys"
    mount --bind /dev /isolated_env/dev || handle_error "Failed to mount /dev"
    log_message "System files mounted successfully."
}

# Step 4: Set up network isolation with virtual interfaces
setup_network_isolation() {
    log_message "Setting up network isolation with virtual interfaces..."
    sudo ip link add veth0 type veth peer name veth1 || handle_error "Failed to create veth pair"
    sudo ip link set veth1 netns isolated_net_ns || handle_error "Failed to move veth1 to network namespace"
    sudo ip link set veth0 up || handle_error "Failed to bring up veth0"
    sudo ip netns exec isolated_net_ns ip link set veth1 up || handle_error "Failed to bring up veth1 in network namespace"
    sudo ip addr add 192.168.1.1/24 dev veth0 || handle_error "Failed to assign IP to veth0"
    sudo ip netns exec isolated_net_ns ip addr add 192.168.1.2/24 dev veth1 || handle_error "Failed to assign IP to veth1"
    sudo ip netns exec isolated_net_ns ip route add default via 192.168.1.1 || handle_error "Failed to add routing"
    log_message "Network isolation set up successfully."
}

# Step 5: Clean up the environment (remove namespaces, interfaces, and filesystem)
cleanup() {
    log_message "Cleaning up the isolated environment..."

    # Remove the network namespace
    sudo ip netns delete isolated_net_ns || echo "Network namespace deletion failed."

    # Clean up the virtual network interfaces
    sudo ip link delete veth0 || echo "Failed to delete veth0 interface."

    # Optionally, remove the isolated environment directory
    sudo rm -rf /isolated_env || echo "Failed to remove /isolated_env directory."

    log_message "Cleanup completed."
}

# Run the full setup
run_setup() {
    create_filesystem
    setup_namespaces
    mount_system_files
    setup_network_isolation
}

# Main function to manage both setup and cleanup
main() {
    if [ "$1" == "setup" ]; then
        log_message "Starting isolated environment setup..."
        run_setup
        log_message "Isolated environment setup completed successfully!"
    elif [ "$1" == "cleanup" ]; then
        cleanup
    else
        echo "Usage: $0 {setup|cleanup}"
        exit 1
    fi
}

# Call the main function
main "$1"
