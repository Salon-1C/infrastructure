# Infrastructure — Prueba local end-to-end

Este `docker-compose.yml` levanta el stack completo con API Gateway local (`traefik`) para mantener paridad conceptual con cloud:

- frontend (`arquisoft-front`)
- `business-logic`
- `stream-engine`
- `mediamtx` (ingest + playback + recordings)
- `record-service` (metadatos + upload a objeto)
- MySQL principal + MySQL dedicado para recordings
- MinIO (S3 local)

## Servicios y puertos

| Servicio | Host | Descripción |
|---|---|---|
| `traefik` | http://localhost | Gateway local para front + APIs |
| `traefik dashboard` | http://localhost:8088 | Debug de routing |
| `mediamtx` RTMP | rtmp://localhost:1935 | Ingest desde OBS |
| `mediamtx` WHEP | http://localhost:8889 | Playback WebRTC |
| `mysql` | localhost:3306 | DB de business-logic |
| `recordings-mysql` | interno compose | DB dedicada de recordings |
| `minio` API | http://localhost:9000 | Storage S3-compatible |
| `minio` consola | http://localhost:9001 | UI de objetos |

## Arranque rápido

```bash
cp .env.example .env
docker compose up --build
```

Navega al front por el gateway:

- `http://localhost/explorar`
- `http://localhost/grabaciones`

Para parar y limpiar:

```bash
docker compose down -v
```

## Flujo E2E: stream + grabación + catálogo histórico

1. Crea un stream desde `/transmitir` (vista profesor).
2. Publica desde OBS:
   - Servidor: `rtmp://localhost:1935/live`
   - Stream key: la generada en `/transmitir`
3. Detén la transmisión.
4. MediaMTX deja archivos en `/recordings` (volumen compartido).
5. `record-service` detecta archivo estable, lo sube a MinIO y persiste metadatos.
6. Abre `/grabaciones` y valida que aparezca en la lista.

## Endpoints clave (vía gateway)

- `GET /api/recordings`
- `GET /api/recordings/:id`
- `POST /internal/recordings/reconcile` (uso interno/manual)

## Terraform (producción)

El Terraform ahora contempla:

- `record-service` como ECS service adicional
- bucket S3 dedicado para grabaciones
- RDS dedicado para metadatos de recordings
- nuevo ECR (`record-service`)
- routing ALB/API Gateway para `/api/recordings/*`
