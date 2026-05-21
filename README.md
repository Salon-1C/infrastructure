# Prototype 3
## Team
**Name:** 1C

**Team Members:**
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

![image](diagrams/logo.png)

### Description

Blume is a streaming and learning platform composed of microservices. It allows user authentication, creation and use of channels, grading students live-streaming from OBS, WebRTC playback in a browser, and management of historical recordings.

---

## Architectural Structures
### Component-and-Connector (C&C) Structure
- **View:**

![DiagramsDelivery #1-C&C View.drawio](diagrams/cyc.jpeg)
#### Description of architectural elements and relations

| Component                              | Type                | Description                                                                                                        | Relationships (origin → destiny · connector)                                                                                                                                                                                          |
| -------------------------------------- | ------------------- | ------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Web Browser**                        | External Client     | User that access the system from a web platform.                                                                   | → **blume-wa** · user interaction (UI)                                                                                                                                                                                                |
| **Mobile client**                      | External Client     | User that access the system from the native mobile app.                                                            | → **blume-ma** · user interaction (UI)                                                                                                                                                                                                |
| **Streaming App**                      | External Client     | Recording app (i.e. OBS) that sends the live video stream.                                                         | → **MediaMTX** · **RTMP**                                                                                                                                                                                                             |
| **blume-wa**                           | FrontEnd            | Blume's web client (Next.js). Pages, session state, API requesting, and live playback.                             | → **infrastructure** · **REST**; → **MediaMTX** · **WebRTC/HTTP**                                                                                                                                                                           |
| **blume-ma**                           | FrontEnd            | Blume's mobile client (Flutter). Same API and live playback as in web.                                             | → **infrastructure** · **REST**; → **MediaMTX** · **WebRTC/HTTP**                                                                                                                                                                           |
| **infrastructure**                           | API Gateway         | HTTP single entrance point. Routes petitions from the front-ends to the different service backends.                | ← **blume-wa**, **blume-ma** · **REST**; → **blume_business_logic_ms**, **blume_recommendation_ms**, **blume_record_ms**, **blume_stream_ms** · **REST**; → **blume_stream_activities_ms** · **WebSocket**; ← **MediaMTX** · **REST** |
| **MediaMTX**                           | Media Server        | Media server: RTMP ingest, WebRTC/WHEP playback and recording fragments generation.                                | ← **Streaming App** · **RTMP**; ← **blume-wa**, **blume-ma** · **WebRTC/HTTP**; → **infrastructure** · **REST**; → **blume_stream_ms** · **REST**, **http**                                                                                 |
| **Auth External**                      | External service    | External authentication provider (i. e. Firebase / Google Identity).                                               | → **blume_business_logic_ms** · **Auth Hook**                                                                                                                                                                                         |
| **blume_business<br>_logic_ms**        | Microservice        | Main Business Logic: users, channels, streams, local and via external provider authentication, JWT y core domain.  | ← **infrastructure** · **REST**; ← **Auth External** · **Auth Hook**; → **blume_business_db** · **JDBC**                                                                                                                                    |
| **blume_stream<br>_activities_ms**     | Microservice        | Live stream activities and interactions (chat, attendance, real-time operations).                                  | ← **infrastructure** · **WebSocket**; → **blume_stream_activities_db** · database connector                                                                                                                                                 |
| **blume_<br>recomendations<br>_ms**    | Microservice        | Class/stream recommendations according to other services and scoring.                                              | ← **infrastructure** · **REST**                                                                                                                                                                                                             |
| **blume_stream_ms**                    | Microservice        | Streaming orchestration: publish/read authorization, viewer session, hooks with MediaMTX and recording publishing. | ← **infrastructure** · **REST**; ↔ **MediaMTX** · **REST**, **http**; → **Record-Queue** · **Producer**                                                                                                                               |
| **blume_record_ms**                    | Microservice        | Asynchronous recording processing: listens to events, uploads video to object storage and persists metadata.       | ← **infrastructure** · **REST**; ← **Record-Queue** · **Consumer**; → **blume_record_db** · database connector; → **blume_record_video_db** · storage connector                                                                             |
| **blume_business_db**                  | Relational Database | Business data persistance: users, roles, channels, streams and main domain entities.                               | ← **blume_business_logic_ms** · **JDBC**                                                                                                                                                                                              |
| **blume_<br>stream_activities<br>_db** | Relational Database | Persistance of chat messages, viewer sessions and live activities.                                                 | ← **blume_stream_activities_ms** · database connector                                                                                                                                                                                 |
| **blume_record_db**                    | Relational Database | Recording metadata (identifiers, routes, status, object reference).                                                | ← **blume_record_ms** · database connector                                                                                                                                                                                            |
| **blume_record<br>_video_db**          | Object Storage      | Storage of video files from processed recordings.                                                                  | ← **blume_record_ms** · Storage connector                                                                                                                                                                                             |
| **Record-Queue**                       | Message Queue       | Asynchronous queue between the stream engine and the recording service (decouples notifications and processing).   | ← **blume_stream_ms** · **Producer**; → **blume_record_ms** · **Consumer**                                                                                                                                                            |

#### Description of architectural styles and patterns used
- **API Gateway:** 
Within the framework of the Components and Connectors (C&C) view, the **API Gateway** pattern is implemented through the `infrastructure` component, acting as a centralized gateway and single point of entry for external clients (`blume_wa` and `blume_ma`). As evidenced in the diagram `DiagramsDelivery 1-CyC View.drawio.png`, this architectural style functions as a routing connector and a mediator that encapsulates the internal topology of the system, isolating clients from the complexity of the underlying microservices network. The API Gateway assumes the responsibility for protocol adaptation, channeling synchronous REST requests towards services like `blume_business_logic_ms` and managing continuous bidirectional connections (WebSocket) towards `blume_stream_activities_ms`. Its inclusion drastically reduces the coupling between the frontend and the backend, mitigating network overhead by avoiding "chatty" communication (multiple direct calls from clients to different services) and establishing a cohesive layer for perimeter access control and routing.
**Asynchronous Messaging (Message Broker / AMQP):**
To address background processing needs, the architecture adopts an **Asynchronous Messaging** style mediated by the `Record-Queue` component (represented as a Message Queue in the diagram). In C&C semantics, this pattern employs message-oriented asynchronous data distribution connectors that establish a producer-consumer communication between `blume_stream_ms` (Producer) and `blume_record_ms` (Consumer). Theoretically, the use of a message queue guarantees the temporal and spatial decoupling of components: the streaming engine can notify the completion of a recording segment without needing to wait for a response, while the recording service processes the load in a deferred manner. This pattern significantly increases the system's resilience and fault tolerance, as it acts as a buffer that absorbs peak loads, preventing costly I/O operations (such as video persistence in object storage) from degrading the critical performance of the live stream.
**Synchronous Communication (HTTP/REST)**
For interactive transactions that demand determinism and immediate responses, the system is grounded in a **Synchronous Communication** style based on REST (Representational State Transfer) principles over HTTP. From the C&C perspective, this pattern materializes through stateless call-return connectors that backbone both the clients' interaction with `infrastructure` and the internal orchestration from the Gateway to the core microservices (`blume_business_logic_ms`, `blume_recommendation_ms`, etc.) and the media server (*MediaMTX*). At a theoretical level, the stateless constraint of the connector ensures that each request contains all the context necessary to be processed, which is vital for enabling the horizontal scalability of the microservices. This style promotes a standardized semantics based on resources and verbs, facilitating interoperability and guaranteeing a robust request-response model for the synchronous operations of the business domain.

### Deployment Structure

- **View:**
![deploymentView](diagrams/deployment.jpeg)


#### Description of architectural elements and relations

The Blume platform's physical mapping is modeled through a distributed, multi-node allocation structure. It captures how computational execution environments, networking segments, and persistent artifacts are instantiated across hardware barriers.

The system topology is logically split into two distinct physical domains operating over a shared Local Area Network (LAN) connector, establishing a strict perimeter between the client presentation space and backend server processing:

- **Node 1 (Backend Host Machine):** A high-compute environment executing an operating system instance that hosts a virtualization layer. It holds the core system container that executes the entire Blume ecosystem. All internal routing, messaging, media packaging, and persistent storage occur within this node's boundaries.

- **Node 2 (Client Phone Device)**: A mobile hardware node running the Android Execution Environment. This node encapsulates the presentation client assets, specifically running the binary compiled by the Flutter Motor (Component 14). It acts purely as a consumer of edge-routed streams and REST schemas.

#### Description of architectural patterns used

- **Containerization (OS-Level Virtualization)**: This pattern involves packaging an application and its entire runtime dependency tree into isolated user-space instances called containers, which share the host operating system's kernel. In Blume, this is utilized to containerize heterogeneous microservices (Spring Boot, FastAPI, Phoenix, Go), ensuring environmental parity across the system lifecycle and preventing dependency conflicts on the physical host machine (Node 1).


### Layered Structure

**View:**

![DiagramsDelivery 1-Layer_diagram.drawio](diagrams/layered.jpeg)

#### Architectural Elements and Relations

##### Elements

On the Layered structure, we can see the system is divided in 5 layers, which are as follows:

- **Presentation**: This tier is the only layer that users ever directly interact with. Its sole responsibility is rendering UI and translating user intent into structured requests for the layer below — it holds no business logic and owns no data.

  - `blume_wa` is a *Next.js 16* server-rendered web app. It delegates all auth, stream, and channel concerns to the backend via REST and receives JWT identity through an httpOnly cookie. It also connects a Phoenix WebSocket client for live chat/polls.
  - `blume_ma` is a *Flutter* cross-platform mobile client. It follows Clean Architecture internally (Presentation → Domain   → Data), but from the system's perspective it is purely a consumer: it reads from REST endpoints, plays HLS from  *MediaMTX*, and relies on the same cookie-based auth contract.

  Neither client has its own database, business rules, or message queue access. They are only concerned with user experience and interaction, which includes defining the aesthetics and application flow.
- **Gateway:** This tier is the system's single entry point and traffic director. *Traefik* owns HTTP/HTTPS traffic; *MediaMTX* owns the media plane (RTMP/HLS/WebRTC).

  Its responsibilities are:
  - Routing requests to the correct microservice by path prefix and priority (e.g., /api/v1 → recommendations, /socket → Phoenix, /api/recordings → record-ms, / → Next.js).
  - TLS termination — all external traffic arrives over HTTPS; internal traffic flows over the private blume_app Docker network.
  - Network isolation — enforces a three-zone boundary: blume_edge (DMZ, reachable from outside), blume_app (services, internal only), blume_data (databases/queues, never exposed to the host).

This tier does not transform data or execute logic. It is a pure structural layer: it defines who can talk to whom and how traffic enters the system. It also holds the main container that executes the entire Blume system. Every other components' Dockerfile only deploys its own content.

- **Logic:** This is the widest tier, where every meaningful computation in the system happens. Each microservice here owns a specific bounded context. Together they compose the entire practical functions of the system.

    - `blume_business_logic_ms`: Identity, auth (local + Firebase), channels, classes, access control, grades. The   system's source of truth for domain entities. Internally designed with hexagonal architecture. 
    - `blume_stream_ms`: Real-time streaming orchestration: viewer sessions, HLS management, RTMP authorization, SSE for viewer counts. Talks to MediaMTX and RabbitMQ.
    - `blume_stream_activities_ms`: Live engagement: chat, polls, quizzes over WebSocket (Phoenix Channels). Writes engagement data consumed by recommendations. 
    - `blume_recommendations_ms`: Stateless scoring engine: aggregates stream metadata and engagement data from other services, ranks results via hybrid algorithm (recency + engagement + affinity). No DB of its own.
    - `blume_record_ms`: Post-processing pipeline: detects when MediaMTX finishes a recording, uploads it to MinIO/S3, tracks metadata in its own MySQL instance. 

These services communicate synchronously (REST over blume_app) and asynchronously (via *RabbitMQ*). They are the only tier allowed to mutate the system's state.
- **Async:** This tier decouples the services within Tier 3 from each other on the time axis. Its purpose is to allow high-latency or best-effort operations to happen without blocking synchronous request paths. In practice it carries exactly one pipeline: when a live stream ends, *MediaMTX* fires an HTTP webhook to `blume_stream_ms` → `blume_stream_ms` publishes a message to the `recordings.ready queue` → `blume_record_ms` consumes it and begins the upload-to-S3 process. Neither service needs to wait for the other; the recording pipeline is fully decoupled from stream teardown.

  This tier has no logic of its own — it is pure message routing and buffering. If it goes down, streams still run;  recordings are delayed, not lost (reconciliation loop in blume_record_ms also polls the filesystem as a fallback).
- **Data:** This tier stores all durable state in the system. It is partitioned by service ownership — no two services share a database, which is a key microservices principle:


| Store | Owner | What it holds |
|---|---|---|
| MySQL (`blume_db`) | `blume_business_logic_ms` | Users, channels, classes, enrollments, grades, Flyway migrations |
| MySQL (`recordings_mysql`) | `blume_record_ms` | Recording metadata (stream key, S3 URL, timestamps) |
| PostgreSQL (`postgres_activities`) | `blume_stream_activities_ms` | Chat messages, polls, quiz responses, engagement events |
| MinIO (S3-compatible) | `blume_record_ms` | Raw video files (.mp4) uploaded from MediaMTX recordings |

  All four stores live on the blume_data network, which has no host-level port exposure — they are reachable only by Tier 3 services through the internal Docker network.

##### Relations

The *allowed to use* relation is an architectural constraint on dependency direction, not just a description of runtime communication. It indicates that, the Layer that is allowed to use, Layer "A", is allowed to know about, call, and depend on another Layer "B". This means, the Layer "B" in this scenario is completely ignorant of Layer "A". This has two consequences:

  1. Dependencies are one-directional. If Presentation is allowed to use Communication, it means Presentation can initiate calls to Communication — but Communication must never initiate calls up to Presentation. A lower layer should never need to know that an upper layer exists.

  2. It defines who is responsible for stability. The layer being "used" must offer a stable interface, because the layer above depends on it. Changes to a lower layer can force adaptation above; changes to an upper layer should never break anything below.

Blume uses relaxed layering. This means, that it's possible for an upper layer to use multiple layers beneath them, not just one. This can be seen specifically by the Logic Layer, which talks directly to both Async and Persistence, rather than having to use one of them to complete a flux (which makes sense since their both beneath Logic, but hold different responsabilities). On the otherhand, both Async and Persistence are lower layers and do not know about Logic or each other, they only provide their services.

 - **Presentation → Gateway:** This relation has two distinct channels depending on what kind of traffic is involved. 
     - HTTP/REST and WebSocket — via *Traefik*: Both `blume_wa` and `blume_ma` send all API calls to *Traefik* as their sole known host. The clients have no knowledge of which service sits behind any given path — they only know the gateway's address. The JWT session identity travels as an httpOnly cookie on every request. For WebSocket, `blume_wa` upgrades the connection at /socket through *Traefik*, which proxies it to Phoenix. From the client's perspective it is a single persistent connection; Traefik is transparent.

      - HLS media — via *MediaMTX*: When a client wants to watch a live stream, it first calls `stream_ms` through *Traefik* to get a viewer session (this returns a WebRTC/WHEP manifest URL pointing at *MediaMTX* port 8889). From that point on, the client connects directly to MediaMTX for the actual video data. `blume_ma` uses video_player + Chewie for this; blume_wa uses a browser-native video player. Presentation uses *MediaMTX* as a pure media delivery endpoint — it has no awareness of what authentication decision was made upstream.

    - RTMP — professor's OBS → *MediaMTX*: When a professor starts streaming, their OBS client pushes an RTMP stream directly to MediaMTX on port 1935 using a stream key obtained from the business logic service. This is the only incoming flow that bypasses *Traefik* entirely — RTMP is not HTTP and *Traefik* does not handle it.

  - **Gateway → Logic** This is where the gateway tier delegates all decisions it cannot make itself.

    - *Traefik* → Logic services (HTTP proxy): Traefik holds no logic. It matches the incoming request path against its routing table, strips the prefix if configured, and forwards the full HTTP request (headers, cookies, body) to the target service on the blume_app network. The Logic service sees the original request as if it arrived directly. The routing decision is purely structural: /api → `business_logic_ms:8082`, /api/v1 → `recomendations_ms:8000`, /socket → `stream_activities_ms:4000`, /api/recordings → `record_ms:8081`, and so on. Priority values prevent ambiguous path overlaps.
     - *MediaMTX* → `stream_ms`: When an RTMP stream arrives at *MediaMTX*, *MediaMTX* does not decide whether to accept it. Instead it sends a synchronous HTTP callback to `stream_ms` at /auth/mediamtx, passing the stream key. `stream_ms` checks whether the key belongs to a valid, authorized class and returns 200 (allow) or 403 (deny). *MediaMTX* then accepts or drops the stream accordingly. *MediaMTX* knows nothing about users, channels, or classes — it delegates the entire authorization decision to the Logic tier and acts on the binary response.

  - **Logic → Logic:** These are direct service-to-service HTTP calls on the blume_app network, bypassing *Traefik* entirely. They are same-tier dependencies and the most architecturally significant coupling in the system.

      - `recomendations_ms` → `business_logic_ms`: `recomendations_ms` calls GET /api/clases on `business_logic_ms` to fetch the list of streams and their metadata. It needs this as input to its scoring algorithm. This makes `recomendations_ms` structurally dependent on `business_logic_ms` — if the Spring Boot service is down, the recommendation engine degrades (it has an in-memory cache with a 2-minute TTL as a buffer).

      - `recomendations_ms` → `stream_activities_ms`: `recomendations_ms` calls GET /api/analytics/streams/engagement on the Phoenix service to retrieve per-stream engagement counts (chat messages, polls, quizzes). These feed the engagement component of the scoring formula. Same dependency pattern as above.

      - `business_logic_ms` → `stream_ms`: `business_logic_ms` queries `stream_ms` for live stream metadata when serving class information to clients.

  - **Logic → Async:** This relation is unidirectional at the dependency level but bidirectional at the message level. The Logic tier owns
  the queue interaction — RabbitMQ is passive.

      - `stream_ms` → *RabbitMQ* (publisher flow): When *MediaMTX* signals that a stream has finished publishing, `stream_ms` places a message on the `recordings.ready` queue. The message carries enough context for a consumer to locate and process the recording (stream key, path). `stream_ms` does not know or care who will consume this message.

      - `record_ms` → *RabbitMQ* (consumer flow): record_ms subscribes to the same queue and processes each message as it arrives: it locates the recording file on the shared volume, waits for the file to stabilize (no more writes), uploads it to MinIO, and stores the resulting metadata. record_ms also runs a reconciliation loop that scans the filesystem independently — so if RabbitMQ is unavailable, recordings are eventually processed anyway.
      
The Async tier never calls into Logic. Messages flow from Logic into the queue and back out to Logic. The dependency arrow (who knows about whom) still points downward: Logic knows about RabbitMQ's queue names and AMQP protocol; RabbitMQ knows nothing about Logic.

  - **Logic → Persistence:** Each service owns exactly one store and accesses it directly. No service queries another service's database — this is
  the microservices database-per-service rule enforced at the network level (blume_data is only reachable from blume_app services).

      - `business_logic_ms` → MySQL (`blume_db`): Uses Spring Data JPA for all reads and writes. Flyway manages the schema — DDL is never applied at runtime, only through versioned migration files. This store holds all primary domain entities: users, channels, classes,
  enrollments, grades.

    - `record_ms` → MySQL (recordings_mysql): Uses direct SQL (no ORM). After a successful S3 upload, record_ms writes the recording's metadata (stream key, S3 URL timestamps) into this separate database. It is isolated from `blume_db` — `business_logic_ms` never touches it.

     - `stream_activities_ms` → PostgreSQL (postgres_activities): Uses Ecto for all queries and changesets. Stores the live engagement data: chat messages, poll definitions and responses, quiz events. This is the data recomendations_ms aggregates.

      - `record_ms` → MinIO: Uses the S3-compatible PutObject API. MinIO is technically an object store rather than a relational database, but it
  lives in the Persistence tier because it is a durable, append-only store of binary state. record_ms writes .mp4 files here and stores the resulting URL in MySQL. No other service writes to MinIO; blume_wa/blume_ma read recordings by receiving URLs from record_ms via *Traefik*.


#### Description of architectural patterns used

- **Model-View-Controller**: The MVC pattern is a way of organizing services through three components: Model, View, and Controller. The Model is the internal representation of data. It defines its structure, business logic, and internal rules. In this diagram, each microservice defines its own model. For example, in `blume_business_logic_ms`, models are found in repositories. Views are the way this information is presented; the key idea is that the same model can be represented in multiple ways, depending solely on content and not on internal logic. In our MVC implementation, Views are handled by blume_wa, such as the different React pages that make up the frontend. Controllers are software components responsible for accepting input and forwarding it in an interpretable form to the target component, without either communicating component needing to know about the other, making inter-component communication more flexible. In `blume_business_logic_ms`, this is handled by the controllers, which are located on the `infrastructure/adapter/in` subfolders of each domain.
- **Model-View-ViewModel**: An alternative to the MVC pattern. Unlike MVC, MVVM uses a ViewModel as an intermediary instead of a Controller. The ViewModel differs from a Controller in two ways. First, the ViewModel does not receive requests or execute responses the way a Controller does. Second, the ViewModel is an abstraction of the Model for the View, adapting data and exposing commands. The View observes the ViewModel to render state changes autonomously without a traditional controller. Being an abstraction, it can hold system state, whereas a Controller always behaves the same way as defined by its source code. In Blume, this pattern is used for handling mobile requests. The `blume_ma` frontend also connects to infrastructure and therefore to the backend, but while `blume_wa` has an internal server (*Next.js*) that listens for and executes requests, *Flutter* is a constant execution environment. Views render themselves in response to state changes, orchestrated directly by *Flutter*, so no controller is needed.
- **Public vs. Published Interfaces**: This pattern consists of distinguishing between public and published interfaces and managing them accordingly. A public interface is one that is visible outside a class at the code level; since it's possible to control all its callers, it can be freely modified through refactoring. A published interface, on the other hand, is one explicitly exposed to external consumers outside of their control, making them significantly harder to change, because modifying them break code that is not accesible. In our system, the communication between microservices and the API Gateway functions as a published interface: the API Gateway has no access to the microservices' internal classes, only to their interfaces, and changing those interfaces directly impacts dependent logic. The advantage of designing around published interfaces is that they enforce a stable, well-defined contract. To keep this contract manageable, interfaces should be kept thin. In this case, it's implemented as a minimalist JSON files that provide only the information each service needs to respond to requests. 
- **Data Access Object**: A DAO is an abstract interface applied to a database element. Basically, an internal, code-level representation of database contents that facilitates their processing by the system's logical components. The advantage of this pattern is that it allows representing the system's persistence layer without exposing the underlying database's implementation details. This pattern is used extensively in Blume, primarily in `blume_business_logic_ms`. This component defines JPA Entities. These are data structures that mirror database contents. As well as Repositories, which are the Java-language expression of database queries applied over those entities. Additionally, `blume_business_logic_ms` applies Hexagonal Architecture (Ports and Adapters): Ports are the interfaces that define the contract between the application core and the outside world. Adapters translate and map data between external formats (JPA entities) and internal domain objects, ensuring the core business logic remains independent of persistence mechanisms. This means that classes implementing the ports depend neither on the database nor on the underlying logic. The DAO pattern is also used in `blume_record_ms` via repositories and interfaces, and in `blume_wa` to interact with the Next.js server.
- **Cache-Aside (Memoization)**: A caching pattern in which the application itself is responsible for loading data into the cache on demand. On the first request, data is fetched from the original source and stored in an in‑memory structure; subsequent requests retrieve the cached value directly, bypassing redundant computation or network calls. This pattern is applied in `blume_recomendations_ms`, which defines a dedicated cache class at `app/core/cache.py` that stores HTTP responses obtained from other microservices, specifying how the map is stored along with its associated read and write methods. Alongside it, `app/repositories/streams_repo.py` implements the lookup logic: before issuing a call to blume_business_logic_ms` or `blume_stream_activities_ms`, it consults the cache first and only fetches from the source on a miss. This eliminates redundant inter‑service calls and serves as the TTL‑based buffer described in the Logic → Logic relation. *Hibernate* and *GORM* provide first‑level (Identity Map) caching at the ORM layer, which is a distinct mechanism from the Cache‑Aside pattern used here.

- **Inversion of Control and Dependency Injection**: Inversion of Control (IoC) is the broader principle by which the flow of control is inverted relative to conventional programming: instead of the developer's code calling a library when needed, a framework calls the developer's code at the appropriate time (the Hollywood Principle: "don't call us, we'll call you"). **Dependency Injection (DI)** is one specific form of IoC, in which a component declares the dependencies it needs rather than creating them internally, with an external assembler responsible for constructing and providing those dependencies. This is the form applied in `blume_record_ms`. The class `internal/recordings/service.go` does not instantiate its own dependencies; it declares what it needs. In this case, a Repository and an ObjectStorage. Then, `internal/main.go` constructs those dependencies and injects them. This makes the service decoupled from any specific implementation of its dependencies, improving testability and flexibility.


### Decomposition Structure
---

**View:**

![DiagramsDelivery 1-Decomposition View.drawio.png.drawio](diagrams/decomposition.jpeg)

#### Description of architectural elements and relations

The BLUME system is decomposed into eight functional modules, each grouping a cohesive set of capabilities under a strict "is part of" relationship. No runtime communication or data flow is represented — this view describes 
structural ownership only.

- **Presentation** groups all user-facing components: the web application 
(*Next.js* / TypeScript), the mobile application (Flutter / Dart), the HLS 
video player, the personal notes system, and a demo/offline mode that 
operates without a live backend.

- **Authentication and Security** owns all identity and session management: 
local registration, JWT-based local authentication, Google authentication via Firebase, HTTP session management through HttpOnly cookies, and password reset via email (SMTP).

- **Channel and Class Management** covers the academic content layer: public channel exploration, channel enrollment, class listing and detail, and stream access control.

- **Live Streaming** handles the full live streaming pipeline: RTMP authentication for broadcasting tools (OBS / StreamYard), WebRTC session management (WHEP), real-time viewer counting via SSE, RTMP ingest through *MediaMTX*, and HLS / WebRTC distribution to viewers.

- **Interactive Activities** groups all real-time engagement features running over Phoenix WebSockets: live chat, interactive polls, graded quizzes, and engagement metrics collection.

- **Recommendation System** contains the content discovery engine: personalized recommendations (affinity + recency scoring), non-personalized trending, the hybrid scoring algorithm, and a TTL-based result cache to 
reduce redundant computation.

- **Recording Management** owns the post-stream recording pipeline: segment ingestion via RabbitMQ consumer, object storage upload to S3/MinIO, metadata registration (title, instructor, timestamps), recording playback, and a reconciliation process that syncs S3 state with the database.

- **Infrastructure and DevOps** contains all platform-level components: the API Gateway (Traefik v3), relational databases (MySQL + PostgreSQL), the message queue (RabbitMQ), object storage (MinIO / Cloudflare R2), and the media server (MediaMTX) handling RTMP ingest, HLS packaging, and WebRTC distribution.

---

## Quality Attributes
### Security

For this quality attribute we used 4 different patterns to overcome 4 different scenarios

#### Secure Channel

---

##### Scenario
  - **Source:** A user enrolled as a student in a course that uses the Blume platform.
  - **Stimulus:** They wish to modify the grades of the course in which they are enrolled. In this example, student Ana García Morales failed the 2nd Midterm of Computer Networks.

  ![secure_channel_1](diagrams/secure_1.jpeg)


  - **Environment:** The system is operating under standard conditions. *Traefik* offers HTTP services on port 80, with Spring Boot using a standard cookie configuration. Before implementing HTTPS, it is possible to exploit the system by obtaining the identity validation cookie through external means, as shown in this example:

  ![secure_channel_2](diagrams/secure_2.png)
  ![secure_channel_3](diagrams/secure_3.jpeg)
  ![secure_channel_4](diagrams/secure_4.jpeg)

  In this example, using `tcpdump`, at the moment the professor logs in on a public network, the student can access the traffic generated by the login event. In the initial state, the user's username and password are not sent directly, but a cookie (*blume_session*) is transmitted, which is used by the server to verify the user's identity. Once this cookie is obtained, along with other easily accessible information such as the user's internal class ID or the evaluation ID, a command can be sent to modify the grade — using the professor's cookie to impersonate them and submit a request to the backend. The web frontend confirms that the request successfully modified the grade, without the professor having made this change directly.

  - **Response:** A TLS certificate is obtained and deployed to encrypt the system's network traffic.
  - **Response Measure:** Basic network inspection tools such as `tcpdump` confirm that all intercepted traffic is encrypted, and the user cannot access the cookie required for authentication.
  ![secure_channel_5](diagrams/secure_5.jpeg)
  ![secure_channel_6](diagrams/secure_6.jpeg)

  In our example, we run the same command after having implemented the HTTPS pattern and its corresponding CA  certificates to protect the system's traffic. Running `tcpdump` no longer allows content to be viewed through ports 80 or 443, which are used for system communication. After implementing HTTPS, `tcpdump` only captures encrypted bytes and produces no interpretable output. Since the content cannot be interpreted, the cookie is transmitted securely, and the attacker cannot make any requests, as they have no way to impersonate the professor without their credentials.

- WireShark
![wireshark](diagrams/secure_7.jpeg)

To further validate the effectiveness of the encryption mechanism, a network analysis was conducted using Wireshark. For this test, traffic was captured on a wireless network interface. A mobile device connected to the same local network was used to access and navigate the Blume web interface hosted on the deployment machine.

As captured in the log below, the network traffic was successfully intercepted. However, the packet details confirm that all payload data remains fully encrypted. The capture clearly identifies the source IP (the mobile device) and the destination IP (the host computer running the application), proving that while the communication path is visible, the sensitive contents—including session tokens and application data—are completely shielded from unauthorized inspection.

#### Characteristics
  - **Threat:** Malicious agent with network access
  - **Attack:** Network traffic interception
  - **Weakness:** With HTTP, information travels in plain text
  - **Vulnerability:** An attacker could eavesdrop on traffic, compromising confidentiality
  - **Risk:** Theft, exposure, or modification of sensitive information in transit
  - **Countermeasure:** Implement HTTP/TLS to encrypt communication and protect data in transit

#### Architectural Tactics

##### Detect

  For early threat detection, the following tactics are implemented:

  - **Verify Message Integrity:** At the transport layer, TLS provides HMAC-based integrity verification, ensuring that messages cannot be tampered with in transit.

##### Resist

  To resist attacks, the following tactics are implemented:

  - **Encryption:** The TLS certificate encrypts all HTTP connector traffic routed through *Traefik*. RTMP stream  ingestion (port 1935) currently remains unencrypted, as RTMPS is not yet configured.
  - **Actor Authentication:** Authentication relies on session cookies (`blume_session`) rather than sending raw  credentials with every request. However, as the scenario demonstrates, the session cookie is itself equally sensitive: over plain HTTP it is transmitted in clear text and can be intercepted, which is precisely why TLS is required to protect it.
  - **Limit Exposure:** Public access to sensitive ports is removed: port 15672 for RabbitMQ and ports 9000 and 9001 for MinIO. The Traefik API/dashboard is fully disabled via `--api.insecure=false`. Ports 8889 (MediaMTX WebRTC) and 1935 (RTMP ingestion) remain publicly exposed for operational reasons.
  - **Change Default Configuration:** In addition to limiting exposure, default usernames and passwords for management dashboards were changed, in case an attacker is able to bypass the limited exposure barrier.

##### React

  The following tactics are implemented to respond promptly and efficiently to a successful attack:

  - **Inform:** HSTS prevents browsers from sending requests over plain HTTP, protecting against downgrade attacks in which a man-in-the-middle could strip HTTPS and redirect traffic to plain HTTP.

##### Recover

  In the current implementation, the Secure Channel pattern does not handle the Recover portion of the Security Tactics.


#### Architectural Pattern

  The **Secure Channel** pattern consists of a design applied to a system's connectors — in this case using the HTTP protocol — over which an encryption algorithm is applied to protect the content of its traffic from external actors. In this case, the TLS protocol is used to encrypt the information transmitted by the previously implemented HTTP connectors. For this delivery, the pattern was correctly implemented in the local deployment of the system, on all HTTP connectors that use the *Traefik* API Gateway. It is implemented as follows:

  The new version of `infrastructure/traefik/dynamic.yml` defines the use of the HTTPS protocol as follows:

  ```yml=
  routers:
      nextAuthClearSession:
        rule: "Path(`/api/auth/clear-session`)"
        entryPoints: ["websecure"]
        middlewares: ["hsts"]
        priority: 20
        service: blume_wa
        tls: {}
```
  For each router, it defines websecure as the entrypoint — requiring HTTPS for every router — along with HSTS as
  middleware. The same file defines the TLS configuration as follows:
```yml=
  tls:
    certificates:
      - certFile: /etc/traefik/certs/blume-gateway.crt
        keyFile: /etc/traefik/certs/blume-gateway.key
    options:
      default:
        minVersion: VersionTLS12
        cipherSuites:
          - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
          - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
          - TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256
```
This includes the location of the TLS certificate (which contains the server's public key) and the corresponding private key used to establish encrypted connections. In the current configuration, applied locally, these are generated via an automatic key generation script at `infrastructure/security/generate-certs.sh`, though these certificates are not compatible across hosts.

  The docker-compose.yml in infrastructure includes the following commands:
```yml=
  --entrypoints.web.http.redirections.entrypoint.to=websecure
  --entrypoints.web.http.redirections.entrypoint.scheme=https
   ```
These instruct the system that when a connection is attempted on an HTTP port (port 80), it is immediately redirected to HTTPS before any application content is exchanged — subtly preventing the use of HTTP without directly blocking the user's request (provided the security policy is met, of course).


#### Reverse Proxy
---
##### Scenario
- **Source:** An external attacker or automated scanner attempting to map the internal architecture of the Blume platform.
- **Stimulus:** The attacker scans the host for open ports and attempts to communicate directly with internal microservice endpoints — for example, the Spring Boot business logic service on port 8082, the Go stream engine on port 8080, the Elixir/Phoenix activities service on port 4000, or the record service on port 8081. Alternatively, the attacker tries to access the Traefik administration dashboard to extract the internal routing table.
- **Environment:** The system is running under normal conditions. The host exposes only the following ports: 80 (HTTP, immediately redirected to HTTPS), 443 (HTTPS via Traefik), 1935 (RTMP for OBS streaming), and 8889 (WebRTC/WHEP for MediaMTX). All internal microservice ports are bound exclusively to Docker internal networks.

  The attacker runs a port scan and attempts direct connections:
  ```bash
  # Attacker attempts to reach internal services directly
  nc -zv localhost 8082   # Spring Boot — business logic
  nc -zv localhost 8080   # Go — stream engine
  nc -zv localhost 8081   # Go — record service
  nc -zv localhost 8000   # Python — recommendations
  nc -zv localhost 4000   # Elixir/Phoenix — activities
  nc -zv localhost 8888   # MediaMTX HTTP API

  # Attacker attempts to extract the routing table from the Traefik dashboard
  curl -s http://localhost:8080/api/rawdata
  ```

  All attempts return `Connection refused` — no service is reachable on those ports from the host. The Traefik admin API is also disabled (`--api.insecure=false`), so the internal routing configuration cannot be extracted. The internal DNS names (`blume-business-logic-ms`, `blume_stream_ms`, etc.) are resolvable only inside the `blume_app` Docker network and are never communicated to any external client.
  
- **Response:** The reverse proxy (Traefik) is the exclusive external contact point. All client requests must enter through port 443. Traefik inspects each request's URL path, matches it against its routing table, and forwards it to the correct internal service — without the client ever knowing the target service's address, port, or technology stack. The backend service responds to Traefik; Traefik relays the response back to the client.

  A legitimate request successfully routes through the proxy:
  ```bash
  # Only Traefik's port is reachable — internal topology is invisible to the caller
  curl -k -s -o /dev/null -w "%{http_code}" https://localhost/api/auth/login
  # → 401 (routed internally to blume-business-logic-ms:8082, unknown to the caller)

  curl -k -s -o /dev/null -w "%{http_code}" https://localhost/api/v1/recommendations
  # → 200 (routed internally to blume_recomendations_ms:8000, unknown to the caller)
  ```

- **Response Measure:** (1) `nc -zv localhost <port>` returns `Connection refused` for all internal service ports (8082, 8080, 8081, 8000, 4000, 8888). (2) `curl http://localhost:8080/api/rawdata` returns `Connection refused` — the Traefik admin API is disabled. (3) HTTP responses are returned for valid paths through port 443 only. (4) No internal hostname, IP, or port number appears in any HTTP response header received by the client.

![reverse_proxy](diagrams/scenario_1.jpeg)

---
##### Characteristics
- **Threat:** Reconnaissance and direct exploitation of internal microservice endpoints.

- **Attack:** Port scanning and direct connection to backend service ports; extraction of the internal routing topology via the Traefik admin API; crafting raw HTTP requests aimed at bypassing gateway-level controls (authentication middleware, path validation) by contacting backend services directly.

- **Weakness:** Without a reverse proxy, each microservice would need to be independently exposed on the host network, multiplying the attack surface and eliminating any centralized enforcement point. An attacker who discovers a backend port can communicate with that service as if they were the gateway.

- **Vulnerability:** If internal service ports were published to the host, an attacker could bypass Traefik entirely and send requests directly to Spring Boot (:8082), Go (:8080), or Phoenix (:4000) — potentially bypassing the JWT validation middleware and TLS enforcement that are applied at the application layer, not at the transport layer.

- **Risk:** Direct access to unauthenticated internal endpoints could allow unauthorized data reads, state mutation, or exploitation of service-specific vulnerabilities without passing through any centralized security boundary.

- **Countermeasure:** The Reverse Proxy pattern, implemented via Traefik, acts as a single choke point: all inbound HTTP/HTTPS traffic is funneled through it, internal service ports are never published to the host, and the routing configuration that reveals the internal topology is inaccessible from outside the container network.

##### Architectural Tactics

###### Detect

- **Monitor:** Traefik's access log records every incoming request with its source IP, URL path, HTTP status, and response latency. This provides a centralized audit trail for all traffic entering the system — anomalous patterns (high 404 rates from a single IP, unusual path probing, scanning signatures) are visible in a single log stream without requiring each microservice to implement its own access logging.

###### Resist

- **Limit Exposure:** Internal microservice ports (8082, 8080, 8081, 8000, 4000, 8888) are declared only on the `blume_app` Docker network and are never published to the host via a `ports` mapping. The Traefik management API is disabled via `--api.insecure=false`, preventing an attacker from extracting the routing table even if they reach the gateway host.
- **Authenticate Actors:** Because Traefik is the sole entry point, it becomes the natural location to enforce cross-cutting security policies. TLS termination (Scenario 1) and the path-based routing rules that forward requests to JWT-protected services (Scenario 4) are all applied at this single point before any backend service is reached.
- **Limit Access:** The routing table in `traefik/dynamic.yml` explicitly declares which paths are routable. A request to an undeclared path will not match any router and will receive a 404 — no internal service is accidentally reachable via an undocumented URL.

###### React

- **Inform:** HSTS headers (applied by the `hsts` middleware on every router) instruct browsers to never attempt plain HTTP connections, preventing downgrade attacks that could circumvent the HTTPS entry point.

###### Recover

In the current implementation, the Reverse Proxy pattern does not define explicit recovery tactics beyond the `restart: unless-stopped` policy on the Traefik container, which ensures the proxy is automatically restarted if it crashes.

##### Architectural Pattern

The **Reverse Proxy** pattern interposes a dedicated intermediary component between external clients and a set of internal services. From the client's perspective, there is exactly one server — the proxy. Internally, there is an arbitrary number of services at different addresses and ports. The proxy owns the mapping between public URL paths and internal backends; this mapping is never disclosed to clients.

In Blume, this pattern is implemented by Traefik. Its configuration in `infrastructure/traefik/dynamic.yml` defines a routing table that maps URL path prefixes to internal services by priority:

```yml
routers:
  recommendations:
    rule: "PathPrefix(`/api/v1`)"
    entryPoints: ["websecure"]
    middlewares: ["hsts"]
    priority: 15
    service: recommendations
    tls: {}
  business:
    rule: "PathPrefix(`/api`)"
    entryPoints: ["websecure"]
    middlewares: ["hsts"]
    priority: 10
    service: business
    tls: {}
  frontend:
    rule: "PathPrefix(`/`)"
    entryPoints: ["websecure"]
    middlewares: ["hsts"]
    priority: 1
    service: blume_wa
    tls: {}

services:
  recommendations:
    loadBalancer:
      servers:
        - url: "http://blume_recomendations_ms:8000"
  business:
    loadBalancer:
      servers:
        - url: "http://blume-business-logic-ms:8082"
  blume_wa:
    loadBalancer:
      servers:
        - url: "http://blume_wa:3000"
```

A client that sends `GET /api/v1/recommendations` to `https://blume-host` receives a response from the Python FastAPI service running at `blume_recomendations_ms:8000` — without ever knowing that address. Priority values resolve overlapping prefixes deterministically: `/api/v1/something` matches `recommendations` (priority 15) rather than `business` (priority 10).

The `docker-compose.yml` enforces the network invariant that makes this possible:

```yml
traefik:
  ports:
    - "80:80"
    - "443:443"
  networks:
    - blume_edge
    - blume_app

blume-business-logic-ms:
  # no 'ports' mapping — only reachable on blume_app
  networks:
    - blume_app
    - blume_data
```

Traefik sits on both `blume_edge` (reachable from the host) and `blume_app` (reachable from services). Backend services sit only on `blume_app` with no `ports` entry — they are unreachable from the host by construction. The proxy is the only component that bridges both networks, making it the mandatory path for all external traffic.


#### Network segmentation
---
An architectural security pattern that divides a network infrastructure into multiple isolated logical subnets, applying strict access policies between them to contain potential breaches and prevent unauthorized lateral movement. The primary advantage of this pattern is the significant reduction of the system's attack surface by enforcing the principle of least privilege at the network level. In Blume, this is implemented by segregating the container architecture into three distinct Docker networks: `blume_edge` (acting as a DMZ for perimeter traffic via Traefik), `blume_app` (a private network for application microservices), and `blume_data` (an internal network configured with `internal: true`). This ensures that infrastructure components like databases (`MySQL`, `PostgreSQL`), object storage (`MinIO`), and message brokers (`RabbitMQ`) have no host-level port exposure and can exclusively receive traffic from authorized microservices attached to their segment.
##### Scenario
- **Source:** 	
Bad external actor or compromised process in the edge zone (blume _edge: Traefik, frontend), that tries to reach resources in interal layers without authorizaton. Includes: Attacker in the host's network, container in DMZ after explotation, or automatic port scanning.
- **Stimulus:** 	
Direct network access attempt to data and message services (MySQL :3306, PostgreSQL :5432, RabbitMQ :5672, MinIO :9000) without going through the HTTP gateway (Traefik) or the authorized app logic. Examples: nc mysql 3306, scanning of ports in the host, JDBC/AMQP connection from a container only on blume_edge.

- **Environment:** 
Local deployment with Docker Compose in a node (three networks: blume_edge, blume_app, blume_data with interal:true). Conceptual parity with production in AWS (public/private subnets, Security Groups ALB → ECS → RDS). The system is in normal operation (deployed stack, users can use HTTP in :80).

- **Response:**
The system denies unauthorized TCP conections between zones: the DMZ and the application layer without data attatchment dont establish session with DB, queue or storage. The legimate traffic of users keeps entering by Traefik (:80); the microservices that require persistance access blume_data only if they are in blume_app and blume_data.

- **Response measure:**
(1) 0 successful connections from probe in blume_edge towards mysql, recording-mysql, postgres, rabbitmq and minIO (automated test). (2) 0 connections from probe only in blume_app towards mysql and rabbitmq. (3) Connection permitted only from probe with networks blume_app + blume_data (simulates legitimate microservice). (4) Edge availability: HTTP 200 in public routes via Traefik (i.e. /, /api/v1/health). (5) Surface on host: ports of not published data (3306, 5672, 9000 not mapped to host). Acceptance criteria: run-test.sh script ends with exit code 0 and 12/12 PASS comprobations. 

![network_segmentation](diagrams/scenario_2.jpeg)

---
##### Characteristics

* **Threat:**
Unauthorized access to sensitive data and lateral movement from a lower-trust component (frontend/DMZ) toward critical infrastructure (credentials in DB, messages in RabbitMQ, recordings in MinIO). Objectives: theft of user/channel data, manipulation of recording queues, denial of service on persistence layers.
* **Attack:** 	
(1) Scanning and direct connection to DB/queue/storage ports exposed on the host or within a shared flat network. (2) Pivoting from a compromised edge container toward MySQL/PostgreSQL using default or leaked credentials. (3) Bypassing the API Gateway by calling microservices or databases via internal IP/port without application-layer authentication.
* **Weakness:** 	
Deployment architecture with a single network plane (`blume_net`): all containers share the same logical Docker L2/L3 segment; there is no separation between DMZ / application / data. This allows any compromise in a service to reach any other open port via DNS name (`mysql`, `rabbitmq`).
* **Vulnerability:**
Exposure of infrastructure ports to the host (3306, 5672, 15672, 9000, 9001) and lack of isolation between Docker networks: a process on the host or in an edge container can open a TCP session against MySQL/RabbitMQ/MinIO without passing through application-layer controls (JWT, business authorization).
* **Risk:**
High in the unsegmented state (medium-high probability × high impact): direct exposure of personal and business data, potential data exfiltration or DB deletion, abuse of recording queues. Medium-low after the countermeasure: direct attack from DMZ/app without data access is blocked; residual risks persist (ports :4000, RTMP/WebRTC, `/internal/*` routes via Traefik, weak credentials in RabbitMQ).
* **Countermeasure:**
Tactic: network segmentation. Implementation: (1) three Docker networks (`blume_edge`, `blume_app`, internal `blume_data`); (2) minimal network attachment per service (only microservices requiring it join `blume_data`); (3) removal of `ports` mapping in data services; (4) Traefik :80 as the single public HTTP endpoint; (5) MinIO accessed via `/storage` in the gateway; (6) on AWS: VPC, public/private subnets, Security Groups (ALB → ECS → RDS). Verification: `tests/security/network-segmentation/run-test.sh`
* Network Segmentation Table:

| Service | `blume_edge` | `blume_app` | `blume_data` |
| --- | --- | --- | --- |
| traefik | ✓ | ✓ |  |
| blume_wa | ✓ | |  |
| Microservices (Spring, Go, FastAPI, Phoenix) |  | ✓ | ✓ if using DB/queue/storage |
| blume_recommendations_ms |  | ✓ |  |
| mysql, postgres, rabbitmq, recordings-mysql |  |  | ✓ |
| minio |  | ✓ | ✓ (S3 API only from app; public via Traefik `/storage`) |
| mediamtx |  | ✓ |  |

Network segmentation is primarily a **Resist / Prevent** tactic: *isolation* between zones, *communication path control*, and *least privilege* connectivity to contain lateral movement before damage occurs.

##### Architectural Tactics

###### Detect

- **Monitor:** Traefik's access log records every incoming request with its
source IP, URL path, HTTP status, and response latency. Any attempt to reach
an undeclared path returns a 404 that is visible in the centralized log
stream, exposing port-scanning and probing patterns without requiring each
microservice to implement its own access logging.

###### Resist

- **Separate Entities:** Three distinct Docker networks are defined —
`blume_edge` (public-facing DMZ), `blume_app` (application tier), and
`blume_data` (persistence tier, declared with `internal: true`). Docker
enforces physical isolation between them: a container on `blume_edge` cannot
open a socket to any host on `blume_data` because there is no routing path
between the two networks.
- **Limit Exposure:** No data-layer service (`mysql`, `recordings-mysql`,
`postgres`, `rabbitmq`, `minio`) publishes a `ports` mapping to the host.
Their ports are accessible only through the `blume_data` internal network,
which has no host-level or edge-level interface.
- **Limit Access:** The routing table in `traefik/dynamic.yml` declares only
the paths that are intentionally routable. Requests to undeclared paths
receive a 404 — no internal service is reachable through an undocumented
URL.
- **Authenticate Actors:** Only services explicitly attached to both
`blume_app` and `blume_data` can resolve the data-service Docker DNS names
(`mysql`, `rabbitmq`, etc.). A container present only on `blume_edge` or
`blume_app` without `blume_data` attachment fails DNS resolution before any
TCP connection is attempted.

###### React

- **Inform:** HSTS headers on every Traefik router prevent browsers from
downgrading connections to plain HTTP, eliminating a class of interception
vectors that could otherwise be used to extract internal topology details
from response headers.

###### Recover

In the current implementation, the Network Segmentation pattern does not
define explicit recovery tactics. The `restart: unless-stopped` policy on
all containers ensures automatic restart after a crash, but no
point-in-time restore or audit trail mechanism has been implemented.

---

##### Architectural Pattern

The **Network Segmentation** pattern divides the infrastructure into
isolated logical zones with explicitly controlled trust boundaries between
them. Access between zones is not merely restricted — it is structurally
impossible at the network level for non-authorized paths.

In Blume, this is implemented through three Docker networks in
`docker-compose.yml`:

```yml
networks:
  blume_edge:
  blume_app:
  blume_data:
    internal: true
```

The `internal: true` flag on `blume_data` instructs Docker to create a
network with no external routing — not even to the host. Services are
attached to the minimum set of networks their function requires:

| Service | blume_edge | blume_app | blume_data |
|---|---|---|---|
| traefik | ✓ | ✓ | |
| blume_wa | ✓ | | |
| Microservices (Spring, Go, FastAPI, Phoenix) | | ✓ | ✓ (if DB/queue needed) |
| blume_recommendations_ms | | ✓ | |
| mysql, postgres, rabbitmq, recordings-mysql | | | ✓ |
| minio | | ✓ | ✓ |
| mediamtx | | ✓ | |

A container on `blume_edge` cannot initiate a connection to `blume_data`
because Docker provides no route between them. Traffic must flow
Edge → App → Data, and only microservices that legitimately require
database or queue access are placed on `blume_data`. This enforces
least-privilege connectivity at the infrastructure level, independent of
any application-layer authentication.



#### Token-based Authentication Pattern

---
##### Scenario
- **Source:** A malicious student or an external attacker.

- **Stimulus:** They attempt to start a live stream on MediaMTX (an action reserved for professors), or try to connect to the real-time chat by impersonating another user.

- **Environment:** The system is operating under normal conditions. Without token validation at each service boundary, any request that reaches `blume_stream_ms` or `blume_stream_activities_ms` would be processed regardless of the caller's identity or role.

  The attacker attempts three different unauthorized actions:

  ```bash
  # Attack 1 — Attempting to publish an RTMP stream without credentials
  curl -k -s -X POST https://localhost/auth/mediamtx \
    -H "Content-Type: application/json" \
    -d '{"action":"publish","path":"/live/stream-key","query":"","ip":"1.2.3.4"}'

  # Attack 2 — Forging a JWT to claim the PROFESSOR role (wrong secret)
  FAKE_TOKEN="eyJhbGciOiJIUzI1NiJ9.eyJyb2xlQ29kZSI6IlBST0ZFU1NPUiJ9.INVALIDSIG"
  curl -k -s -H "Cookie: blume_session=$FAKE_TOKEN" https://localhost/api/channels

  # Attack 3 — Connecting to the real-time chat WebSocket without a token
  wscat --no-check -c "wss://localhost/socket/websocket"
  ```

  In all three cases, the request reaches the respective service (Go, Spring Boot, Elixir/Phoenix) where JWT verification is enforced independently.

- **Response:** Each service verifies the JWT signature cryptographically before executing any business logic. If the token is absent, forged, expired, or carries an insufficient role, the request is immediately rejected — an HTTP 401/403 is returned or the WebSocket handshake is closed — without consulting any external service or shared session store.

  ```bash
  # Attack 1 — No token: rejected by Go mediamtx_handler.go
  # → 401 Unauthorized: "unauthorized: missing token"

  # Attack 2 — Invalid signature: rejected by Spring Boot JwtAuthFilter.java
  # → 403 Forbidden (user treated as anonymous, access denied by Spring Security)

  # Attack 3 — No token: rejected by Elixir/Phoenix UserSocket.connect/3
  # → Connection closed — :error returned before any resource is allocated
  ```

  An additional integrity check demonstrates that even a valid token with a modified payload is rejected:

  ```bash
  # Tampered payload: student changes roleCode to PROFESSOR in the JWT body
  # Any change to header or payload invalidates the HMAC signature
  TAMPERED="<base64url(header)>.<base64url(payload_with_roleCode_PROFESSOR)>.<original_sig>"
  curl -k -s -o /dev/null -w "%{http_code}" \
    -H "Cookie: blume_session=$TAMPERED" https://localhost/api/channels
  # → 403 Forbidden — signature mismatch detected
  ```

- **Response Measure:** (1) Requests without a token to `/auth/mediamtx` return 401. (2) Requests with a forged or tampered JWT to `/api/*` return 403. (3) WebSocket connection attempts without a `token` parameter are rejected before any channel is joined. (4) Student tokens attempting the `publish` action return 403 from `mediamtx_handler.go`. (5) All checks pass in under 100ms, with no impact on legitimate authenticated users. Full automated verification: `tests/security/jwt-reverse-proxy/run-test.sh`.

![jwt](diagrams/scenario_4.jpeg)

---
##### Characteristics
- **Threat:** Unauthorized access to professor-exclusive features (live streaming); identity spoofing in the real-time chat.

- **Attack:** (1) Attempting to publish an RTMP stream without credentials; (2) connecting to a WebSocket channel without a token; (3) forging a JWT with a self-assigned `PROFESSOR` role using a wrong secret; (4) tampering with the payload of a legitimately obtained token to escalate privileges.

- **Weakness:** Without decentralized token validation, each service would need to either query a central authentication service on every request — creating a single point of failure and a performance bottleneck — or blindly trust all requests forwarded by Traefik, which provides no identity guarantees.

- **Vulnerability:** If JWT verification is not enforced at the individual service level, an attacker who bypasses Traefik (e.g. by exploiting the network weakness described in Scenario 3) could reach services that trust all incoming connections, gaining unauthorized access to streaming and chat resources.

- **Risk:** A student posing as a professor could hijack the RTMP publish slot and disrupt a live class session; an attacker could flood the real-time chat under any fabricated identity, compromising the integrity of live interactions.

- **Countermeasure:** Stateless JWT-based authentication applied independently at all three service boundaries (Spring Boot, Go, Elixir/Phoenix), sharing only the cryptographic secret (`JWT_SECRET`). No shared session store is required; each service can verify identity and role autonomously.

##### Architectural Tactics

###### Detect

- **Verify Message Integrity:** The HMAC signature of the JWT acts as an integrity mechanism. Any alteration to the header or payload — even a single byte — produces a completely different signature, which the receiving service detects and rejects. This allows each service to independently confirm that the token has not been tampered with since it was issued by the trusted authority (Spring Boot).

###### Resist

- **Authenticate Actors:** Each service cryptographically validates the JWT signature using the shared `JWT_SECRET` with the HMAC algorithm (HS256/HS384). A token signed with any other key — or one whose payload has been altered — is rejected before any business logic executes.
- **Authorize Actors:** Beyond authentication, `mediamtx_handler.go` enforces role-based access control: the `roleCode` claim must equal `PROFESSOR` for `publish` actions. Role information is embedded in the token itself, so no database query is needed to make the authorization decision.
- **Identify Actors:** `StreamActivitiesWeb.UserSocket` extracts `userId` and `username` from the verified token and binds them to the WebSocket connection state (Socket Assigns). Every chat message sent over that connection is cryptographically tied to the validated sender identity.
- **Limit Exposure:** Token expiration (`JWT_EXPIRATION_SECONDS`) serves as the revocation mechanism—a compromised token becomes invalid once it expires, reducing the attack window without requiring server-side state.

###### React

In the current implementation, the Token-based Authentication pattern does not define explicit reaction tactics. If a token is compromised before it expires, no active revocation mechanism is in place; the attack window is bounded by `JWT_EXPIRATION_SECONDS`.

###### Recover

In the current implementation, the Token-based Authentication pattern does not handle explicit recovery mechanisms.

##### Architectural Pattern

The **Token-based Authentication** pattern (also known as **Bearer Token** or **Stateless Auth**) delegates authentication state from the server to the client. Instead of maintaining server-side sessions — which would require a shared session store across microservices — the server issues a cryptographically signed token at login time. The client attaches that token to every subsequent request; each receiving service verifies the signature independently, without consulting any database or central authority.

This pattern is structurally essential in a microservices architecture: since Spring Boot, Go, and Elixir/Phoenix are completely independent processes, sharing session state between them would require additional infrastructure (Redis, a shared database). The JWT eliminates that need — the shared secret (`JWT_SECRET`) is the only dependency among the three verifiers.

In Blume, the token is generated in `JwtTokenAdapter.java` at login time:

```java
// JwtTokenAdapter.java — token generation in Spring Boot
String token = Jwts.builder()
    .subject(userInfo.email())
    .claim("userId",   userInfo.userId().toString())
    .claim("username", userInfo.username())
    .claim("roleCode", userInfo.roleCode())   // authorization claim read by Go and Elixir
    .issuedAt(now)
    .expiration(expiry)
    .signWith(key)   // HMAC-SHA, key derived from JWT_SECRET
    .compact();
```

The token travels as an `httpOnly` cookie (`blume_session`). Each microservice verifies it autonomously:

- **Spring Boot — `JwtAuthFilter.java`:** Intercepts every HTTP request, extracts the token from the cookie, calls `validateSession.validate(token)` (which delegates to `JwtTokenAdapter.parse()`), and populates the `SecurityContext` with the authority `ROLE_<roleCode>`. If the token is invalid or absent, the user remains anonymous and Spring Security enforces the path-level access restrictions.

- **Go — `mediamtx_handler.go`:** Extracts the token from the `?token=` query param that MediaMTX forwards in the webhook payload. It verifies it with `jwt.Parse()`, accepting any HMAC variant (HS256, HS384, HS512), and applies the hard business rule: only `roleCode == "PROFESSOR"` may execute the `publish` action. For `read` actions, any authenticated user is accepted.

- **Elixir/Phoenix — `StreamActivitiesWeb.UserSocket`:** The `connect/3` callback verifies the token using the `Joken` library, trying HS256 first and then HS384 for compatibility with the algorithm `jjwt` selects based on key length. If verification fails, it returns `:error` and the WebSocket connection is never established — the attacker consumes no chat server resources.

All three verifiers are **stateless** and **independent**: they can scale horizontally without coordination. The pattern is implemented as follows in `docker-compose.yml`, where the single shared secret is injected as an environment variable into every service that needs to verify tokens:

```yml
blume-business-logic-ms:
  environment:
    JWT_SECRET: ${JWT_SECRET}          # issues tokens

blume_stream_ms:
  environment:
    JWT_SECRET: ${JWT_SECRET}          # verifies tokens (Go)

blume_stream_activities_ms:
  environment:
    JWT_SECRET: ${JWT_SECRET}          # verifies tokens (Elixir)
```

No service needs to call another to validate a token — the shared secret is the entire trust contract.


### Performance and Scalability - Lab 6

---
#### Scenario

- **Feature under test:** Explore Public Class Catalog —
`GET /api/cursos/explorar`

- **Source:** Virtual users simulated by k6, representing concurrent students or unauthenticated visitors browsing the public course catalog.

- **Stimulus:** A progressive ramp of concurrent HTTP requests to the `/api/cursos/explorar` endpoint, escalating from 1 to 2000 virtual users (VUs) in five stages of 30 seconds each, followed by a ramp-down to zero.

- **Environment:** The system is deployed locally on a single host running Docker Compose. Load is generated from a separate physical machine on the same LAN, pointing to the server's local IP — ensuring the tester node does
not compete for resources with the system under test. The endpoint is public and requires no authentication (no JWT, cookies, or special headers). In its unoptimized state, the system runs a single replica of `blume_business_logic_ms`
with no in-memory cache: every request triggers a full SQL query to MySQL, making the HikariCP connection pool the primary bottleneck under concurrent load.

- **Response:** The system must serve all requests within an acceptable latency threshold across all load stages. The knee of the performance curve —the point where `http_req_failed` exceeds 0% and latency grows non-linearly —must be identified, and architectural tactics must be applied to shift it to the right.

- **Response Measure:** `http_req_duration (avg)` and `http_req_failed` (%) recorded at each VU stage: 1, 50, 200, 500, and 2000 virtual users. The knee of the curve is defined as the lowest VU count at which `http_req_failed > 0%`.

#### Applied architectural tactics

##### Control Resource Demand

- **Reduce Computational Overhead — In-Memory Caching with Spring @Cacheable:** The `getPublic()` method in `blume_business_logic_ms` is annotated with 
`@Cacheable(value="public-channels", sync=true)`. On the first request, the microservice queries MySQL and stores the result in RAM. All subsequent requests are served directly from the cache, bypassing the database entirely.
The `sync=true` parameter prevents cache stampede: when the cache is cold, only one thread executes the SQL query while the others wait, preventing 2000 simultaneous threads from hitting MySQL at the same time. Combined with the three replicas, MySQL receives at most 3 queries total — one per replica warm-up — regardless of the total number of concurrent users.

##### Manage Resources

- **Introduce Concurrency — Load Balancing with Multiple Replicas:** Three replicas of `blume_business_logic_ms` are configured in `docker-compose.yml`
using the `deploy.replicas: 3` directive. *Traefik* automatically detects all three instances through Docker's internal DNS and distributes incoming traffic among them using round-robin. Under a load of 2000 VUs, each replica handles approximately 667 concurrent users instead of 2000, reducing the pressure on each instance's HikariCP connection pool individually and tripling the system's overall concurrency capacity.


##### Load Balancing with Multiple Replicas

3 replicas of the Java microservice were configured in `docker-compose.yml` using the `deploy.replicas: 3` directive. Traefik automatically detects the three instances through Docker's internal DNS and distributes incoming traffic among them using round-robin.

```yaml
blume_business_logic_ms:
  image: blume/business-logic:latest
  deploy:
    replicas: 3
```

With 3 replicas, each instance receives approximately one third of the total traffic. In the 2000 VUs stage, each instance handles ~667 users instead of 2000, reducing pressure on each replica's HikariCP connection pool individually.

##### In-Memory Cache with Spring @Cacheable

In-memory caching was implemented using Spring Cache with the following modifications:

- `spring-boot-starter-cache` was added as a dependency in `pom.xml`.
- `@EnableCaching` was enabled in the main class `JavaBackendApplication`.
- The `getPublic()` method was annotated with `@Cacheable(value="public-channels", key="...", sync=true)`.

The `sync=true` parameter prevents the "cache stampede" problem: when the cache is cold, only one thread executes the query to MySQL; the others wait for the first result to be stored in the cache before serving their responses. This prevents 2000 simultaneous threads from hitting the database at the same time.

**Combined effect:** the 2000 VUs load is split across 3 replicas (~667 VUs each), and each replica only executes 1 query to MySQL (the first request that warms up the cache). All subsequent requests are served directly from RAM, eliminating the database bottleneck.

#### Performance Testing Analysis and Results


##### Environment Setup

###### Deployed Components

| Component | Technology | Detail |
|---|---|---|
| Database | MySQL 8.4 | Docker container, HikariCP pool max. 10 connections |
| Microservice | Java 21 / Spring Boot 3.3.5 | blume_business_logic_ms — business logic service |
| API Gateway | Traefik v3.3 | HTTPS, port 443, TLS terminated at the gateway |
| Frontend | Not deployed | Not required: the tested endpoint is public and does not need an active user session |

###### k6 Script Used

k6 (Option 2) was used with progressive stages that simulate a load ramp from 1 to 2000 virtual users (VUs) and then ramp-down to zero:

```js
import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'https://localhost';

export const options = {
  insecureSkipTLSVerify: true,
  stages: [
    { duration: '30s', target: 1    },
    { duration: '30s', target: 50   },
    { duration: '30s', target: 200  },
    { duration: '30s', target: 500  },
    { duration: '30s', target: 2000 },
    { duration: '30s', target: 0    },
  ],
};

export default function () {
  const res = http.get(`${BASE_URL}/api/cursos/explorar`);
  check(res, { 'status is 200': (r) => r.status === 200 });
  sleep(1);
}
```

Execution command from the tester node:

```bash
k6 run --env BASE_URL=https://192.168.2.6 script.js
```

---

##### BEFORE Test — Unoptimized System

###### System State

- 1 replica of the Java microservice
- No in-memory cache
- HikariCP connection pool with maximum 10 connections to MySQL
- Traefik routing all traffic to the single available instance

###### Results Obtained

| Metric | Value |
|---|---|
| checks_total | ~10,180 |
| checks_succeeded | 99.01% (~10,080 of 10,180) |
| checks_failed | 0.99% (~100 of 10,180) |
| http_req_duration avg | 6.55 s |
| http_req_duration min | 15.02 ms |
| http_req_duration med | 2.52 s |
| http_req_duration max | ~60 s (timeout) |
| http_req_failed | 0.99% (~100 timeouts) |
| Completed iterations | ~10,056 |
| Interrupted iterations | 332 |
| Total duration | 3 min 29.8 s |

###### Behavior by Load Level

| VUs | Estimated avg latency | http_req_failed | Observation |
|---|---|---|---|
| 1 | ~20 ms | 0.00% | Normal |
| 50 | ~250 ms | 0.00% | Normal |
| 200 | ~1,200 ms | 0.00% | Degrading |
| 500 | ~3,500 ms | 0.00% | Saturated |
| 2,000 | ~12,000 ms | >0.99% | **KNEE OF THE CURVE** |

###### Degradation Analysis

The unoptimized system collapses in the 2000 VUs stage due to the following chain of causes:

- HikariCP is configured with a maximum of 10 simultaneous connections to MySQL. With 2000 concurrent users, waiting queues are generated to obtain a connection from the pool.
- When the pool is exhausted, requests are blocked waiting for a connection. HikariCP's timeout (30 seconds by default) is exceeded, generating exceptions that k6 records as http_req_failed.
- Cascading timeouts raise the global average latency to 6.55 s, despite the fact that under normal conditions (1 VU) the endpoint responds in ~20 ms.
- The median (2.52 s) being much lower than the average (6.55 s) confirms that failures are extreme outliers (60 s timeouts) that distort the average.

---

---

##### AFTER Test — Optimized System

###### System State

- 3 replicas of the Java microservice
- In-memory cache (Spring `@Cacheable` with `sync=true`)
- Traefik distributing traffic in round-robin among the 3 replicas
- HikariCP with maximum 10 connections per replica (30 total connections to the pool)

###### Results Obtained

| Metric | Value |
|---|---|
| checks_total | ~18,094 |
| checks_succeeded | 98.72% (~17,863 of 18,094) |
| checks_failed | 1.27% (~231 of 18,094) |
| http_req_duration avg | 3.51 s |
| http_req_duration min | 80 ms |
| http_req_duration med | 521 ms |
| http_req_duration max | ~60 s (timeout) |
| http_req_failed | 1.27% (~231 timeouts) |
| Completed iterations | ~18,005 |
| Interrupted iterations | 63 |
| Total duration | 3 min 28.5 s |

###### Behavior by Load Level

| VUs | Estimated avg latency | http_req_failed | Observation |
|---|---|---|---|
| 1 | ~80 ms | 0.00% | Normal |
| 50 | ~150 ms | 0.00% | Normal |
| 200 | ~400 ms | 0.00% | Normal |
| 500 | ~900 ms | 0.00% | Normal |
| 2,000 | ~6,000 ms | >1.27% | Shifted knee |

---

##### BEFORE vs AFTER Comparison Table

| VUs | BEFORE avg latency (ms) | AFTER avg latency (ms) | BEFORE errors | AFTER errors |
|---|---|---|---|---|
| 1 | 20 | 80 | 0.00% | 0.00% |
| 50 | 250 | 150 | 0.00% | 0.00% |
| 200 | 1,200 | 400 | 0.00% | 0.00% |
| 500 | 3,500 | 900 | 0.00% | 0.00% |
| 2,000 | 12,000 | 6,000 | 0.99% | 1.27%* |

\* The AFTER error rate is slightly higher because the system processed 78% more requests in the same time (18,094 vs 10,180), which exposes the real distribution of failures with greater fidelity.

---

##### Performance Chart

![knee](diagrams/knee.jpeg)


---

##### Conclusions

###### Identifying the Knee of the Curve

In the unoptimized system, the knee of the curve is located in the interval between 500 and 2000 concurrent virtual users. It is the point where `http_req_failed` exceeds 0% (0.99%) and the average latency makes a non-linear jump from 3,500 ms to 12,000 ms. This confirms that the bottleneck is HikariCP's connection pool: with 1 replica and a maximum of 10 connections, the system saturates its concurrency capacity to the database in that load range.

###### Impact of the Optimization Tactics

- The global average latency was reduced from 6.55 s to 3.51 s (46% reduction).
- The median latency dropped from 2.52 s to 521 ms (79% reduction), indicating that most requests now respond much faster.
- The optimized system processed 18,094 iterations compared to 10,180 in the original (78% more throughput in the same time).
- Interrupted iterations dropped from 332 to 63 (81% reduction), showing greater stability under extreme load.

###### Tactics and Their Relative Impact

The in-memory cache had the greatest individual impact. By eliminating queries to MySQL for repeated requests, the main bottleneck disappears: the endpoint goes from executing 3 SQL queries per request to executing 0 (except for the first one per replica). Load balancing complemented this improvement by tripling the system's concurrency capacity and distributing the cache warm-up load across the 3 replicas.

###### Shifting the Knee to the Right

The implemented tactics shifted the knee of the curve to the right: the optimized system sustains loads of up to 500 VUs with latencies below 1 second (900 ms), whereas in the original system 500 VUs already generated 3,500 ms. The knee of the optimized system persists in the 2000 VUs stage, but with lower latency (6,000 ms vs 12,000 ms) and higher total throughput.

###### Limitations of the Experiment

- The Blume frontend was not deployed during the tests. This does not affect the validity of the experiment: the tested endpoint is public and does not require authentication or an active user session.
- The tests were executed on a local network, not on the internet. The results are representative of the pure performance of the backend without WAN latency.
- The implemented cache is simple (in-memory, without explicit TTL). In production, it would be necessary to define invalidation policies for scenarios where the catalog is updated frequently.
- HikariCP is still limited to 10 connections per replica. An additional optimization would be to increase this limit based on the MySQL server's capacity.

## Link to repositories

The main repository of the whole Blume system it's the [infrastructure](https://github.com/Salon-1C/infrastructure) repository, which is part of the [Salon 1C](https://github.com/Salon-1C/infrastructure) organization where all other repositories are available.

### General structure

```text
1C/
├── infrastructure/              # Compose local, gateway, variables and execution documentation
├── blume_wa/                    # Next.js Frontend
├── blume_business_logic_ms/     # API Spring Boot (auth + business)
├── blume_stream_ms/             # API Go (streaming control + MediaMTX hooks)
├── blume_record_ms/             # Go service (recordings process and catalog)
├── blume_stream_activities_ms/  # Phoenix/Elixir (chat interactions and real-time operations)
├── blume_recommendations_ms/    # Recommendations engine
└── blume_ma/                    # Flutter mobile app (Android / iOS)
```

### Clone all repositories in one parent folder

To run everything with a single `docker compose up`, clone all repositories under the same parent directory:

```bash
mkdir -p 1C && cd 1C
git clone https://github.com/Salon-1C/infrastructure.git
git clone https://github.com/Salon-1C/blume_wa.git
git clone https://github.com/Salon-1C/blume_business_logic_ms.git
git clone https://github.com/Salon-1C/blume_stream_ms.git
git clone https://github.com/Salon-1C/blume_record_ms.git
git clone https://github.com/Salon-1C/blume_stream_activities_ms.git
git clone https://github.com/Salon-1C/blume_recommendations_ms.git
git clone https://github.com/Salon-1C/blume_ma.git
```

Expected folder layout:

```text
1C/
├── infrastructure/
├── blume_wa/
├── blume_business_logic_ms/
├── blume_stream_ms/
├── blume_record_ms/
├── blume_stream_activities_ms/
├── blume_recommendations_ms/
└── blume_ma/
```

Run with:

```text
cd ./1C/infrastructure

docker compose up
```