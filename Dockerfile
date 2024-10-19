# Usamos la imagen base de Nginx
FROM nginx:alpine

# Copiamos los archivos del proyecto al directorio de Nginx
COPY nova-v1 /usr/share/nginx/html

# Exponemos el puerto 80
EXPOSE 80

# Iniciamos Nginx
CMD ["nginx", "-g", "daemon off;"]
