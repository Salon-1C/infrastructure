# Atributo de calidad: Seguridad — Segmentación de red

**Sistema:** Blume (Salón 1C)  
**Táctica arquitectónica:** Segmentación de red (*Network Segmentation*)  
**Ámbito de esta entrega:** despliegue local con Docker Compose (paridad conceptual con AWS VPC + Security Groups)

---

## 1. Contexto en arquitectura de software

En el modelo de **atributos de calidad** (Bass, Clements, Kazman), **Seguridad** describe la resistencia del sistema a acciones no autorizadas. Una de las tácticas que refuerza ese atributo es la **segmentación de red**: dividir el sistema en zonas con distintos niveles de confianza y restringir el tráfico entre ellas al mínimo necesario.

| Concepto | En Blume (local) | En Blume (AWS) |
|----------|------------------|----------------|
| Zona pública / DMZ | `blume_edge` + Traefik `:80` | Subnets públicas + ALB / API Gateway |
| Zona de aplicación | `blume_app` | Subnets privadas + ECS tasks |
| Zona de datos | `blume_data` (`internal: true`) | RDS en subnets privadas + SG `rds` |
| Control de flujo | Redes Docker bridge aisladas | Security Groups + rutas VPC |

El objetivo no es “más contenedores”, sino **reducir la superficie de ataque**: un actor que comprometa solo el borde HTTP no debe poder abrir sesión TCP directa contra MySQL, RabbitMQ o PostgreSQL.

---

## 2. Diseño de zonas (Docker Compose)

```
                    Internet / host
                           │
                    ┌──────▼──────┐
                    │  blume_edge │  DMZ
                    │  traefik    │  :80, :8088 (dashboard)
                    │  blume_wa   │
                    └──────┬──────┘
                           │ HTTP interno
                    ┌──────▼──────┐
                    │  blume_app  │  Aplicación
                    │  microserv. │
                    │  mediamtx   │  :1935, :8889 (streaming)
                    └──────┬──────┘
                           │ solo servicios autorizados
                    ┌──────▼──────┐
                    │ blume_data  │  Datos (red interna)
                    │ mysql ×2    │
                    │ postgres    │
                    │ rabbitmq    │
                    │ minio       │
                    └─────────────┘
```

### Reglas de adjunción

| Servicio | `blume_edge` | `blume_app` | `blume_data` |
|----------|:------------:|:-----------:|:------------:|
| traefik | ✓ | ✓ | |
| blume_wa | ✓ | ✓ | |
| Microservicios (Spring, Go, FastAPI, Phoenix) | | ✓ | ✓ si usan BD/cola/storage |
| blume_recomendations_ms | | ✓ | |
| mysql, postgres, rabbitmq, recordings-mysql | | | ✓ |
| minio | | ✓ | ✓ (API S3 solo desde app; público vía Traefik `/storage`) |
| mediamtx | | ✓ | |

### Decisiones de endurecimiento

1. **Puertos de datos eliminados del host** — Ya no se publican `3306`, `5672`, `15672`, `9000`, `9001`. El acceso a datos pasa por la red interna `blume_data`.
2. **`blume_data` marcada `internal: true`** — Sin salida enrutable hacia Internet desde esa red; aísla la capa de persistencia.
3. **Único HTTP de aplicación en el host** — Traefik (`80`) y excepción documentada Phoenix WebSocket (`4000`), más puertos de streaming RTMP/WebRTC en MediaMTX.
4. **MinIO detrás del gateway** — URLs públicas de grabaciones usan `http://localhost/storage/<bucket>/...` en lugar de exponer el puerto `9000`.
5. **Corrección de descubrimiento** — `MEDIAMTX_HTTP_URL` apunta a `http://mediamtx:8889` (antes `localhost`, inválido entre contenedores).

---

## 3. Escenarios de amenaza cubiertos

| Escenario | Sin segmentación | Con segmentación |
|-----------|------------------|------------------|
| Escaneo de puertos desde la máquina host | MySQL, RabbitMQ, MinIO visibles | Solo 80, 4000, 1935, 8889, 8088 |
| Contenedor comprometido en DMZ | Acceso directo a BD si comparte `blume_net` | Sin adjunción a `blume_data` → sin ruta TCP |
| Microservicio de solo lectura API | Podría alcanzar cola/BD sin necesidad | Solo servicios con doble adjunción `app+data` conectan |

**Limitación consciente (trade-off):** Phoenix en `:4000` sigue expuesto para WebSockets; en producción se unificaría detrás del mismo ALB/WSS. MediaMTX requiere puertos de medios; en AWS se modela con NLB y SG acotados.

---

## 4. Paridad con infraestructura cloud (Terraform)

El módulo `modules/networking/main.tf` implementa la misma táctica:

- Subnets **públicas** (ALB, NLB) vs **privadas** (ECS, RDS).
- **Security group** ALB → ECS (puertos de app) → RDS (3306/5432 solo desde ECS).
- RDS `publicly_accessible = false` (ver módulo RDS).

La prueba local valida el **mismo principio arquitectónico** que la revisión de SG en AWS; no sustituye una auditoría de cuentas cloud.

---

## 5. Prueba de verificación

### Prerrequisitos

```bash
cd infrastructure
cp .env.example .env   # si no existe
# Firebase: blume_business_logic_ms/firebase/serviceAccountKey.json
docker compose up -d --build
```

### Ejecutar la prueba

```bash
chmod +x tests/security/network-segmentation/run-test.sh
./tests/security/network-segmentation/run-test.sh
```

### Qué valida el script

| # | Escenario | Resultado esperado |
|---|-----------|-------------------|
| 1 | Probe en `blume_edge` → mysql, rabbitmq, postgres, minio | **Bloqueado** |
| 2 | Probe solo en `blume_app` → mysql, rabbitmq | **Bloqueado** |
| 3 | Probe en `blume_app` + `blume_data` → mysql, rabbitmq | **Permitido** (rol legítimo de microservicio) |
| 4 | Probe en `blume_edge` → traefik:80 | **Permitido** |
| 4b | Probe en `blume_edge` → business-logic:8082 directo | **Bloqueado** |
| 5 | `curl http://localhost/health` vía Traefik | **200** (stack operativo) |

Un **exit code 0** indica que la táctica está implementada y el sistema sigue funcionando tras el endurecimiento.

---

## 6. Trazabilidad C&C

| Elemento C&C | Conector | Zona origen → destino |
|--------------|----------|------------------------|
| Cliente web | HTTP | Internet → `blume_edge` (Traefik) |
| Traefik | HTTP reverse proxy | `blume_edge` → `blume_app` |
| business-logic | JDBC | `blume_app` + `blume_data` → mysql |
| stream-engine | AMQP | `blume_app` + `blume_data` → rabbitmq |
| record-service | S3 API | `blume_app` + `blume_data` → minio |
| OBS / reproductor | RTMP / WebRTC | Host → mediamtx (`blume_app`) |

---

## 7. Referencias

- Bass, L.; Clements, P.; Kazman, R. *Software Architecture in Practice* — tácticas de seguridad.
- Documentación del proyecto: `README.md` (vista de despliegue), `modules/networking/main.tf` (AWS).
- Rama de trabajo: `feature/segmentacion-red-seguridad`.

---

## 8. Evolución sugerida

- Terminar TLS local (o `mkcert`) en Traefik.
- Enrutar WebSocket de Phoenix por Traefik y cerrar `:4000` en host.
- Añadir red `blume_internal` solo para rutas `/internal/*` entre servicios, sin exposición en Traefik (defensa en profundidad).
