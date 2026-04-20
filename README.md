# Blume Platform - Project README

## Team

**Group:** 1C

| Full Name | GitHub Profile |
|---|---|
| Andrés Felipe Alarcón Pulido | [andrefalar](https://github.com/orgs/Salon-1C/people/andrefalar) |
| Juan Jerónimo Gómez Rubiano | [jujgomezru](https://github.com/orgs/Salon-1C/people/jujgomezru) |
| Diego Esteban Ospina Ladino | [DOspinalUN23](https://github.com/orgs/Salon-1C/people/DOspinalUN23) |
| Jared Mijail Ramírez Escalante | [JaredMijailRE](https://github.com/orgs/Salon-1C/people/JaredMijailRE) |
| Felipe Rojas Marín | [Olyveon](https://github.com/orgs/Salon-1C/people/Olyveon) |
| Juan Camilo Rosero Santisteban | [juan-camilo-rosero](https://github.com/orgs/Salon-1C/people/juan-camilo-rosero) |

---

## Software System

**Name**: Blume

**Logo:**

<img src="./diagrams/logo.png" width="20%"/>

### Description

Streaming and learning platform composed of microservices. It allows user authentication, live streaming from OBS, WebRTC playback in a browser, and management of historical recordings.

## Architectural Structures

### Components and Connectors View

![Diagrama C&C de la plataforma](./diagrams/diagram-cyc.png)

### Description of architectural styles used

Blume follows a **SOFEA (Service-Oriented Front-End Architecture)** style at the system level, with each backend component internally organized as a **Layered (Hexagonal) Architecture**.

#### SOFEA - System level

SOFEA describes a system where a rich client (typically a Single-Page Application or a hybrid SSR/SPA) is fully decoupled from one or more backend services and communicates with them exclusively over a network protocol — in this case, HTTP/REST. The frontend is an independently deployable artifact, not a view rendered by the server.

Blume was designed following a SOFEA architecture, as evidenced by the following components:

- `arquisoft-frontend` (Next.js) is deployed independently from the backend services. It has no runtime coupling to `business-logic` or `stream-engine` beyond HTTP calls.
- All communication between the frontend and the backends is stateless HTTP/REST over JSON. Session state is carried by a signed JWT stored in an httpOnly cookie, not in server-side session objects.
- The frontend initiates all cross-component interactions. Neither `business-logic` nor `stream-engine` pushes data to the frontend except via polling or SSE (Server-Sent Events) responses to client-initiated requests.
- Each of the three main components (`arquisoft-frontend`, `business-logic`, `stream-engine`) can be built, tested, and deployed independently, which is the defining characteristic of SOFEA.

#### Layered (Hexagonal) Architecture — Component Level

Within `business-logic`, the internal structure follows Hexagonal Architecture, organized via vertical slicing by feature domain. This is a variant of layered architecture where the dependency direction is strictly inward: outer layers (infrastructure, adapters) depend on inner layers (application, domain), never the reverse.

The layers within each vertical slice are:

1. **Domain Layer** — Contains entities, value objects, domain exceptions, and port interfaces (both inbound and outbound). Has zero dependencies on any framework. Defines what the system *is*.
2. **Application Layer** — Contains use case orchestrators (services). Depends only on domain ports (interfaces). Defines what the system *does*, without knowing how it is delivered or persisted.
3. **Infrastructure Layer** — Contains all adapters: inbound (HTTP controllers, filters) and outbound (JPA repositories, SMTP client, Firebase SDK client, JWT library). Depends on the application and domain layers. Defines how the system *connects* to the outside world.

This structure applies per feature slice (`authentication/`, `channels/`, `activities/`, etc.), so each feature is a self-contained vertical unit with its own domain, application, and infrastructure sub-packages.

`stream-engine` (Go + Gin) follows a simpler layered structure given its narrower scope: a `config` package, a `server` package (routing and middleware), and `internal` packages per concern (`auth`, `signaling`, `media`), with no external dependencies between them.

### Description of architectural elements and relationships

#### Architectural elements

| Component | Technology | Role |
|---|---|---|
| `arquisoft-frontend` | Next.js 16, TypeScript, React 19 | Rich web client. Serves all user-facing pages, manages session state via React Context, and consumes both backend services over HTTP. |
| `business-logic` | Spring Boot 3.3.5, Java 21 | Central backend. Handles user authentication (local and Google/Firebase), session management via signed JWT cookies, password reset via SMTP, and all core business domain logic. |
| `stream-engine` | Go 1.22+, Gin | Streaming orchestration server. Validates RTMP stream keys for MediaMTX, generates WHEP URLs for WebRTC-based playback, and tracks live viewer counts. |
|`record-service`|Go Service |Recording processing; scans files, uploads to S3/MinIO, and saves metadata.|
| `MySQL 8.4` | Relational Database | Primary data store. Holds users, roles, auth providers, password reset tokens, channels, streams, chat messages, viewer sessions, and analytics events. Managed via Flyway migrations (6 versioned scripts). |
| `MediaMTX` | bluenviron/mediamtx (Docker) | Media server (RTMP ingest, WHEP/WebRTC playback, and recording generation). |
| `Cloudflare R2` | Object Storage + CDN | Hosts the HLS media segments produced by MediaMTX and delivers them to browsers with CDN caching. |
| Minio|MinIO console | S3-compatible object storage.|
| `Firebase` | Google Identity Platform | Provides Google OAuth. The frontend uses the Firebase JS SDK to obtain an ID token; `business-logic` verifies it using the Firebase Admin SDK (service account). |
| `traefik` |Traefik (Docker)| Single local gateway for the frontend and APIs (conceptual parity with cloud deployment).|


#### End-to-end functional flow

1. The instructor creates/starts the stream from the frontend.

2. OBS publishes the video via RTMP to `mediamtx`.

3. `stream-engine` authorizes publish/read access and delivers viewing sessions.

4. Students access the stream via WebRTC/WHEP in their browsers.

5. Upon completion, `mediamtx` saves the file to the shared volume (`/recordings`).

6. `record-service` detects a stable file, uploads it to MinIO, and persists metadata in its database.

7. The frontend queries `/api/recordings` to display the historical catalog.

### General structure

```text
1C/
├── infrastructure/   # Compose local, gateway, variables and execution documentation
├── arquisoft-front/  # Next.js Frontend
├── business-logic/   # API Spring Boot (auth + business)
├── stream-engine/    # API Go (streaming control + MediaMTX hooks)
└── record-service/   # Go service (recordings process and catalog)
```

### Main services and ports

| Service | URL / Port | Use |
|---|---|---|
| Gateway `traefik` | `http://localhost` | Unique entrypoint (frontend + APIs) |
| Dashboard Traefik | `http://localhost:8088` | Routing debugging |
| Media ingest RTMP | `rtmp://localhost:1935/live` | OBS publishing |
| Media playback WHEP | `http://localhost:8889` | WebRTC reproduction|
| MySQL business | `localhost:3306` | `business-logic` data |
| MinIO API | `http://localhost:9000` | Recording objects |
| MinIO console | `http://localhost:9001` | Bucket management |

## Prototype (Instructions to run project)

### Prerequisites

| Tool | Version | Purpose |
|---|---|---|
| Docker + Docker Compose | Latest stable | MySQL, MediaMTX |

From `infrastructure/`:

```bash
cp .env.example .env
docker compose up --build
```

Recommended endpoints:

- App: `http://localhost/explorar`
- Recordings: `http://localhost/grabaciones`

Shut down and clean volumes:

```bash
docker compose down -v
```

### Key endpoints

- Auth and business: `GET/POST /api/auth/*`, `GET /api/health`
- Streaming:
  - `POST /auth/mediamtx`
  - `GET /api/viewer-session?path=/live/<key>`
  - `GET /api/stats`
- Recordings:
  - `GET /api/recordings`
  - `GET /api/recordings/:id`
  - `POST /internal/recordings/reconcile` (manual/internal operation)

### Variables and secrets

- `infrastructure/.env` defines shared DB/MinIO credentials and runtime values.

- Requires Firebase credentials for `business-logic`:

- file: `business-logic/firebase/serviceAccountKey.json`

- Mounted as a read-only volume in a container.

- On-premises, `record-service` uses an internal S3 endpoint (`minio`) and a local public URL for playback.

### Cloud deployment

The infrastructure folder includes a production deployment with equivalent components:

- containerized services (including `record-service`);

- object storage for recordings;

- dedicated database for recording metadata;

- registry images and routing for `/api/recordings/*`.