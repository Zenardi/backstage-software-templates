package ${{values.java_package_name}};

import io.swagger.v3.oas.annotations.OpenAPIDefinition;
import io.swagger.v3.oas.annotations.info.Info;
import io.swagger.v3.oas.annotations.tags.Tag;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@OpenAPIDefinition(
    info = @Info(
        title = "Spring Boot Hello World API",
        version = "1.0.0",
        description = "A simple Spring Boot REST API with Hello World endpoints"
    )
)
@Tag(name = "Hello API", description = "Endpoints for hello world operations")
public class HelloController {

    @GetMapping("/")
    @Operation(
        summary = "Welcome endpoint",
        description = "Returns a welcome message to the API"
    )
    @ApiResponse(responseCode = "200", description = "Welcome message returned successfully")
    public String index() {
        return "Hello, World! Welcome to Spring Boot API";
    }

    @GetMapping("/hello")
    @Operation(
        summary = "Hello endpoint",
        description = "Returns a simple hello message"
    )
    @ApiResponse(responseCode = "200", description = "Hello message returned successfully")
    public String hello() {
        return "Hello from Spring Boot!";
    }

    @GetMapping("/api/status")
    @Operation(
        summary = "Status endpoint",
        description = "Returns the status of the API in JSON format"
    )
    @ApiResponse(responseCode = "200", description = "Status information returned successfully")
    public String status() {
        return "{\"status\": \"OK\", \"message\": \"Spring Boot API is running\"}";
    }
}
