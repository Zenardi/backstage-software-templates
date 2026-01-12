- [🚀 Spring Boot 4.0 gRPC Service with Swagger/OpenAPI (Java 25)](#-spring-boot-40-grpc-service-with-swaggeropenapi-java-25)
  - [🛠 Tech Stack](#-tech-stack)
  - [⚡ gRPC vs. REST: Why this method?](#-grpc-vs-rest-why-this-method)
  - [📦 Getting Started](#-getting-started)
    - [Prerequisites](#prerequisites)
    - [1. Running Locally](#1-running-locally)
  - [📚 Swagger/OpenAPI Integration](#-swaggeropenapi-integration)
    - [Accessing Swagger UI](#accessing-swagger-ui)
    - [Available REST Endpoints](#available-rest-endpoints)
    - [Architecture](#architecture)
    - [2. Running with Docker](#2-running-with-docker)
    - [3. Running with Docker Compose](#3-running-with-docker-compose)
  - [🔐 Advanced: Mutual TLS (mTLS) Setup](#-advanced-mutual-tls-mtls-setup)
    - [Server Configuration (`application.yml`)](#server-configuration-applicationyml)
  - [🧪 Testing the Service](#-testing-the-service)
    - [Via Swagger UI (REST)](#via-swagger-ui-rest)
    - [Via cURL (REST)](#via-curl-rest)
    - [Via grpcurl (gRPC)](#via-grpcurl-grpc)
    - [Via Postman (gRPC)](#via-postman-grpc)
  - [🏗 Dependencies Used](#-dependencies-used)
  - [📂 Project Structure](#-project-structure)
  - [🔧 Configuration](#-configuration)


# 🚀 Spring Boot 4.0 gRPC Service with Swagger/OpenAPI (Java 25)

This repository contains a high-performance gRPC service with REST API wrappers and Swagger/OpenAPI documentation, scaffolded for 2026. It utilizes **Java 25 Virtual Threads** (Project Loom) and the **Official Spring gRPC** starter to deliver a scalable, "Zero Trust" microservice architecture with comprehensive API documentation.

## 🛠 Tech Stack

* **Java 25 (LTS):** Utilizing refined Virtual Threads for high-concurrency without thread-starvation.
* **Spring Boot 4.0:** The latest standard for native cloud integration.
* **Official Spring gRPC:** Integrated via `spring-grpc-spring-boot-starter`.
* **Swagger/OpenAPI 3.0:** Interactive API documentation via `springdoc-openapi`.
* **Dual Protocol Support:** Both gRPC (binary) and REST (JSON) endpoints.
* **Multiplexing:** Configured to run both REST and gRPC over **Port 8080** using HTTP/2.

---

## ⚡ gRPC vs. REST: Why this method?

| Feature | gRPC (Modern) | REST / JSON (Legacy) |
| --- | --- | --- |
| **Payload** | **Binary (Protobuf)** - ~40% smaller | **Text (JSON)** - Bulky & Verbose |
| **Protocol** | **HTTP/2** (Multiplexed) | **HTTP/1.1** (Sequential) |
| **Data Contract** | **Strict (`.proto`)**. Self-documenting | **Loose**. Needs external Swagger/OpenAPI |
| **Efficiency** | Extremely low CPU/Memory overhead | High parsing overhead |

---

## 📦 Getting Started

### Prerequisites

* **JDK 25** (e.g., Eclipse Temurin).
* **Docker** & **Docker Compose**.
* **grpcurl** (for CLI testing).

### 1. Running Locally

1. **Generate Java Stubs:**
```bash
./mvnw clean compile

```


2. **Start the Application:**
```bash
./mvnw spring-boot:run

```

The application will start on:
- **REST API + Swagger:** `http://localhost:8080`
- **Swagger UI:** `http://localhost:8080/swagger-ui.html`
- **gRPC Server:** Port `9090` (separate port for native gRPC)

---

## 📚 Swagger/OpenAPI Integration

This service provides **dual protocol support** - both gRPC and REST APIs for the same business logic.

### Accessing Swagger UI

Once the application is running, access the interactive API documentation:

**🌐 Swagger UI:** [http://localhost:8080/swagger-ui.html](http://localhost:8080/swagger-ui.html)

**📄 OpenAPI JSON Specification:** [http://localhost:8080/api-docs](http://localhost:8080/api-docs)

### Available REST Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/greet/hello/{name}` | Returns a greeting for the specified name (path parameter) |
| `POST` | `/api/greet/hello` | Returns a greeting for the name in request body |

**Example Request (GET):**
```bash
curl http://localhost:8080/api/greet/hello/World
```

**Example Response:**
```json
{
  "message": "Hello World from Java 25!"
}
```

**Example Request (POST):**
```bash
curl -X POST http://localhost:8080/api/greet/hello \
  -H "Content-Type: application/json" \
  -d '{"name": "John"}'
```

### Architecture

The REST endpoints are **wrappers** around the gRPC service:
- `GreeterRestController` calls `MyGreeterService` (gRPC implementation)
- Both protocols share the same business logic
- No code duplication - REST translates to gRPC internally



### 2. Running with Docker

The project uses a **multi-stage build** to separate the JDK (build-time) from the JRE (runtime) for security and size.

```bash
docker build -t grpc-service:latest .
docker run -p 8080:8080 grpc-service:latest

```

### 3. Running with Docker Compose

Launches the app, a PostgreSQL database, and Prometheus for observability.

```bash
docker compose up -d --build

```

---

## 🔐 Advanced: Mutual TLS (mTLS) Setup

For production, we use **mTLS** where both the client and server must present certificates. This is configured using **Spring SSL Bundles**.

### Server Configuration (`application.yml`)

```yaml
server:
  ssl:
    bundle: "server-bundle"
    client-auth: "need" # Forces client to provide a valid certificate

spring:
  ssl:
    bundle:
      jks:
        server-bundle:
          keystore:
            location: "classpath:server.p12"
            password: "changeit"
          truststore:
            location: "classpath:truststore.p12"

```

---

## 🧪 Testing the Service

This service supports multiple testing methods for both REST and gRPC protocols.

### Via Swagger UI (REST)

1. Open [http://localhost:8080/swagger-ui.html](http://localhost:8080/swagger-ui.html)
2. Expand the **Greeter API** section
3. Click **"Try it out"** on any endpoint
4. Enter parameters and click **"Execute"**

### Via cURL (REST)

**GET Request:**
```bash
curl http://localhost:8080/api/greet/hello/World
```

**POST Request:**
```bash
curl -X POST http://localhost:8080/api/greet/hello \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice"}'
```

### Via grpcurl (gRPC)

Since gRPC and REST share **Port 8080**, ensure you use the `-plaintext` flag only for local development.

```bash
grpcurl -plaintext -d '{"name": "John Doe"}' localhost:9090 com.example.grpc.Greeter/SayHello

```

**Note:** gRPC runs on port **9090** separately from REST (port 8080).

### Via Postman (gRPC)

1. New -> **gRPC Request**.
2. Enter `localhost:9090`.
3. Under "Service Definition", select **Server Reflection**.
4. Invoke `SayHello`.

---

## 🏗 Dependencies Used

* `spring-grpc-spring-boot-starter`: Native Spring integration for gRPC.
* `grpc-services`: Enables Server Reflection and gRPC Health Checks.
* `protobuf-maven-plugin`: Compiles `.proto` files into Java classes during the Maven `generate-sources` phase.
* `springdoc-openapi-starter-webmvc-ui`: Provides Swagger UI and OpenAPI 3.0 documentation for REST endpoints.

---

## 📂 Project Structure

```
src/main/
├── java/com/example/demo/
│   ├── DemoApplication.java           # Main Spring Boot application
│   ├── MyGreeterService.java          # gRPC service implementation
│   ├── config/
│   │   └── OpenApiConfig.java         # Swagger/OpenAPI configuration
│   └── controller/
│       └── GreeterRestController.java # REST API wrapper
├── proto/
│   └── hello.proto                    # Protocol Buffer definition
└── resources/
    └── application.yaml               # Application configuration
```

---

## 🔧 Configuration

**Key configuration in `application.yaml`:**

```yaml
spring:
  grpc:
    server:
      port: 9090                       # gRPC runs on dedicated port
      reflection-enabled: true         # Enable gRPC reflection

server:
  port: 8080                           # REST/Swagger runs here
  http2:
    enabled: true                      # Required for gRPC over servlet

springdoc:
  swagger-ui:
    path: /swagger-ui.html
  api-docs:
    path: /api-docs
```

