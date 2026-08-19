# 02-terraform-module — Infraestructura en GCP con Terraform

Proyecto de portfolio que despliega la misma aplicación Flask del proyecto anterior 
(01-k8s-app), pero esta vez sobre una VM en Google Cloud Platform, con foco en la 
construcción de la infraestructura mediante Terraform: módulos reutilizables, red 
privada, autenticación sin contraseñas (IAM Database Authentication) y una base de 
datos Cloud SQL conectada de forma segura.

Internet
  │
  ├── HTTP/HTTPS (0.0.0.0/0) ──► Firewall (allow-web) ──► VM (Flask + Cloud SQL Connector)
  │                                                              │
  └── SSH vía IAP (35.235.240.0/20) ──► Firewall (allow-iap-ssh) ─┘
                                                                  │
                                                          Cloud NAT (salida a internet)
                                                                  │
                                            VPC privada ──► Peering (/24) ──► Cloud SQL (IP privada, IAM Auth)

### 1. Estructura de módulos reutilizables (environments/modules)

Se optó por separar la infraestructura en módulos reutilizables (`network`, `compute`, 
`sql`) independientes del entorno concreto, y una carpeta `environments/dev` que los 
orquesta con sus propios valores.

Esta separación responde a una práctica que utilizo de forma profesional: mantiene la 
estructura de carpetas limpia y fácil de entender, y permite escalar a múltiples entornos 
sin duplicar lógica. Para añadir un entorno nuevo (por ejemplo, `prod`), bastaría con:

- Copiar la carpeta `environments/dev` a `environments/prod`
- Ajustar `terraform.tfvars` con los valores específicos del nuevo entorno
- Configurar el `gcloud config configuration` correspondiente
- Ajustar los permisos IAM/proyecto según corresponda

Los módulos en sí no cambian — solo cambian los valores que se les pasan desde cada entorno.

### 2. Separación de firewall: IAP para SSH vs público para web

Se crearon dos reglas de firewall independientes en lugar de una única regla genérica:

- **allow-iap-ssh**: permite tráfico TCP al puerto 22 únicamente desde el rango de IPs 
  de Identity-Aware Proxy (`35.235.240.0/20`).
- **allow-web**: permite tráfico TCP a los puertos 80/443 desde cualquier origen 
  (`0.0.0.0/0`), necesario porque el sitio debe ser accesible públicamente.

**Por qué IAP en vez de SSH tradicional:** con IAP, el puerto 22 nunca queda expuesto 
directamente a internet. La conexión se realiza a través de un túnel autenticado con la 
identidad IAM del usuario, como si se accediera desde la propia red interna de GCP. Esto 
elimina la superficie de ataque típica de un puerto SSH abierto (escaneos automatizados, 
intentos de fuerza bruta, bots), sin sacrificar la capacidad de administrar la VM.

### 3. IAM Database Authentication en Cloud SQL

En lugar de usuario y contraseña tradicional, la instancia de Cloud SQL se configuró con 
IAM Database Authentication: la Service Account de la VM se autentica contra la base de 
datos usando su propia identidad IAM, sin necesidad de gestionar ni almacenar ninguna 
contraseña.

Esta es la práctica recomendada por Google para este escenario, y es una funcionalidad 
que no había utilizado antes en profundidad — se aprovechó este proyecto para probarla 
de extremo a extremo: desde la configuración del flag `cloudsql_iam_authentication` en 
la instancia, hasta la conexión real desde la aplicación Flask usando el Cloud SQL Python 
Connector con `enable_iam_auth=True`.

### 4. Endpoint /db-status: verificación de conectividad con Cloud SQL

Se añadió un endpoint `/db-status` a la aplicación Flask que realiza una comprobación 
real de conectividad contra la instancia de Cloud SQL — a modo de health check específico 
de base de datos, similar en propósito al `/health` general, pero verificando que desde 
la VM se puede llegar realmente a la instancia y autenticarse contra ella.

**Por qué el conector oficial (Cloud SQL Python Connector) en vez de un driver tradicional:** 
al usar IAM Database Authentication, la conexión no puede hacerse con usuario/contraseña 
convencional. El conector de Google gestiona automáticamente la autenticación IAM (el 
token de la identidad de la VM) y la resolución de la conexión contra la instancia, sin 
necesidad de exponer ni gestionar credenciales. Además, permite indicar explícitamente 
el uso de la IP privada (`IPTypes.PRIVATE`), necesario porque la instancia no tiene IP 
pública configurada.

## Cómo desplegar y probar

1. Clonar el repositorio y posicionarte en el entorno:
\`\`\`bash
cd 02-terraform-module/fase-A/environments/dev
\`\`\`

2. Inicializar Terraform (descarga providers y conecta con el backend remoto en GCS, 
donde se guarda el state de la infraestructura):
\`\`\`bash
terraform init
\`\`\`

3. Revisar qué recursos se van a crear:
\`\`\`bash
terraform plan
\`\`\`

4. Aplicar y crear la infraestructura:
\`\`\`bash
terraform apply
\`\`\`
Entre los outputs se mostrará la IP pública de la VM — desde ahí se accede directamente 
a la aplicación.

5. Conectar a la VM por SSH (a través de IAP, sin exponer el puerto 22):
\`\`\`bash
gcloud compute ssh dev-terraform-module-instance --tunnel-through-iap
\`\`\`

6. Una vez dentro, se puede consultar `/startup-script.log` para ver la salida completa 
del script de arranque (instalación de Docker, despliegue de la app, configuración del 
Cloud SQL Auth Proxy).

7. Para verificar la conexión con la base de datos, visitar en el navegador:
\`\`\`
http://<IP_PUBLICA>/db-status
\`\`\`
Debería devolver `{"status": "conectado", "resultado": 1}` si todo funciona correctamente.crear 

## Qué haría diferente en producción

- **CI/CD automatizado**: conectar el repositorio a Cloud Build para que los despliegues 
  (build de la imagen, push a registro, actualización de infraestructura) se disparen 
  automáticamente en cada cambio, en vez de ejecutar los pasos manualmente.
- **Escalabilidad**: sustituir la VM única con IP pública por un Managed Instance Group 
  (MIG), detrás de un Network Endpoint Group (NEG) y un Load Balancer, permitiendo 
  escalado horizontal real en vez de depender de una sola instancia.
- **CDN**: añadir Cloud CDN para contenido estático, reduciendo latencia y carga sobre 
  el backend.
- **Cloud Armor**: proteger el Load Balancer con reglas WAF/rate-limiting, mitigando 
  ataques comunes (OWASP Top 10, fuerza bruta, DDoS básico) antes de que el tráfico 
  llegue a la aplicación.

## Limitaciones conocidas

- **Permisos de la SA de Terraform demasiado amplios**: `terraform-admin` tiene el rol 
  `roles/resourcemanager.projectIamAdmin`, necesario para que la gestión de bindings IAM 
  sea 100% reproducible vía Terraform. En un entorno real, esto se ajustaría creando un 
  rol personalizado con los permisos mínimos desgranados uno a uno — más tedioso de 
  configurar, pero mucho más seguro.
- **Sin TLS/HTTPS**: el tráfico web viaja en HTTP plano. Sin llegar a montar un Load 
  Balancer completo, una mejora aplicable incluso en este entorno sería instalar Nginx 
  como proxy inverso delante de la app, con Let's Encrypt para obtener un certificado.
- **Sin CI/CD**: los despliegues se ejecutan manualmente. Podría implementarse ya, 
  incluso sin ser un entorno de producción.
- **Sin monitorización activa**: no hay alertas configuradas ante caídas de la VM o del 
  contenedor. Se podría mejorar la resiliencia configurando un `systemd` (o ajustando la 
  política de reinicio del contenedor Docker) para que ante una caída se levante 
  automáticamente, junto con alertas que avisen si el servicio deja de responder.
- **Instancia única sin alta disponibilidad**: tanto la VM como Cloud SQL son instancias 
  únicas (`ZONAL`), sin réplicas ni failover automático.