#!/bin/bash

# Colores para la salida
PURPLE='\033[0;35m' # intervención del usuario
GREEN='\033[0;32m' # correcto
RED='\033[0;31m' # error
NC='\033[0m' # Sin color

# Verificar si las herramientas necesarias están instaladas
function check_requerimientos() {
    echo -e "${GREEN}Verificando herramientas necesarias...${NC}"
    for tool in git docker; do
        if ! command -v $tool &> /dev/null; then
            echo -e "${RED}Error: ${tool} no está instalado.${NC}"
            exit 1
        fi
    done
}

# Verificar si Docker está en ejecución
function check_docker_running() {
    echo -e "${GREEN}Verificando si Docker está en ejecución...${NC}"
    if ! docker info &> /dev/null; then
        echo -e "${RED}Error: Docker no está en ejecución.${NC}"
        exit 1
    else
        echo -e "${GREEN}Docker está en ejecución.${NC}"
    fi
}

# Iniciar el servicio Docker
function start_docker() {
    echo -e "${GREEN}Iniciando Docker...${NC}"
    sudo systemctl start docker
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Docker ha sido iniciado correctamente.${NC}"
    else
        echo -e "${RED}Error al iniciar Docker.${NC}"
        exit 1
    fi
}

# Detener Docker y eliminar el contenedor en curso
function stop_docker() {
    echo -e "${GREEN}Deteniendo Docker y eliminando el contenedor en ejecución...${NC}"
    
    # Eliminar el contenedor en ejecución
    container_id=$(docker ps -q)
    if [ -n "$container_id" ]; then
        echo -e "${GREEN}Eliminando contenedor ${container_id}...${NC}"
        docker stop $container_id
        docker rm $container_id
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Contenedor detenido y eliminado.${NC}"
        else
            echo -e "${RED}Error al detener o eliminar el contenedor.${NC}"
            exit 1
        fi
    else
        echo -e "${RED}No hay contenedores en ejecución.${NC}"
    fi

    # Detener el servicio Docker
    sudo systemctl stop docker
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Docker ha sido detenido correctamente.${NC}"
    else
        echo -e "${RED}Error al detener Docker.${NC}"
        exit 1
    fi
}

# Verificar si es un repositorio Git
function is_git_repo() {
    if ! git rev-parse --is-inside-work-tree &> /dev/null; then
        echo -e "${RED}Error: El directorio actual no es un repositorio Git.${NC}"
        exit 1
    fi
}

# Obtener el nombre del repositorio y la rama actual
function get_repo_info() {
    repo_name=$(basename `git rev-parse --show-toplevel 2>/dev/null` || echo "desconocido")
    branch_name=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "desconocida")
    echo "Repositorio: $repo_name"
    echo "Rama: $branch_name"
}

# Obtener el último commit (autor y correo)
function get_last_commit_info() {
    author=$(git log -1 --pretty=format:'%an' 2>/dev/null || echo "desconocido")
    email=$(git log -1 --pretty=format:'%ae' 2>/dev/null || echo "desconocido")
    echo "Último commit por: $author <$email>"
}

# Obtener la versión actual del proyecto
function get_version() {
    if [ -f package.json ]; then
        version=$(jq -r '.version' package.json)
    elif [ -f CHANGELOG.md ]; then
        version=$(grep -Eo 'v[0-9]+\.[0-9]+\.[0-9]+' CHANGELOG.md | head -n 1)
    else
        version=$(git describe --tags --always 2>/dev/null || echo "desconocida")
    fi
    echo "Versión del proyecto: $version"
}

# Construir la imagen Docker
function build_docker_image() {
    if [[ -z "$repo_name" ]]; then
        echo -e "${RED}Error: No se pudo obtener el nombre del repositorio.${NC}"
        exit 1
    fi
    image_name="${repo_name}:latest"
    echo -e "${GREEN}Construyendo imagen Docker ${image_name}...${NC}"
    docker build -t $image_name . || exit 1
}

# Simulación de despliegue con detalles
function deploy_simulation() {
    echo -e "${GREEN}Simulando despliegue...${NC}"
    
    # Solicitar al usuario que ingrese el puerto
    echo -e "${PURPLE}Ingrese el puerto en el que desea exponer la aplicación:${NC}"
    read user_port

    # Ejecutar el contenedor y capturar su ID
    container_id=$(docker run -d -p ${user_port}:80 "${repo_name}:latest")

    # Verificar si el contenedor se ejecutó correctamente
    if [ $? -eq 0 ]; then
        echo -e "✔ Despliegue exitoso: Contenedor ${container_id}" >> $log_file
        echo -e "${GREEN}✔ Despliegue exitoso: Contenedor ${container_id}${NC}"
    else
        echo -e "${RED}✖ Error en el despliegue${NC}"
        echo -e "✖ Error en el despliegue" >> $log_file
        exit 1
    fi
}


# Logging
function crear_log() {
    log_file="deployment.log"
    
    # Escribir encabezado y detalles de la versión y repositorio
    echo -e "╔════════════════════════════════════════╗" > $log_file
    echo -e "║         📝 DEPLOYMENT LOG              ║" >> $log_file
    echo -e "╚════════════════════════════════════════╝" >> $log_file
    
    echo -e "🔹 Fecha: $(date)" >> $log_file
    echo -e "🔹 Versión: $version" >> $log_file
    echo -e "🔹 Repositorio: $repo_name" 
    echo -e "🔹 Rama: $branch_name" >> $log_file
    
    # Último commit
    echo -e "  ╔══════════════════════════════════════╗" >> $log_file
    echo -e "  ║    Último Commit                     ║" >> $log_file
    echo -e "  ╚══════════════════════════════════════╝" >> $log_file
    echo -e "🔹 Autor: $author <$email>" >> $log_file

    # Información de despliegue
    echo -e "  ╔══════════════════════════════════════╗" >> $log_file
    echo -e "  ║    Resultado del Despliegue          ║" >> $log_file
    echo -e "  ╚══════════════════════════════════════╝" >> $log_file
    echo -e "✔ Despliegue simulado: Sí" >> $log_file

    # Separador final
    echo -e "\n════════════════════════════════════════════" >> $log_file
}

# Manejo de comandos
case $1 in
    docker)
        check_requerimientos
        start_docker
        is_git_repo
        get_repo_info
        get_last_commit_info
        get_version
        build_docker_image
        deploy_simulation
        crear_log
        ;;
    stop)
        check_requerimientos
        check_docker_running
        stop_docker
        ;;
    *)
        echo -e "${RED}Uso: $0 {docker|stop}${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}Proceso completado. Revisa deployment.log para más detalles.${NC}"
