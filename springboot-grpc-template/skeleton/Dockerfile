# --- STAGE 1: Build Stage ---
# Use a full JDK 25 image to compile the code and generate gRPC stubs
FROM eclipse-temurin:25-jdk AS builder

WORKDIR /build

# 1. Copy only the Maven/Gradle wrapper and configuration first
# This allows Docker to cache your dependencies unless pom.xml/build.gradle changes
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .

# 2. Download dependencies (Offline mode for speed)
RUN ./mvnw dependency:go-offline

# 3. Copy the source code and proto files
COPY src ./src

# 4. Build the application
# This will trigger the protobuf-maven-plugin to generate Java stubs automatically
RUN ./mvnw clean package -DskipTests

# --- STAGE 2: Runtime Stage ---
# Use a slim JRE 25 image for the final container
FROM eclipse-temurin:25-jre-alpine

# Security: Run as a non-root user
RUN addgroup -S spring && adduser -S spring -G spring
USER spring:spring

WORKDIR /app

# Copy only the compiled JAR from the builder stage
COPY --from=builder /build/target/*.jar app.jar

# Expose the gRPC port (matching your application.yml)
EXPOSE 9090

# Performance: Optimized for Virtual Threads (Java 25)
# Use the 'exec' form to ensure signals (like SIGTERM) are passed to the JVM
ENTRYPOINT ["java", "-Dspring.threads.virtual.enabled=true", "-jar", "app.jar"]