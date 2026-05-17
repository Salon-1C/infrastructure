# Blume — Description of architectural elements and relations

Vista **Components and Connectors (C&C)** según el diagrama [`DiagramsDelivery 1-CyC View.drawio.png`](./DiagramsDelivery%201-CyC%20View.drawio.png).

## Leyenda de tipos (diagrama)

| Símbolo / color | Tipo de elemento |
|---|---|
| Caja rosa clara | FrontEnd |
| Caja azul clara | Microservicio |
| Barra horizontal | API Gateway |
| Rectángulo blanco | Media Server |
| Cilindro rosa | Message Queue |
| Cilindro amarillo | Relational Database |
| Cubo rojo | Object Storage |
| Actor externo | Cliente o servicio externo |

## Tabla de componentes, descripción y relaciones

| Componente | Tipo | Descripción | Relaciones (origen → destino · conector) |
|---|---|---|---|
| **Web Browser** | Cliente externo | Usuario que accede a la plataforma desde un navegador web. | → **Blume-wa** · interacción de usuario (UI) |
| **Mobile client** | Cliente externo | Usuario que accede desde la aplicación móvil nativa. | → **Blume-ma** · interacción de usuario (UI) |
| **Streaming App** | Cliente externo | Aplicación de captura/publicación (p. ej. OBS) que envía el flujo de video en vivo. | → **MediaMTX** · **RTMP** |
| **Blume-wa** | FrontEnd | Cliente web de Blume (Next.js). Páginas, estado de sesión y consumo de APIs y reproducción en vivo. | → **Blume_ag** · **REST**; → **MediaMTX** · **WebRTC/HTTP** |
| **Blume-ma** | FrontEnd | Cliente móvil de Blume (Flutter). Misma API y reproducción en vivo que la web. | → **Blume_ag** · **REST**; → **MediaMTX** · **WebRTC/HTTP** |
| **Blume_ag** | API Gateway | Punto único de entrada HTTP. Enruta peticiones de los frontends hacia los microservicios backend. | ← **Blume-wa**, **Blume-ma** · **REST**; → **Blume_business_logic_ms**, **Blume_recommendation_ms**, **Blume_record_ms**, **Blume_stream_ms** · **REST**; → **Blume_Activities_ms** · **WebSocket**; ← **MediaMTX** · **REST** |
| **MediaMTX** | Media Server | Servidor de medios: ingestión RTMP, reproducción WebRTC/WHEP y generación de fragmentos de grabación. | ← **Streaming App** · **RTMP**; ← **Blume-wa**, **Blume-ma** · **WebRTC/HTTP**; → **Blume_ag** · **REST**; → **Blume_stream_ms** · **REST**, **http** |
| **Auth External** | Servicio externo | Proveedor de autenticación externo (p. ej. Firebase / Google Identity). | → **Blume_business_logic_ms** · **Auth Hook** |
| **Blume_business_logic_ms** | Microservicio | Lógica de negocio central: usuarios, canales, streams, autenticación local y vía proveedor externo, JWT y dominio core. | ← **Blume_ag** · **REST**; ← **Auth External** · **Auth Hook**; → **Blume_business_db** · **JDBC** |
| **Blume_Activities_ms** | Microservicio | Actividades en vivo del stream (chat, presencia, eventos en tiempo real). | ← **Blume_ag** · **WebSocket**; → **Blume_activities_db** · conector de base de datos |
| **Blume_recommendation_ms** | Microservicio | Recomendaciones de clases/streams según datos de otros servicios y scoring. | ← **Blume_ag** · **REST** |
| **Blume_record_ms** | Microservicio | Procesamiento asíncrono de grabaciones: consume eventos, sube video a almacenamiento de objetos y persiste metadatos. | ← **Blume_ag** · **REST**; ← **Record-Queue** · **Consumer**; → **Blume_record_db** · conector de base de datos; → **Blume_record_video_db** · conector de almacenamiento |
| **Blume_stream_ms** | Microservicio | Orquestación de streaming: autorización de publish/read, sesiones de visualización, hooks con MediaMTX y publicación de eventos de grabación. | ← **Blume_ag** · **REST**; ↔ **MediaMTX** · **REST**, **http**; → **Record-Queue** · **Producer** |
| **Blume_business_db** | Relational Database | Persistencia de datos de negocio: usuarios, roles, canales, streams y entidades del dominio central. | ← **Blume_business_logic_ms** · **JDBC** |
| **Blume_activities_db** | Relational Database | Persistencia de mensajes de chat, sesiones de visualización y eventos de actividades en vivo. | ← **Blume_Activities_ms** · conector de base de datos |
| **Blume_record_db** | Relational Database | Metadatos del catálogo de grabaciones (identificadores, rutas, estado, referencias a objetos). | ← **Blume_record_ms** · conector de base de datos |
| **Blume_record_video_db** | Object Storage | Almacenamiento de archivos de video de las grabaciones procesadas. | ← **Blume_record_ms** · conector de almacenamiento |
| **Record-Queue** | Message Queue | Cola asíncrona entre el motor de stream y el servicio de grabaciones (desacopla notificación y procesamiento). | ← **Blume_stream_ms** · **Producer**; → **Blume_record_ms** · **Consumer** |

## Resumen de conectores

| Conector | Uso en el diagrama |
|---|---|
| **REST** | Frontends ↔ gateway; gateway ↔ microservicios; MediaMTX ↔ stream y gateway |
| **WebSocket** | Gateway ↔ **Blume_Activities_ms** (tiempo real) |
| **WebRTC/HTTP** | Frontends ↔ **MediaMTX** (reproducción en vivo) |
| **RTMP** | **Streaming App** → **MediaMTX** (ingesta) |
| **http** | **MediaMTX** ↔ **Blume_stream_ms** (hooks / control de medios) |
| **Auth Hook** | **Auth External** → **Blume_business_logic_ms** |
| **JDBC** | **Blume_business_logic_ms** → **Blume_business_db** |
| **Producer / Consumer** | **Blume_stream_ms** → **Record-Queue** → **Blume_record_ms** |

## Flujo funcional principal (referencia)

1. El instructor publica video con **Streaming App** vía **RTMP** hacia **MediaMTX**.
2. **Blume_stream_ms** autoriza y coordina sesiones; los estudiantes reproducen por **WebRTC/HTTP** desde **Blume-wa** / **Blume-ma**.
3. Al cerrarse segmentos de grabación, **Blume_stream_ms** publica en **Record-Queue** (**Producer**).
4. **Blume_record_ms** consume la cola (**Consumer**), persiste metadatos en **Blume_record_db** y video en **Blume_record_video_db**.
5. Autenticación y dominio de negocio pasan por **Blume_ag** → **Blume_business_logic_ms**, con validación externa vía **Auth Hook**.
