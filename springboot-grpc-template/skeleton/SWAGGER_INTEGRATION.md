# Swagger/OpenAPI Integration Documentation

## Overview

This document describes the Swagger/OpenAPI integration added to the gRPC Spring Boot application. The integration provides REST API wrappers around the existing gRPC services with comprehensive interactive documentation.

## Table of Contents

- [Architecture](#architecture)
- [Implementation Details](#implementation-details)
- [Components](#components)
- [Configuration](#configuration)
- [Usage Guide](#usage-guide)
- [API Documentation](#api-documentation)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

---

## Architecture

### Dual Protocol Design

The application now supports both gRPC and REST protocols:

```
┌─────────────────────────────────────────────┐
│         Client Applications                 │
└────────────┬────────────────┬───────────────┘
             │                │
             │                │
    ┌────────▼──────┐  ┌─────▼──────────┐
    │  REST Client  │  │  gRPC Client   │
    │  (HTTP/JSON)  │  │  (HTTP/2 PB)   │
    └────────┬──────┘  └─────┬──────────┘
             │                │
             │                │
    ┌────────▼────────────────▼───────────┐
    │      Spring Boot Application        │
    │                                      │
    │  ┌────────────────────────────────┐ │
    │  │   GreeterRestController        │ │
    │  │   (Port 8080)                  │ │
    │  └────────────┬───────────────────┘ │
    │               │                      │
    │               │ wraps                │
    │               │                      │
    │  ┌────────────▼───────────────────┐ │
    │  │   MyGreeterService (gRPC)      │ │
    │  │   (Port 9090)                  │ │
    │  └────────────────────────────────┘ │
    │                                      │
    └──────────────────────────────────────┘
```

### Key Design Decisions

1. **No Code Duplication**: REST endpoints wrap gRPC service implementation
2. **Single Source of Truth**: Business logic lives in gRPC service only
3. **Protocol Translation**: REST controller translates HTTP/JSON to gRPC calls
4. **Separate Ports**: gRPC (9090) and REST (8080) run on different ports for clarity

---

## Implementation Details

### Dependencies Added

**Maven Dependency (`pom.xml`):**

```xml
<dependency>
    <groupId>org.springdoc</groupId>
    <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
    <version>2.7.0</version>
</dependency>
```

This dependency provides:
- Swagger UI (interactive documentation)
- OpenAPI 3.0 specification generation
- Automatic endpoint discovery
- Schema generation from Java classes

---

## Components

### 1. GreeterRestController

**Location:** `src/main/java/com/example/demo/controller/GreeterRestController.java`

**Purpose:** Exposes REST endpoints that wrap the gRPC service.

**Key Features:**
- `@Tag` annotation for API grouping
- `@Operation` for endpoint documentation
- `@ApiResponse` for response documentation
- `@Parameter` for parameter descriptions
- DTOs with `@Schema` annotations

**Endpoints:**

#### GET /api/greet/hello/{name}

```java
@GetMapping("/hello/{name}")
@Operation(
    summary = "Say Hello",
    description = "Returns a greeting message for the provided name"
)
public ResponseEntity<GreetingResponse> sayHello(@PathVariable String name)
```

**Example:**
```bash
curl http://localhost:8080/api/greet/hello/Alice
```

**Response:**
```json
{
  "message": "Hello Alice from Java 25!"
}
```

#### POST /api/greet/hello

```java
@PostMapping("/hello")
@Operation(
    summary = "Say Hello (POST)",
    description = "Returns a greeting message via POST request"
)
public ResponseEntity<GreetingResponse> sayHelloPost(@RequestBody GreetingRequest request)
```

**Example:**
```bash
curl -X POST http://localhost:8080/api/greet/hello \
  -H "Content-Type: application/json" \
  -d '{"name": "Bob"}'
```

**Response:**
```json
{
  "message": "Hello Bob from Java 25!"
}
```

### 2. Data Transfer Objects (DTOs)

**GreetingRequest:**
```java
@Schema(description = "Request object for greeting")
public static class GreetingRequest {
    @Schema(description = "Name of the person to greet", 
            example = "World", 
            required = true)
    private String name;
    // getters and setters
}
```

**GreetingResponse:**
```java
@Schema(description = "Response object containing the greeting message")
public static class GreetingResponse {
    @Schema(description = "The greeting message", 
            example = "Hello World from Java 25!")
    private String message;
    // getters and setters
}
```

### 3. OpenApiConfig

**Location:** `src/main/java/com/example/demo/config/OpenApiConfig.java`

**Purpose:** Configures OpenAPI documentation metadata.

**Configuration:**
```java
@Bean
public OpenAPI customOpenAPI() {
    return new OpenAPI()
        .info(new Info()
            .title("Greeter gRPC Service API")
            .version("1.0.0")
            .description("REST API wrapper for the gRPC Greeter service")
            .contact(new Contact()
                .name("API Support")
                .email("support@example.com"))
            .license(new License()
                .name("Apache 2.0")
                .url("https://www.apache.org/licenses/LICENSE-2.0.html")))
        .servers(List.of(
            new Server()
                .url("http://localhost:8080")
                .description("Local Development Server")
        ));
}
```

---

## Configuration

### Application Configuration

**File:** `src/main/resources/application.yaml`

```yaml
spring:
  application:
    name: demo
  grpc:
    server:
      port: 9090                        # gRPC dedicated port
      reflection-enabled: true          # Enable gRPC reflection

server:
  port: 8080                            # REST API port
  http2:
    enabled: true                       # Required for gRPC

# Swagger/OpenAPI Configuration
springdoc:
  api-docs:
    path: /api-docs                     # OpenAPI JSON spec path
    enabled: true
  swagger-ui:
    path: /swagger-ui.html              # Swagger UI path
    enabled: true
    tags-sorter: alpha                  # Sort tags alphabetically
    operations-sorter: alpha            # Sort operations alphabetically
  show-actuator: false                  # Hide actuator endpoints
```

### Port Configuration

| Service | Port | Purpose |
|---------|------|---------|
| REST API | 8080 | HTTP/JSON endpoints with Swagger |
| gRPC Server | 9090 | Native gRPC binary protocol |

---

## Usage Guide

### Starting the Application

1. **Build the project:**
   ```bash
   ./mvnw clean install
   ```

2. **Run the application:**
   ```bash
   ./mvnw spring-boot:run
   ```

3. **Verify startup:**
   ```
   Started DemoApplication in X.XXX seconds
   REST API available at: http://localhost:8080
   gRPC Server running on port: 9090
   ```

### Accessing Swagger UI

**URL:** [http://localhost:8080/swagger-ui.html](http://localhost:8080/swagger-ui.html)

**Features:**
- Interactive API testing
- Request/response examples
- Schema documentation
- Try-it-out functionality

### Accessing OpenAPI Specification

**URL:** [http://localhost:8080/api-docs](http://localhost:8080/api-docs)

**Use Cases:**
- Import into Postman
- Generate client SDKs
- API contract validation
- Documentation generation

---

## API Documentation

### Greeter API

**Tag:** `Greeter API`  
**Description:** REST endpoints for the Greeter gRPC service

#### Endpoints Summary

| Endpoint | Method | Description | Request | Response |
|----------|--------|-------------|---------|----------|
| `/api/greet/hello/{name}` | GET | Greet by name (path param) | Path: `name` | `GreetingResponse` |
| `/api/greet/hello` | POST | Greet by name (body) | Body: `GreetingRequest` | `GreetingResponse` |

#### Request/Response Examples

**Successful Response (200 OK):**
```json
{
  "message": "Hello World from Java 25!"
}
```

**Error Response (400 Bad Request):**
```json
{
  "timestamp": "2026-01-11T10:30:00.000+00:00",
  "status": 400,
  "error": "Bad Request",
  "path": "/api/greet/hello/"
}
```

---

## Best Practices

### 1. Documentation Annotations

Always use comprehensive OpenAPI annotations:

```java
@Operation(
    summary = "Brief summary",
    description = "Detailed description with examples"
)
@ApiResponses(value = {
    @ApiResponse(
        responseCode = "200",
        description = "Success description",
        content = @Content(schema = @Schema(implementation = MyClass.class))
    ),
    @ApiResponse(
        responseCode = "400",
        description = "Error description"
    )
})
```

### 2. Schema Documentation

Document all DTOs with `@Schema`:

```java
@Schema(description = "Clear description", example = "example value")
private String fieldName;
```

### 3. Error Handling

Implement proper error handling in REST controllers:

```java
try {
    // gRPC call
} catch (Exception e) {
    return ResponseEntity
        .status(HttpStatus.INTERNAL_SERVER_ERROR)
        .body(new ErrorResponse(e.getMessage()));
}
```

### 4. Async gRPC Calls

Use `CompletableFuture` for non-blocking gRPC calls:

```java
CompletableFuture<String> future = new CompletableFuture<>();
grpcService.call(request, new StreamObserver<Response>() {
    @Override
    public void onNext(Response response) {
        future.complete(response.getMessage());
    }
    
    @Override
    public void onError(Throwable t) {
        future.completeExceptionally(t);
    }
});
```

### 5. API Versioning

Consider versioning your API:

```java
@RequestMapping("/api/v1/greet")
public class GreeterRestController {
    // endpoints
}
```

---

## Troubleshooting

### Issue: Swagger UI Not Loading

**Symptoms:**
- 404 error when accessing `/swagger-ui.html`
- Blank page

**Solutions:**
1. Verify dependency is in `pom.xml`:
   ```xml
   <dependency>
       <groupId>org.springdoc</groupId>
       <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
       <version>2.7.0</version>
   </dependency>
   ```

2. Check configuration in `application.yaml`:
   ```yaml
   springdoc:
     swagger-ui:
       enabled: true
   ```

3. Try alternate URL: `/swagger-ui/index.html`

### Issue: gRPC Service Not Found

**Symptoms:**
- REST endpoint returns 500 error
- "Service not available" message

**Solutions:**
1. Verify gRPC service is annotated with `@Service`:
   ```java
   @Service
   public class MyGreeterService extends GreeterGrpc.GreeterImplBase {
   ```

2. Check gRPC server is running on port 9090

3. Verify proto files are compiled:
   ```bash
   ./mvnw clean compile
   ```

### Issue: Port Already in Use

**Symptoms:**
- Application fails to start
- "Port 8080 is already in use"

**Solutions:**
1. Check what's using the port:
   ```bash
   lsof -i :8080
   ```

2. Kill the process or change port in `application.yaml`:
   ```yaml
   server:
     port: 8081
   ```

### Issue: OpenAPI Schema Not Generated

**Symptoms:**
- DTOs not appearing in Swagger UI
- Missing schema documentation

**Solutions:**
1. Add `@Schema` annotations to DTOs
2. Ensure DTOs are public and static (if inner classes)
3. Rebuild the project:
   ```bash
   ./mvnw clean install
   ```

---

## Additional Resources

### Official Documentation

- [springdoc-openapi Documentation](https://springdoc.org/)
- [OpenAPI 3.0 Specification](https://swagger.io/specification/)
- [Spring gRPC Documentation](https://docs.spring.io/spring-grpc/reference/)

### Related Files

- Main Application: [DemoApplication.java](src/main/java/com/example/demo/DemoApplication.java)
- gRPC Service: [MyGreeterService.java](src/main/java/com/example/demo/MyGreeterService.java)
- REST Controller: [GreeterRestController.java](src/main/java/com/example/demo/controller/GreeterRestController.java)
- OpenAPI Config: [OpenApiConfig.java](src/main/java/com/example/demo/config/OpenApiConfig.java)
- Proto Definition: [hello.proto](src/main/proto/hello.proto)
- Configuration: [application.yaml](src/main/resources/application.yaml)

---

## Future Enhancements

### Planned Features

1. **Authentication & Authorization**
   - Add Spring Security
   - JWT token support
   - OAuth2 integration

2. **Advanced Documentation**
   - Request/response examples
   - Code samples in multiple languages
   - Interactive tutorials

3. **Monitoring & Metrics**
   - Prometheus metrics for REST endpoints
   - Request tracing
   - Performance monitoring

4. **API Gateway Integration**
   - Rate limiting
   - Request transformation
   - Circuit breaker patterns

5. **Automated Testing**
   - REST API integration tests
   - OpenAPI contract validation
   - Performance benchmarking

---

## Changelog

### Version 1.0.0 (2026-01-11)

**Added:**
- Swagger/OpenAPI integration with springdoc-openapi v2.7.0
- REST API wrapper controller (`GreeterRestController`)
- OpenAPI configuration (`OpenApiConfig`)
- DTOs for REST API (GreetingRequest, GreetingResponse)
- Comprehensive API documentation
- Interactive Swagger UI at `/swagger-ui.html`
- OpenAPI JSON specification at `/api-docs`

**Modified:**
- Updated `application.yaml` with springdoc configuration
- Enhanced `pom.xml` with OpenAPI dependency
- Updated README.md with Swagger usage instructions

**Technical Details:**
- REST API Port: 8080
- gRPC Server Port: 9090
- Java Version: 25
- Spring Boot Version: 4.0.1
- OpenAPI Version: 3.0

---

