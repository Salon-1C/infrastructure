# Despliegue en AWS (Terraform + GitHub Actions)

Guía para provisionar la infraestructura de **Blume** alineada con el diagrama C&C (Delivery 2) y publicar imágenes automáticamente en ECR/ECS.

## Arquitectura desplegada

| Componente | Servicio ECS | Imagen ECR |
|---|---|---|
| Blume-wa (Next.js) | `blume-wa` | `blume-wa` |
| Blume_business_logic_ms | `business-logic` | `blume-backend` |
| Blume_stream_ms + MediaMTX | `stream-engine` | `stream-engine` + `blume-mediamtx` |
| Blume_record_ms | `record-service` | `record-service` |
| Blume_Activities_ms | `activities-ms` | `activities-ms` |
| Blume_recommendation_ms | `recommendations-ms` | `recommendations-ms` |
| RabbitMQ | `rabbitmq` | imagen pública `rabbitmq:3.13-management` |
| MySQL negocio | RDS | — |
| MySQL grabaciones | RDS | — |
| PostgreSQL actividades | RDS | — |
| S3 grabaciones | bucket S3 | — |

Entrada HTTP: **ALB público** (rutas equivalentes a `traefik/dynamic.yml`).  
RTMP/WebRTC: **NLB público** (puertos 1935 y 8889).

---

## 1. Prerrequisitos

- Cuenta AWS con permisos de administrador (o equivalente para VPC, ECS, RDS, ECR, IAM, S3).
- [Terraform](https://developer.hashicorp.com/terraform/install) ≥ 1.6.
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configurado (`aws configure`).
- Repositorios del equipo en GitHub bajo la org **`Salon-1C`** (o ajusta `github_org` en `terraform.tfvars`).

### Backend remoto (primera vez)

Antes de `terraform init`, crea el bucket y la tabla de bloqueo (una sola vez):

```bash
aws s3api create-bucket \
  --bucket blume-tfstate \
  --region us-east-2 \
  --create-bucket-configuration LocationConstraint=us-east-2

aws dynamodb create-table \
  --table-name blume-tfstate-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-2
```

---

## 2. Aplicar Terraform

```bash
cd infrastructure
cp terraform.tfvars.example terraform.tfvars
# Edita terraform.tfvars con secretos y nombres únicos (bucket S3, URLs, etc.)
terraform init
terraform plan
terraform apply
```

Guarda los outputs:

```bash
terraform output github_deploy_role_arn
terraform output alb_dns_name
terraform output nlb_dns_name
terraform output ecs_services
```

Actualiza `public_app_url` en `terraform.tfvars` con la URL real del ALB (por ejemplo `http://blume-123456789.us-east-2.elb.amazonaws.com`) y vuelve a aplicar si cambiaste variables sensibles al runtime.

---

## 3. Imágenes iniciales en ECR

Tras el primer `apply`, los repositorios ECR existen pero están vacíos. Opciones:

1. **Empujar a `main`** en cada repo (workflows de la sección 4), o  
2. Build manual local:

```bash
AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
REGISTRY="${AWS_ACCOUNT}.dkr.ecr.us-east-2.amazonaws.com"
aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin "$REGISTRY"

# MediaMTX (desde infrastructure/)
docker build -f docker/mediamtx/Dockerfile -t "$REGISTRY/blume-mediamtx:latest" .
docker push "$REGISTRY/blume-mediamtx:latest"

# Repite build/push para cada microservicio según su Dockerfile...
```

Luego fuerza despliegue ECS:

```bash
aws ecs update-service --cluster blume --service business-logic --force-new-deployment
# ... resto de servicios
```

---

## 4. GitHub Actions — credenciales y secretos

### 4.1 Rol IAM (OIDC, sin access keys)

Terraform crea el rol `blume-github-deploy`. **No uses access keys** en GitHub; usa OIDC.

En **cada repositorio** de componente (y en `infrastructure` para MediaMTX):

| Nombre | Tipo | Valor |
|---|---|---|
| `AWS_ROLE_ARN` | Secret | Salida `github_deploy_role_arn` de Terraform |

**Settings → Secrets and variables → Actions → New repository secret**

### 4.2 Variables de repositorio (solo `blume_wa`)

| Nombre | Valor ejemplo |
|---|---|
| `PUBLIC_APP_URL` | `http://tu-alb.us-east-2.elb.amazonaws.com` |
| `STREAM_KEY` | Mismo valor que `stream_key` en `terraform.tfvars` (opcional) |

### 4.3 Permisos del workflow

Los workflows requieren:

```yaml
permissions:
  id-token: write
  contents: read
```

Ya están definidos en cada `docker-ecr.yml`.

### 4.4 Orden recomendado

1. `terraform apply` en `infrastructure`.
2. Push a `main` de **`infrastructure`** (publica `blume-mediamtx` y el workflow reutilizable).
3. Configura `AWS_ROLE_ARN` en todos los repos.
4. Push a `main` de cada microservicio y `blume_wa`.

Los workflows en componentes llaman a:

`Salon-1C/infrastructure/.github/workflows/reusable-deploy-ecs.yml@main`

Si tu org o rama difiere, edita la referencia `uses:` en cada `docker-ecr.yml`.

### 4.5 Repositorios y servicios ECS

| Repositorio GitHub | Workflow | ECR | ECS service |
|---|---|---|---|
| `infrastructure` | `mediamtx-ecr.yml` | `blume-mediamtx` | `stream-engine` |
| `blume_business_logic_ms` | `docker-ecr.yml` | `blume-backend` | `business-logic` |
| `blume_stream_ms` | `docker-ecr.yml` | `stream-engine` | `stream-engine` |
| `blume_record_ms` | `docker-ecr.yml` | `record-service` | `record-service` |
| `blume_stream_activities_ms` | `docker-ecr.yml` | `activities-ms` | `activities-ms` |
| `blume_recomendations_ms` | `docker-ecr.yml` | `recommendations-ms` | `recommendations-ms` |
| `blume_wa` | `docker-ecr.yml` | `blume-wa` | `blume-wa` |

Cada push a `main` construye la imagen, etiqueta `latest` y `sha-<commit>`, y ejecuta `ecs update-service --force-new-deployment`.

---

## 5. Verificación

- App web: URL del output `alb_dns_name`
- API Gateway (HTTPS): `api_gateway_endpoint`
- OBS: `rtmp://<nlb_dns>:1935/live` con stream key de Terraform
- WebRTC: puerto 8889 del NLB
- Logs: CloudWatch → `/ecs/blume/<servicio>`

---

## 6. Solución de problemas

| Problema | Acción |
|---|---|
| Workflow falla en `AssumeRole` | Verifica `AWS_ROLE_ARN` y que el repo esté en `github_repos` de Terraform |
| ECS task no arranca | Revisa que la imagen `latest` exista en ECR |
| Chat WebSocket no conecta | `PUBLIC_APP_URL` en `blume_wa` debe ser la URL del ALB; Phoenix usa `/socket` vía regla ALB |
| RDS connection refused | Comprueba que el servicio ECS esté en subnets privadas y SG correctos |

---

## 7. Costes aproximados

RDS ×3, NAT Gateway, ALB, NLB y Fargate generan coste continuo. Para laboratorio, reduce `desired_count` o destruye con `terraform destroy` cuando no uses el entorno.
