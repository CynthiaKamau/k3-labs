#!/bin/bash
sudo apt update -y && sudo apt upgrade -y && sudo apt install -y curl vim jq git make docker.io unzip
sudo usermod -aG docker ubuntu
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)"
curl -sfL https://get.k3s.io | \
        K3S_TOKEN=wibble \
        INSTALL_K3S_CHANNEL=latest \
        INSTALL_K3S_EXEC="server --disable=traefik" \
        sh -