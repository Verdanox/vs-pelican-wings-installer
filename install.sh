#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}--------$1--------${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VERSION=$VERSION_ID
    else
        print_error "Cannot detect operating system"
        exit 1
    fi
    
    if [[ "$OS" != *"Ubuntu"* ]] && [[ "$OS" != *"Debian"* ]]; then
        print_error "This script only supports Ubuntu and Debian"
        exit 1
    fi
}

install_docker() {
    print_status "Installing Docker..."
    
    curl -sSL https://get.docker.com/ | CHANNEL=stable sudo sh
    
    print_success "Docker installed successfully"
}

install_wings() {
    print_status "Installing Wings..."
    
    sudo mkdir -p /etc/pelican /var/run/wings
    
    ARCH=$([[ "$(uname -m)" == "x86_64" ]] && echo "amd64" || echo "arm64")
    sudo curl -L -o /usr/local/bin/wings "https://github.com/pelican-dev/wings/releases/latest/download/wings_linux_$ARCH"
    
    sudo chmod u+x /usr/local/bin/wings
    
    print_success "Wings binary installed successfully"
}

setup_wings() {
    print_status "Setting Up..."
    
    echo "Create a Node in your Pelican Panel and go to \"Configuration File\" to create an Auto Deploy Command."
    echo ""
    echo -n "What is your Auto Deploy Command?: "
    read AUTO_DEPLOY_CMD < /dev/tty
    
    if [[ -z "$AUTO_DEPLOY_CMD" ]]; then
        print_error "Auto Deploy Command cannot be empty"
        exit 1
    fi
    
    eval $AUTO_DEPLOY_CMD
    
    print_success "Wings configured successfully"
}

create_service() {
    print_status "Creating Service..."
    
    sudo tee /etc/systemd/system/wings.service > /dev/null << EOF
[Unit]
Description=Wings Daemon
After=docker.service
Requires=docker.service
PartOf=docker.service

[Service]
User=root
WorkingDirectory=/etc/pelican
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
    
    print_success "Wings service file created"
}

enable_wings() {
    print_status "Enabling Wings..."
    
    sudo systemctl enable --now wings
    
    print_success "Wings service enabled and started"
}

display_completion() {
    print_status "Finished Wings Installation!"
    echo ""
    print_success "Pelican Wings installation completed successfully!"
    echo ""
    print_warning "Wings is now running and will automatically start on boot"
    echo ""
    print_warning "You can check the status with: sudo systemctl status wings"
    echo "View logs with: sudo journalctl -u wings -f"
}

main() {
    echo -e "${BLUE}--------PELICAN WINGS INSTALLATION SCRIPT--------${NC}"
    echo -e "${GREEN}Made by: Verdanox${NC}"
    echo ""
    
    check_root
    detect_os
    
    print_warning "Installing Pelican Wings on your server..."
    print_warning "Operating System: $OS $VERSION"
    echo ""
    
    install_docker
    install_wings
    setup_wings
    create_service
    enable_wings
    display_completion
}

main "$@"
