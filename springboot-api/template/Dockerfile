# Build stage
FROM maven:latest AS builder

WORKDIR /app

# Copy pom.xml and source code
COPY pom.xml .
COPY src ./src

# Build the application
RUN mvn clean package -DskipTests

# Runtime stage
FROM eclipse-temurin:25-jre-jammy

WORKDIR /app

# Copy the built JAR file from the builder stage
COPY --from=builder /app/target/${{values.app_name}}-1.0.0-SNAPSHOT.jar app.jar

# Expose port 8080 (default Spring Boot port)
EXPOSE 8080

# Set the entry point
ENTRYPOINT ["java", "-jar", "app.jar"]
