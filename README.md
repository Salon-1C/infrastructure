# Infrastructure — Prueba de sistema local

Este `docker-compose.yml` levanta el stack completo de Blume para pruebas de sistema end-to-end: frontend Next.js, backend Spring Boot, MySQL, stream-engine Go y MediaMTX.

## Servicios y puertos

| Servicio | Host | Descripción |
|---|---|---|
| `frontend` | http://localhost:3000 | Next.js (arquisoft-front) |
| `business-logic` | http://localhost:8080 | Spring Boot API |
| `stream-engine` | http://localhost:9090 | Go API (viewer-session, stats, auth hook) |
| `mediamtx` — RTMP | rtmp://localhost:1935 | Ingest desde OBS u otro cliente |
| `mediamtx` — WHEP | http://localhost:8889 | WebRTC playback desde el navegador |
| `mysql` | localhost:3306 | Base de datos MySQL 8.4 |

## Arranque rápido

```bash
# 1. Copia y completa las variables de entorno
cp .env.example .env

# 2. Levanta todos los servicios (el primer build tarda varios minutos)
docker compose up --build

# 3. Abre el front en el navegador
open http://localhost:3000
```

Para parar y limpiar:
```bash
docker compose down -v   # -v elimina el volumen de MySQL
```

## Publicar un stream (OBS)

1. En OBS > Configuración > Stream:
   - **Servicio:** Personalizado
   - **Servidor:** `rtmp://localhost:1935/live`
   - **Clave de retransmisión:** el valor de `STREAM_KEY` en tu `.env`
2. Pulsa "Iniciar transmisión".
3. Abre http://localhost:3000/clase/demo — el reproductor WebRTC conectará automáticamente.

## Ver el stream en el front

Navega a cualquier ruta `/clase/<id>`. La página lee `NEXT_PUBLIC_STREAM_KEY` (baked en el build de Docker) y abre la sesión WHEP. El flujo es:

```
Browser → GET http://localhost:9090/api/viewer-session?path=/live/<KEY>
       ← { whep_url: "http://localhost:8889/live/<KEY>/whep" }
Browser → POST SDP a whep_url
       ← SDP answer + WebRTC track
```

## Bloqueadores conocidos en `business-logic`

Los siguientes archivos tienen **marcadores de merge conflict** y deben resolverse manualmente antes de poder construir la imagen de `business-logic`:

- `business-logic/backend-core/Dockerfile`
- `business-logic/backend-core/src/main/resources/application.yml`
- `business-logic/backend-core/src/main/java/com/blume/shared/infrastructure/config/FirebaseConfig.java`
- `business-logic/docker-compose.yml`
- `business-logic/.github/workflows/docker-erc.yml`

Hasta resolver esos conflictos, el servicio `business-logic` no compilará con `docker compose up --build`. Los demás servicios (stream-engine, mediamtx, frontend) pueden arrancarse por separado:

```bash
docker compose up --build frontend stream-engine mediamtx
```

## Notas de infraestructura Terraform (AWS)

El Terraform en este directorio no requiere cambios para la integración de streaming: ya contiene las reglas ALB para `/api/viewer-session`, `/api/viewers/*`, `/api/stats`, `/auth/mediamtx` → stream-engine, y el NLB para RTMP (1935) y WHEP (8889).

Dos inconsistencias pre-existentes para resolver antes de un despliegue en producción:

- `MAIL_PASSWORD` en la task ECS de `business-logic` apunta al secret de Firebase (probablemente un copy-paste).
- `ALLOWED_ORIGIN` (nombre en ECS) vs `ALLOWED_ORIGINS` (nombre en Spring `application.yml`) — la app Spring no leerá el valor de ECS tal como está.
