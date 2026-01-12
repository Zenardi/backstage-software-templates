package com.example.demo.controller;

import com.example.demo.MyGreeterService;
import com.example.grpc.HelloReply;
import com.example.grpc.HelloRequest;
import io.grpc.stub.StreamObserver;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.concurrent.CompletableFuture;

@RestController
@RequestMapping("/api/greet")
@Tag(name = "Greeter API", description = "REST endpoints for the Greeter gRPC service")
public class GreeterRestController {

    @Autowired
    private MyGreeterService greeterService;

    @GetMapping("/hello/{name}")
    @Operation(
        summary = "Say Hello",
        description = "Returns a greeting message for the provided name. This endpoint wraps the gRPC SayHello method."
    )
    @ApiResponses(value = {
        @ApiResponse(
            responseCode = "200",
            description = "Successfully generated greeting",
            content = @Content(
                mediaType = "application/json",
                schema = @Schema(implementation = GreetingResponse.class)
            )
        ),
        @ApiResponse(
            responseCode = "400",
            description = "Invalid name provided"
        )
    })
    public ResponseEntity<GreetingResponse> sayHello(
            @Parameter(description = "Name of the person to greet", required = true, example = "World")
            @PathVariable String name) {
        
        CompletableFuture<String> future = new CompletableFuture<>();
        
        HelloRequest request = HelloRequest.newBuilder()
                .setName(name)
                .build();
        
        greeterService.sayHello(request, new StreamObserver<HelloReply>() {
            @Override
            public void onNext(HelloReply reply) {
                future.complete(reply.getMessage());
            }

            @Override
            public void onError(Throwable t) {
                future.completeExceptionally(t);
            }

            @Override
            public void onCompleted() {
                // Already completed in onNext
            }
        });
        
        try {
            String message = future.get();
            return ResponseEntity.ok(new GreetingResponse(message));
        } catch (Exception e) {
            return ResponseEntity.badRequest().build();
        }
    }

    @PostMapping("/hello")
    @Operation(
        summary = "Say Hello (POST)",
        description = "Returns a greeting message for the provided name via POST request"
    )
    @ApiResponses(value = {
        @ApiResponse(
            responseCode = "200",
            description = "Successfully generated greeting"
        )
    })
    public ResponseEntity<GreetingResponse> sayHelloPost(
            @Parameter(description = "Request body with the name", required = true)
            @RequestBody GreetingRequest greetingRequest) {
        
        CompletableFuture<String> future = new CompletableFuture<>();
        
        HelloRequest request = HelloRequest.newBuilder()
                .setName(greetingRequest.getName())
                .build();
        
        greeterService.sayHello(request, new StreamObserver<HelloReply>() {
            @Override
            public void onNext(HelloReply reply) {
                future.complete(reply.getMessage());
            }

            @Override
            public void onError(Throwable t) {
                future.completeExceptionally(t);
            }

            @Override
            public void onCompleted() {
                // Already completed in onNext
            }
        });
        
        try {
            String message = future.get();
            return ResponseEntity.ok(new GreetingResponse(message));
        } catch (Exception e) {
            return ResponseEntity.badRequest().build();
        }
    }

    // DTOs for REST API
    @Schema(description = "Request object for greeting")
    public static class GreetingRequest {
        @Schema(description = "Name of the person to greet", example = "World", required = true)
        private String name;

        public GreetingRequest() {}

        public GreetingRequest(String name) {
            this.name = name;
        }

        public String getName() {
            return name;
        }

        public void setName(String name) {
            this.name = name;
        }
    }

    @Schema(description = "Response object containing the greeting message")
    public static class GreetingResponse {
        @Schema(description = "The greeting message", example = "Hello World from Java 25!")
        private String message;

        public GreetingResponse() {}

        public GreetingResponse(String message) {
            this.message = message;
        }

        public String getMessage() {
            return message;
        }

        public void setMessage(String message) {
            this.message = message;
        }
    }
}
