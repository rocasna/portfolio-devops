# Se utiliza una versión estable de Python Alpine
FROM python:3.12-alpine3.19

# Instalar dependencias del sistema
RUN apk add --no-cache gcc musl-dev linux-headers libffi-dev

# Crear y establecer el directorio de trabajo
WORKDIR /app

# Copiar requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copiar el código fuente
COPY app.py ./app.py

# Asegurar los permisos correctos para el usuario sin privilegios
RUN chown -R nobody:nogroup /app

# Definir variables de entorno limpias para evitar fugas a directorios root
ENV TMPDIR=/tmp
ENV HOME=/tmp

# Exponer el puerto de la app
EXPOSE 5000

USER nobody:nogroup

# Comprobar el estado de salud interno en Alpine con el puerto correcto
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://127.0.0.1:5000/health || exit 1

CMD ["gunicorn", "--worker-class", "gevent", "--bind", "0.0.0.0:5000", "app:app"]
