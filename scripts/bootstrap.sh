#!/usr/bin/env bash
set -euo pipefail

ID=""
VERSION=""
case "$(uname -s)" in
    Linux)
        if [[ -f /etc/os-release ]]; then
            eval "$(grep -E '^(ID|VERSION_ID)=' /etc/os-release | sed 's/VERSION_ID/VERSION/g')"
        fi
        ;;
esac

echo "OS: ${ID:-unknown} ${VERSION:-unknown}"

if ! command -v docker &>/dev/null; then
    echo "Installation de Docker..."
    case "$ID" in
        ubuntu|debian)
            apt-get update
            apt-get install -y \
                ca-certificates curl gnupg lsb-release
            install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/$ID/gpg | \
                gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
                https://download.docker.com/linux/$ID $(lsb_release -cs) stable" > \
                /etc/apt/sources.list.d/docker.list
            apt-get update
            apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
        fedora|rhel|centos|rocky|almalinux)
            dnf install -y dnf-plugins-core
            dnf config-manager --add-repo https://download.docker.com/linux/$ID/docker-ce.repo
            dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
        *)
            echo "Distribution non supportée: $ID"
            exit 1
            ;;
    esac

    mkdir -p /etc/docker
    if [[ ! -f /etc/docker/daemon.json ]]; then
        cat > /etc/docker/daemon.json <<'EOFJSON'
{
    "ip-forward": true,
    "ip-masq": true,
    "iptables": true,
    "bridge": "docker0",
    "default-network": "bridge",
    "userland-proxy": true
}
EOFJSON
    fi

    systemctl enable docker
    systemctl start docker
fi

echo "Docker prêt"
