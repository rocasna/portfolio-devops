# 02-terraform-module — Fase B: Infraestructura escalable con Load Balancer, MIG y Cloud Armor

Esta fase resuelve la principal limitación de la Fase A: un único punto de fallo, sin
capacidad de escalar ante picos de tráfico. Se pasa de una infraestructura tradicional
(VM única, router para entrada/salida, y Cloud SQL) a una solución más escalable y
versátil, con un Load Balancer por delante, protección con Cloud Armor, un NEG que
distribuye tráfico hacia un Managed Instance Group (MIG) de VMs, y la misma Cloud SQL
con IAM Database Authentication.

## Por qué este cambio de arquitectura

Esta solución ayuda a resolver problemas de rendimiento de forma automática, al poder
configurar N instancias ante picos de peticiones sin intervención manual. Además, al usar
una Instance Template para levantar las VMs, el ciclo de actualizaciones se simplifica
notablemente: es más sencillo comprobar, revisar y testar cambios antes de desplegarlos
al conjunto completo.

No está todo configurado en esta fase (autoscaling dinámico, por ejemplo, queda pendiente),
pero esta arquitectura abre el abanico de posibilidades para escenarios reales:

- **Despliegues en paralelo**: desplegar una nueva versión en una instancia mientras el
  resto del MIG sigue sirviendo la versión actual, permitiendo validar cambios de forma
  progresiva antes de sustituir todas las instancias.
- **Separación lectura/escritura en base de datos**: Cloud SQL permite configurar una
  réplica de lectura junto a la instancia maestra, útil en proyectos concretos donde se
  quiere aislar carga de lectura de las operaciones de escritura.

Esto no es una lista exhaustiva de lo que permite esta arquitectura, pero refleja el tipo
de flexibilidad que se gana frente al enfoque de la Fase A.

## Arquitectura

```
Internet
  │
  ├── HTTP (0.0.0.0/0) ──► Cloud Armor (rate limiting) ──► Load Balancer (IP pública)
  │                                                              │
  │                                                        Backend Service + Health Check (/health)
  │                                                              │
  │                                                              ▼
  │                                              MIG (Instance Template) ──► VM(s) (Flask + Cloud SQL Connector)
  │                                                              │
  └── SSH vía IAP (35.235.240.0/20) ──► Firewall (allow-iap-ssh) ─┘
                                                                  │
                                                          Cloud NAT (salida a internet)
                                                                  │
                                            VPC privada ──► Peering (/24) ──► Cloud SQL (IP privada, IAM Auth)
```

## Decisiones técnicas clave

### 1. Módulos separados: loadbalancer y armor

Se optó por crear `modules/loadbalancer` y `modules/armor` como módulos independientes,
en lugar de integrar estos recursos dentro de `modules/compute`.

El resultado final de la infraestructura es el mismo independientemente de cómo se organice
el código, pero mantener cada responsabilidad en su propio módulo hace que la estructura
sea mucho más fácil de entender y de mantener: al mirar la carpeta `modules/`, queda claro
de un vistazo qué pieza de la infraestructura hace cada cosa, sin tener que leer el contenido
completo de un único módulo monolítico.

### 2. Firewall restringido: solo rangos de Google + IAP

Aunque las VMs del MIG solo tienen IP interna, es necesario permitir explícitamente el
puerto 80, que es el puerto real que usa el health check de GCP (protocolo HTTP) para
verificar el estado de las instancias — por defecto, los puertos no están abiertos, así
que hay que abrirlos específicamente hacia los rangos de origen de Google
(`130.211.0.0/22` y `35.191.0.0/16`), en lugar de a `0.0.0.0/0`. Esto reduce la superficie
de exposición: solo el propio sistema de health checks de Google puede alcanzar
directamente las VMs; el resto del tráfico público solo llega a través del Load Balancer.

**Sobre IAP para SSH:** al no existir una VM de salto (bastion) ni IP externa en las
instancias, la conexión SSH tradicional simplemente no es posible desde fuera de la VPC.
IAP resuelve esto sin necesidad de montar una VPN ni una VM bastion: crea un túnel
autenticado que verifica la identidad del usuario y sus roles IAM en cada conexión,
haciendo posible conectarse a una instancia sin IP pública como si se estuviera dentro
de la propia red interna de Google.

### 3. Cloud Armor: rate limiting verificado con tráfico real

Se configuró una política de Cloud Armor con una regla de limitación de tasa: 100
peticiones por minuto por IP, con la acción `throttle` (permite hasta el umbral, y
devuelve `429` al superarlo), además de una regla `allow` por defecto para el resto
del tráfico.

La regla se verificó con tráfico real, no solo se dio por buena tras el `apply`: se
lanzaron 150 peticiones en paralelo contra el Load Balancer en apenas 1-2 segundos. El
primer intento (peticiones secuenciales, más lentas) no activó el límite, lo cual llevó
a investigar el motivo — Cloud Armor necesita un tiempo de propagación real tras aplicar
una política nueva (varios minutos) antes de que las reglas surtan efecto en todos los
puntos de red de Google. Tras esperar y repetir la prueba con peticiones en paralelo
reales, el resultado fue: 8 peticiones con `200`, 142 con `429` — confirmando que el
rate limiting funciona correctamente una vez propagado.

### 4. Monitoring: uptime check y alerta por email sobre /db-status

Se añadió un uptime check de Cloud Monitoring que consulta `/db-status` cada 60 segundos,
junto con una política de alertas que notifica por email si el check falla. Esto cierra
una limitación que quedó anotada en el README de la Fase A ("sin monitorización activa"):
ahora, si la aplicación pierde la conexión con Cloud SQL, se recibe una notificación sin
depender de que alguien revise manualmente el estado del servicio.

Este chequeo es independiente del health check del Load Balancer (ver punto 5):
`/db-status` puede fallar y disparar una alerta sin que eso afecte a si la instancia
recibe tráfico HTTP normal — son dos capas de vigilancia con propósitos distintos.

### 5. Separación entre liveness (/health) y readiness de base de datos (/db-status)

Durante las pruebas de despliegue canary se detectó un problema real: inicialmente, el
health check del Load Balancer apuntaba a `/health`, y ese endpoint validaba también la
conexión a Cloud SQL. Como el Cloud SQL Auth Proxy tarda hasta 90 segundos en estar listo
tras el arranque de la VM, el Load Balancer marcaba la instancia como "no sana" durante
ese tiempo — es decir, downtime real, aunque la aplicación Flask ya estuviera arrancada
y respondiendo.

**Solución:** separar ambas responsabilidades.
- `/health` vuelve a ser un chequeo simple (solo confirma que Flask/Gunicorn responden,
  un `200 UP` inmediato, sin tocar la base de datos) — es el que usa el health check del
  Load Balancer para decidir si la instancia recibe tráfico.
- `/db-status` sigue validando la conexión real a Cloud SQL, pero su vigilancia se delega
  al uptime check + alerta de Cloud Monitoring, que notifica por email si la conexión a
  la base de datos falla — sin bloquear el tráfico HTTP normal mientras tanto.

Este patrón equivale a la distinción entre *liveness* y *readiness* que usan sistemas
como Kubernetes: un chequeo rápido decide si el tráfico llega a la instancia, y un
chequeo más profundo (y más lento) se vigila por separado, sin penalizar la disponibilidad
general de la app.

### 6. Despliegue canary sin downtime

Se verificó de forma empírica el comportamiento del canary durante un despliegue de nueva
versión: en la consola de GCP (Instance Templates), se observó que la nueva versión se
estaba creando mientras la instancia con la versión anterior seguía en pie y sirviendo
tráfico. En el backend service del Load Balancer, la versión antigua se mostraba como
"healthy" en todo momento, mientras que la nueva versión (canary) aparecía como no sana
hasta que la aplicación terminaba de levantarse dentro de ella. Solo cuando el canary pasó
su propio health check, el Load Balancer comenzó a enviarle tráfico también.

Combinado con un `target_size` mínimo de 2 instancias y la política de actualización
`PROACTIVE` con `max_unavailable_fixed = 0`, esto garantiza que en ningún momento del
despliegue la aplicación deja de estar disponible.

## Cómo desplegar y probar

1. Posicionarse en el directorio del entorno:
```bash
cd fase-B/environments/dev
```

2. Inicializar Terraform:
```bash
terraform init
```

3. Revisar qué recursos se van a crear:
```bash
terraform plan
```

4. Si todo está correcto, aplicar:
```bash
terraform apply
```

Al terminar, Terraform muestra los outputs de la infraestructura, entre ellos varios útiles
para verificar el despliegue:

```
application_name = "terraform-module"
db_connection_name = "fase-b-505318:europe-west1:dev-terraform-module-db"
db_private_ip = "10.9.187.3"
instance_group_manager_name = "dev-terraform-module-igm"
load_balancer_ip = "136.69.66.162"
project_id = "fase-b-505318"
target_size = 2
zone = "europe-west1-b"
```

5. Listar las instancias del proyecto (útil para obtener el nombre exacto de una VM, ya
que el MIG genera sufijos aleatorios):
```bash
gcloud compute instances list --project=fase-b-505318
```

6. Conectar por SSH a una instancia concreta, vía IAP (sin necesidad de IP pública ni
bastion):
```bash
gcloud compute ssh dev-terraform-module-instance-b8pf --tunnel-through-iap --zone=europe-west1-b --project=fase-b-505318
```

7. Visitar la aplicación a través del Load Balancer, usando el output `load_balancer_ip`:
```bash
curl http://136.69.66.162/health
curl http://136.69.66.162/db-status
```
El navegador también puede usarse directamente contra esa misma IP.

## Qué haría diferente en producción

- **Entornos consistentes**: los entornos (dev/staging/prod) deberían ser siempre iguales
  entre sí en estructura, evitando divergencias que generen sorpresas al promocionar cambios.
- **Autoscaling real**: configurar el autoescalado del MIG basado en métricas de CPU (u
  otras señales relevantes), en vez de un `target_size` fijo.
- **Mínimo de instancias más alto**: ajustar el mínimo aprovisionado según el tráfico
  esperado real, no solo el mínimo necesario para evitar downtime durante despliegues.
- **Alertas más completas**: no limitarse a la disponibilidad general de la app y la
  conexión a base de datos. En un proyecto real, sería importante monitorizar también
  procesos de negocio críticos — por ejemplo, un flujo de compra, el envío de un
  formulario, o el login — para detectar fallos específicos en esos puntos sensibles,
  además de vigilar los recursos que los sostienen (Cloud SQL, Memorystore, etc.).
- **CDN para contenido estático**: usar Cloud CDN para servir assets estáticos, reduciendo
  latencia y carga sobre el backend.
- **CI/CD real**: conectar el repositorio a Cloud Build para automatizar build, test y
  despliegue, en vez de ejecutar los pasos manualmente.
- **Cloud Armor más robusto**: ampliar las reglas más allá del rate limiting básico
  (por ejemplo, reglas OWASP predefinidas, bloqueo geográfico si aplica, o reglas
  específicas según los hallazgos de tráfico real).

Esta lista no es exhaustiva — el alcance real dependería del proyecto concreto, su
tráfico esperado, y su criticidad de negocio.

## Limitaciones conocidas

- **Sin TLS/HTTPS**: el tráfico viaja en HTTP plano. Faltaría crear un certificado para
  el dominio de la app y configurar TLS 1.2+ como mínimo en el Load Balancer.
- **Sin CI/CD**: los despliegues (incluido el uso del canary) se ejecutan manualmente.
- **Autoscaling manual**: el `target_size` del MIG es fijo, sin escalado automático
  basado en métricas de carga.
- **Cloud Armor básico**: la política solo incluye rate limiting; no hay reglas OWASP,
  bloqueo geográfico, ni reglas específicas basadas en patrones de tráfico real.
- **MIG en una única región**: todas las instancias están en `europe-west1`. Una
  arquitectura más resiliente distribuiría el MIG en varias regiones, con el Load
  Balancer dirigiendo el tráfico a la región más cercana al usuario y permitiendo que,
  si una región completa cae, otra siga respondiendo — algo que esta configuración
  actual no soporta.