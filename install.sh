install_tracer()
{
    server="$1" 
    echo "Installing Aiursoft Tracer to domain $server."
    set -x
    cd ~

    # Valid domain is required
    if [[ "$server" == "" ]]; then
        echo "You must specify your server domain. Try execute with 'bash -s www.a.com'"
        return 9
    fi

    # Enable BBR
    echo "Enabling BBR..."
    echo 'net.core.default_qdisc=fq' | tee -a /etc/sysctl.conf
    echo 'net.ipv4.tcp_congestion_control=bbr' | tee -a /etc/sysctl.conf
    sysctl -p

    # Install basic packages
    echo "Installing packages..."
    wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
    dpkg -i packages-microsoft-prod.deb
    echo "deb [trusted=yes] https://apt.fury.io/caddy/ /" | tee -a /etc/apt/sources.list.d/caddy-fury.list
    apt update
    apt upgrade -y
    apt install -y apt-transport-https curl git vim dotnet-sdk-3.1 caddy
    apt autoremove -y

    # Download the source code
    echo 'Downloading the source code...'
    git clone https://github.com/AiursoftWeb/Tracer.git

    # Build the code
    echo 'Building the source code...'
    tracer_path="$(pwd)/app"
    dotnet publish -c Release -o $tracer_path ./Tracer/Tracer.csproj

    # Register tracer service
    echo "Registering Tracer service..."
    echo "[Unit]
    Description=Tracer Service
    After=network.target
    Wants=network.target

    [Service]
    Type=simple
    ExecStart=/usr/bin/dotnet $tracer_path/Tracer.dll
    Restart=on-failure
    RestartPreventExitStatus=23

    [Install]
    WantedBy=multi-user.target" > /etc/systemd/system/tracer.service
    systemctl enable tracer.service
    systemctl start tracer.service

    # Config caddy
    echo 'Configuring the web proxy...'
    echo "$server

root * $tracer_path/wwwroot
file_server

reverse_proxy /* 127.0.0.1:5000
    " > /etc/caddy/Caddyfile
    systemctl restart caddy.service

    # Finish the installation
    echo "Successfully installed Tracer as a service in your machine! Please open https://$server to try it now!"
    echo "Strongly suggest to reboot the machine!"
}

install_tracer "$@"