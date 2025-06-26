# Code Server DevBox

---

Este repositorio contiene una imagen personalizada basada en `devcontainers/base:jammy` con las siguientes herramientas preinstaladas:

- Docker (vía socket del host)
- Terraform 1.6.6
- Terragrunt 0.56.3
- AWS CLI v2
- Node.js 18
- Python 3 + pip
- LocalStack CLI
- Code Server con extensiones:
    - ms-python.python
    - hashicorp.terraform
    - 4ops.terraform

## ✨ Objetivo

Proveer un entorno de desarrollo completo para cada alumno, desplegado en su propia instancia EC2.

## 🛠 Estructura del proyecto

```
.
├── Dockerfile
├── settings.json        # Configuración por defecto para Code Server
└── README.md
```

---

## ⛏ Construcción y Publicación de la Imagen

```bash
# Build local
docker build -t yosoyfunes/code-server-devbox:v1 .

# Push a Docker Hub
docker push yosoyfunes/code-server-devbox:v1
```

---

## ⚙ Lanzamiento en una instancia EC2

### 1. Instalar Docker en EC2 con Ubuntu

```bash
sudo apt update && sudo apt install -y docker.io
sudo usermod -aG docker $USER
newgrp docker
```

### 1.1 Instalar Docker en EC2 con Amazon 2023

```bash
# Amazon Linux 2
sudo yum update -y
sudo amazon-linux-extras enable docker
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user
newgrp docker
```

### 2. Crear volumen

```bash
docker volume create code-server-data
```

### 3. Ejecutar Code Server

```bash
docker run -d \
  --name code-server \
  -p 8080:8080 \
  -e PASSWORD=devcontainer \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v code-server-data:/home/vscode/.local/share/code-server \
  -w /workspaces/project \
  yosoyfunes/code-server-devbox:v1 code-server /workspaces/project
```
> **Nota:** Es importante agregar `code-server /workspaces/project` al final del comando para iniciar el servidor apuntando a la carpeta de trabajo.

### 3.1 Abrir Code Server en la carpeta actual

```bash
docker run -d \
  --name code-server \
  -p 8080:8080 \
  -e PASSWORD=devcontainer \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v code-server-data:/home/vscode/.local/share/code-server \
  -v "$PWD":/workspaces/project \
  -w /workspaces/project \
  yosoyfunes/code-server-devbox:v1 code-server /workspaces/project
```
> **Nota:** Recuerda incluir `code-server /workspaces/project` al final para que el servidor se inicie correctamente en la carpeta deseada.

### 3.2 Usar docker-compose

Puedes lanzar el entorno usando `docker-compose` con el archivo incluido en este repositorio:

```bash
docker-compose up -d
```

> **Nota:** El servicio está configurado para iniciar automáticamente `code-server /workspaces/project` como comando principal, apuntando a la carpeta de trabajo.

---

## 🔒 Acceso

- URL: `http://<IP-EC2>:8080`
- Contraseña por defecto: `devcontainer`
---
