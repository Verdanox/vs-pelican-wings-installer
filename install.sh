#!/bin/bash

alternate=true

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

check_wings_installation() {
    if [[ -f /usr/local/bin/wings ]] && [[ -f /etc/systemd/system/wings.service ]]; then
        return 0
    else
        return 1
    fi
}

uninstall_wings() {
    print_status "Uninstalling Wings..."
    
    sudo systemctl disable --now wings
    sudo rm -f /etc/systemd/system/wings.service
    sudo rm -f /usr/local/bin/wings
    sudo rm -rf /etc/pelican
    
    print_status "Removing Servers..."
    sudo rm -rf /var/lib/pelican
    
    print_status "Uninstalling docker..."
    sudo systemctl stop docker
    sudo apt remove --purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo apt autoremove -y
    sudo rm -rf /var/lib/docker /var/lib/containerd
    
    print_status "Wings successfully uninstalled."
}

update_wings() {
    print_status "Updating Wings..."
    
    sudo systemctl stop wings
    
    ARCH=$([[ "$(uname -m)" == "x86_64" ]] && echo "amd64" || echo "arm64")
    sudo curl -L -o /usr/local/bin/wings "https://github.com/pelican-dev/wings/releases/latest/download/wings_linux_$ARCH"
    
    sudo chmod u+x /usr/local/bin/wings
    
    sudo systemctl start wings
    
    print_success "Wings updated successfully"
}

upgrade_downgrade_wings() {
    print_status "Upgrade/Downgrade Wings..."
    
    echo "Available versions:"
    echo "1. Latest (default)"
    echo "2. Specific version"
    echo ""
    printf "Select option (1-2): "
    read version_choice < /dev/tty
    
    case $version_choice in
        1|"")
            print_status "Installing latest version..."
            ARCH=$([[ "$(uname -m)" == "x86_64" ]] && echo "amd64" || echo "arm64")
            sudo systemctl stop wings
            sudo curl -L -o /usr/local/bin/wings "https://github.com/pelican-dev/wings/releases/latest/download/wings_linux_$ARCH"
            sudo chmod u+x /usr/local/bin/wings
            sudo systemctl start wings
            print_success "Wings upgraded to latest version"
            ;;
        2)
            printf "Enter version (e.g., v1.0.0): "
            read specific_version < /dev/tty
            
            if [[ -z "$specific_version" ]]; then
                print_error "Version cannot be empty"
                return 1
            fi
            
            print_status "Installing version $specific_version..."
            ARCH=$([[ "$(uname -m)" == "x86_64" ]] && echo "amd64" || echo "arm64")
            sudo systemctl stop wings
            sudo curl -L -o /usr/local/bin/wings "https://github.com/pelican-dev/wings/releases/download/$specific_version/wings_linux_$ARCH"
            
            if [[ $? -ne 0 ]]; then
                print_error "Failed to download version $specific_version"
                print_warning "Restoring service..."
                sudo systemctl start wings
                return 1
            fi
            
            sudo chmod u+x /usr/local/bin/wings
            sudo systemctl start wings
            print_success "Wings changed to version $specific_version"
            ;;
        *)
            print_error "Invalid option"
            return 1
            ;;
    esac
}

show_management_panel() {
    echo -e "${BLUE}--------PELICAN WINGS MANAGEMENT PANEL--------${NC}"
    echo -e "${GREEN}Made by: Verdanox${NC}"
    echo ""
    print_success "Wings installation detected!"
    echo ""
    echo "1. Uninstall Wings"
    echo "2. Update Wings"
    echo "3. Upgrade/Downgrade Wings"
    echo "4. Exit"
    echo ""
    printf "Select option (1-4): "
    read choice < /dev/tty
    
    case $choice in
        1)
            echo ""
            print_warning "This will completely remove Wings, Docker, and all server data!"
            printf "Are you sure? (y/N): "
            read confirm < /dev/tty
            
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                uninstall_wings
            else
                print_warning "Uninstallation cancelled"
            fi
            ;;
        2)
            echo ""
            update_wings
            ;;
        3)
            echo ""
            upgrade_downgrade_wings
            ;;
        4)
            print_warning "Exiting..."
            exit 0
            ;;
        *)
            print_error "Invalid option"
            show_management_panel
            ;;
    esac
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
    print_status "Setting Up Wings Configuration..."
    
    if [[ "$alternate" == true ]]; then
        print_warning "ALTERNATE MODE: Auto Deploy Commands are currently broken in Pelican"
        echo ""
        
        if [[ -f /etc/pelican/config.yml ]] && [[ -s /etc/pelican/config.yml ]]; then
            print_success "Configuration file already exists and contains data"
            print_warning "Wings will be restarted with the existing configuration"
            return 0
        fi
        
        sudo touch /etc/pelican/config.yml
        sudo chmod 600 /etc/pelican/config.yml
        
        print_success "Empty configuration file created at /etc/pelican/config.yml"
        echo ""
        echo "Please follow these steps to manually configure Wings:"
        echo ""
        echo "1. Go to your Pelican Panel"
        echo "2. Navigate to Nodes"
        echo "3. Create a new Node or select your existing Node"
        echo "4. Go to the 'Configuration' tab"
        echo "5. Copy the entire configuration file content"
        echo "6. Edit the file: sudo nano /etc/pelican/config.yml"
        echo "7. Paste your configuration content and save"
        echo ""
        print_warning "After adding the configuration, you can:"
        echo "   - Run this script again to enable and start Wings service"
        echo "   - Or manually enable the service with:"
        echo "     sudo systemctl enable --now wings"
        echo "     sudo systemctl restart wings"
        echo ""
        
    else
        echo "Create a Node in your Pelican Panel and go to \"Configuration File\" to create an Auto Deploy Command."
        echo ""
        printf "What is your Auto Deploy Command?: "
        read AUTO_DEPLOY_CMD < /dev/tty
        
        if [[ -z "$AUTO_DEPLOY_CMD" ]]; then
            print_error "Auto Deploy Command cannot be empty"
            exit 1
        fi
        
        bash -c "$AUTO_DEPLOY_CMD"
        
        print_success "Wings configured successfully"
    fi
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
    
    if [[ "$alternate" == true ]]; then
        if [[ -f /etc/pelican/config.yml ]] && [[ -s /etc/pelican/config.yml ]]; then
            print_success "Configuration file found with content - enabling and starting Wings"
            sudo systemctl enable --now wings
            sudo systemctl restart wings
        else
            print_warning "Empty configuration file detected"
            print_warning "Wings service will be created but not started until configuration is added"
            sudo systemctl enable wings
            return 0
        fi
    else
        sudo systemctl enable --now wings
    fi
    
    print_success "Wings service enabled and started"
}

display_completion() {
    print_status "Finished Wings Installation!"
    echo ""
    
    if [[ "$alternate" == true ]]; then
        if [[ -f /etc/pelican/config.yml ]] && [[ -s /etc/pelican/config.yml ]]; then
            print_success "Pelican Wings installation and configuration completed successfully!"
            echo ""
            print_warning "Wings is now running and will automatically start on boot"
        else
            print_success "Pelican Wings installation completed!"
            echo ""
            print_warning "Configuration file created but is empty"
            print_warning "Wings service is created but not started yet"
            echo ""
            print_warning "Next steps:"
            echo "   1. Add your configuration to: /etc/pelican/config.yml"
            echo "   2. Run this script again to start Wings"
            echo "   3. Or manually start with: sudo systemctl enable --now wings && sudo systemctl restart wings"
        fi
    else
        print_success "Pelican Wings installation completed successfully!"
        echo ""
        print_warning "Wings is now running and will automatically start on boot"
    fi
    
    echo ""
    print_warning "Useful commands:"
    echo "   Check status: sudo systemctl status wings"
    echo "   View logs: sudo journalctl -u wings -f"
    echo "   Restart service: sudo systemctl restart wings"
}

main() {
    check_root
    detect_os
    
    if check_wings_installation; then
        show_management_panel
        exit 0
    fi
    
    echo -e "${BLUE}--------PELICAN WINGS INSTALLATION SCRIPT--------${NC}"
    echo -e "${GREEN}Made by: Verdanox${NC}"
    
    if [[ "$alternate" == true ]]; then
        echo -e "${YELLOW}Running in ALTERNATE MODE${NC}"
    fi
    
    echo ""
    
    print_warning "Installing Pelican Wings on your server..."
    print_warning "Operating System: $OS $VERSION"
    echo ""
    
    if [[ "$alternate" == true ]] && [[ -f /etc/pelican/config.yml ]] && [[ -s /etc/pelican/config.yml ]]; then
        print_status "Re-run detected with existing configuration"
        if [[ -f /usr/local/bin/wings ]] && [[ -f /etc/systemd/system/wings.service ]]; then
            print_success "Wings already installed, restarting service..."
            sudo systemctl enable --now wings
            sudo systemctl restart wings
            display_completion
            exit 0
        fi
    fi
    
    install_docker
    install_wings
    setup_wings
    create_service
    enable_wings
    display_completion
}

main "$@"
