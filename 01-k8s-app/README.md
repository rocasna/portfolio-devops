# 01-k8s-app — Backend + Frontend en Kubernetes

Proyecto de portfolio que despliega una aplicación sencilla (backend en Flask + frontend 
estático servido con Nginx) en un clúster de Kubernetes local (MicroK8s), con imágenes 
publicadas en Docker Hub. Foco en buenas prácticas de despliegue: seguridad (contenedores 
no-root), health checks reales vía HTTP, e autoscaling horizontal (HPA) verificado con carga real.

## Arquitectura

Cliente
  │
  ▼
Ingress (fase2.local)
  ├── /api  → Service-backend  → Deployment-backend (Flask, :5000)
  └── /     → Service-frontend → Deployment-frontend (Nginx, :80)

### 1. Separación Frontend/Backend en deployments independientes

Se optó por separar frontend y backend en Deployments independientes, replicando un patrón 
habitual en proyectos reales con equipos de tecnologías distintas:

- **Independencia de equipos**: cada parte (frontend/backend) puede desarrollarse, desplegarse 
  y optimizarse sin afectar a la otra.
- **Aislamiento de fallos**: si un componente falla, el otro sigue funcionando de forma 
  independiente.
- **Escalado selectivo**: al tener recursos separados (Deployments, Services, HPA propios), 
  se puede escalar únicamente el componente que lo necesita, sin sobredimensionar el otro.

### 2. Seguridad: contenedores no-root

Ambas imágenes (backend y frontend) se ejecutan con un usuario sin privilegios (`nobody`, 
UID 65534), en lugar de root. Esto es una buena práctica de seguridad estándar: si un 
atacante llegara a comprometer el contenedor, un usuario no-root reduce significativamente 
la superficie de ataque disponible dentro del propio contenedor.

**Problema real encontrado:** al pasar el backend a usuario no-root, Gunicorn fallaba al 
arrancar con el error `Permission denied: '/.gunicorn`. La causa: Gunicorn intenta crear 
su socket de control dentro de `$HOME`, y como el usuario `nobody` no tiene `HOME` definido 
(por defecto apunta a `/`), no tenía permisos de escritura ahí.

**Solución:** definir `ENV HOME=/tmp` en el Dockerfile, redirigiendo esa ruta a un directorio 
con permisos de escritura para el usuario no-root.

Para el frontend (Nginx), se añadió además la capability `NET_BIND_SERVICE`, necesaria para 
que un usuario no-root pueda bindear al puerto 80 (por debajo de 1024, reservado tradicionalmente 
para root).

### 3. Probes: httpGet vs tcpSocket

Las probes de liveness y readiness usan `httpGet` contra el endpoint `/health` del backend, 
en lugar de `tcpSocket` sobre el puerto.

Se probó también con `tcpSocket` para comparar, pero se descartó: `tcpSocket` solo verifica 
que el puerto esté abierto y acepte conexiones, no que la aplicación esté respondiendo 
correctamente. Esto genera falsos positivos, un proceso puede tener el puerto abierto pero 
estar colgado, bloqueado, o en un estado interno defectuoso, y `tcpSocket` lo reportaría 
como "sano" igualmente.

Con `httpGet` a `/health`, Kubernetes valida que la aplicación responde de forma activa con 
un código HTTP 2xx, lo cual es una comprobación de salud real, no solo de conectividad de red.

### 4. HPA: umbral de CPU y validación con carga real

El HPA está configurado con un umbral de `averageUtilization: 50%` sobre la CPU solicitada 
(`requests.cpu`). Este valor se eligió deliberadamente bajo para esta demo, con el fin de 
observar el escalado con mayor rapidez y claridad al generar carga.

**No es un valor "óptimo" universal.** En un escenario real, el umbral debería ajustarse 
según el comportamiento observado de la aplicación bajo carga: un valor habitual de referencia 
suele rondar el 70-75%, pero el número correcto depende de cómo se comporte cada aplicación 
en concreto a esos niveles. La metodología correcta sería: probar la app bajo distintos niveles 
de CPU, identificar a partir de qué punto el rendimiento se degrada, y fijar el umbral con 
margen de seguridad por debajo de ese punto — nunca al límite exacto.

**Prueba realizada:** se generó carga real de CPU dentro del pod del backend, ejecutando un 
bucle intensivo directamente en el contenedor (`while true; do :; done`). El HPA reaccionó 
correctamente, escalando de 1 a 8 réplicas cuando la CPU superó el umbral (llegando a 
140-150% de utilización), y redujo las réplicas gradualmente tras cesar la carga, respetando 
el `stabilizationWindowSeconds` por defecto de Kubernetes (5 minutos) antes del scale-down, 
para evitar oscilaciones bruscas.

## Cómo desplegar y probar

Desde el directorio `01-k8s-app/k8s`:

\`\`\`bash
kubectl apply -f .
\`\`\`

El clúster tarda aproximadamente 2-3 minutos en tener todos los recursos disponibles y en estado `Running`.

Para probar el autoscaling (HPA), generar carga dentro de un pod del backend:

\`\`\`bash
kubectl exec -it <nombre-pod-backend> -- /bin/sh -c "while true; do :; done"
\`\`\`

Y observar el comportamiento del HPA en otra terminal:

\`\`\`bash
kubectl get hpa -w
\`\`\`

## Qué haría diferente en producción

- Ajustar `resources` (requests/limits) según medición real de consumo, no valores estimados.
- Usar un registro de imágenes privado (actualmente las imágenes están en Docker Hub público, 
  algo aceptable para portfolio pero no para producción).
- Aumentar el número mínimo/máximo de réplicas en Deployments y HPA (backend y frontend), 
  ajustado a tráfico real esperado.
- Desplegar en un clúster gestionado (GKE), con dominio/subdominio real y certificados TLS 
  (HTTPS debería ser obligatorio en cualquier entorno, no solo producción).
- Namespaces dedicados por entorno (dev/staging/prod) desde el primer momento.
- Evaluar imágenes base más ligeras/optimizadas para reducir tamaño y superficie de ataque.
- Página de error o redirección a `/` para rutas del backend accedidas incorrectamente desde 
  fuera (por ejemplo, `/api/health` o `/api/data` accedidas sin contexto).
- Labels consistentes en todos los recursos de Kubernetes desde el minuto uno (facilita 
  filtrado, monitorización y gestión a escala).
- Configurar cabeceras de seguridad en Nginx (CSP, X-Frame-Options, X-Content-Type-Options, 
  etc.) para mitigar ataques como XSS o clickjacking, no implementado aquí por tratarse de 
  un frontend estático simple, pero sería obligatorio en un entorno real.

## Limitaciones conocidas

- Entorno de pruebas local (MicroK8s), no un clúster gestionado ni con las garantías de 
  disponibilidad de un entorno cloud real.
- Sin TLS/HTTPS configurado (tráfico en HTTP plano).
- Imágenes publicadas en un registro público (Docker Hub), no privado.
- Sin namespaces ni labels estructurados, todo desplegado en el namespace `default`.
- Sin gestión de secrets porque la aplicación actual no maneja credenciales ni datos 
  sensibles; en un escenario real con base de datos o APIs externas, se gestionarían vía 
  Kubernetes Secrets o un gestor externo (Secret Manager, Vault).