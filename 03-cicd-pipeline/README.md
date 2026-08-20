Trigger: push a una rama (o a un tag) en el repo
Build: construir la imagen Docker del backend Flask
Push: subir la imagen a Docker Hub (ya usas rcastro95/portfolio-backend) con un tag automático (por ejemplo, el hash corto del commit — resolviendo además esa duda que tuvimos hace tiempo sobre "cómo saber qué versión estoy viendo")
Deploy: actualizar terraform.tfvars o el startup-script.sh con el nuevo tag, y ejecutar terraform apply contra Fase B — aprovechando el canary que ya construiste, para que el despliegue sea progresivo y sin downtime

*El pipeline debe ejecutar el terraform apply automáticamente (CD completo)
*Antes de que lo dejes anotado, un apunte para cuando lo retomes: para el terraform apply automático desde GitHub Actions vas a necesitar las credenciales de GCP como secrets del repositorio (no la clave JSON tradicional si quieres mantener el mismo enfoque de seguridad que ya usaste con impersonation — GitHub Actions soporta Workload Identity Federation para autenticarse sin claves estáticas, que sería coherente con todo el criterio de seguridad que ya has aplicado en este portfolio).