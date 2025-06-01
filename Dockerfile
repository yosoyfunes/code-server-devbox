# Imagen base con zsh, sudo y entorno DevContainer compatible
FROM mcr.microsoft.com/devcontainers/base:jammy

ENV DEBIAN_FRONTEND=noninteractive
ENV PASSWORD=devcontainer

# Usuario base usado por DevContainers
USER root

# ---------------------------
# 1. Instalar herramientas
# ---------------------------
RUN apt-get update && apt-get install -y \
    unzip zip curl git gnupg lsb-release \
    python3 python3-pip \
    software-properties-common \
    sudo jq wget ca-certificates \
    nodejs npm \
    && apt-get clean

# ---------------------------
# 2. Instalar Terraform
# ---------------------------
RUN wget -q https://releases.hashicorp.com/terraform/1.6.6/terraform_1.6.6_linux_amd64.zip && \
    unzip terraform_1.6.6_linux_amd64.zip && \
    mv terraform /usr/local/bin/ && \
    rm terraform_1.6.6_linux_amd64.zip

# ---------------------------
# 3. Instalar Terragrunt
# ---------------------------
RUN wget -q https://github.com/gruntwork-io/terragrunt/releases/download/v0.56.3/terragrunt_linux_amd64 && \
    chmod +x terragrunt_linux_amd64 && mv terragrunt_linux_amd64 /usr/local/bin/terragrunt

# ---------------------------
# 4. Instalar AWS CLI v2
# ---------------------------
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && ./aws/install && rm -rf awscliv2.zip aws

# ---------------------------
# 5. Instalar LocalStack CLI
# ---------------------------
RUN pip3 install localstack awscli-local

# ---------------------------
# 6. Instalar code-server
# ---------------------------
RUN curl -fsSL https://code-server.dev/install.sh | sh

# ---------------------------
# 6.1 Instalar Docker CLI y configurar grupo docker
# ---------------------------
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/docker.gpg && \
    echo "deb https://download.docker.com/linux/ubuntu jammy stable" > /etc/apt/sources.list.d/docker.list && \
    apt-get update && apt-get install -y docker-ce-cli && \
    groupadd docker || true && usermod -aG docker vscode

# ---------------------------
# 7. Instalar extensiones VS Code
# ---------------------------
RUN code-server --install-extension ms-python.python \
    && code-server --install-extension hashicorp.terraform \    
    && code-server --install-extension 4ops.terraform

# ---------------------------
# 8. Configuración Final
# ---------------------------
WORKDIR /workspaces

# Crear carpetas necesarias
RUN mkdir -p /home/vscode/.config/code-server \
    && mkdir -p /home/vscode/.local/share/code-server/User

# Copiar configuración de Code Server y tema oscuro
COPY config.yaml /home/vscode/.config/code-server/config.yaml
COPY settings.json /home/vscode/.local/share/code-server/User/settings.json

# Asegurar permisos correctos
RUN chown -R vscode:vscode /home/vscode/.config /home/vscode/.local

# Cambiar al usuario vscode
USER vscode

# code-server escucha en el puerto 8080
EXPOSE 8080

CMD ["code-server"]