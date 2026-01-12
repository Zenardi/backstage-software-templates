package com.example.demo;

import com.example.grpc.GreeterGrpc;
import com.example.grpc.HelloReply;
import com.example.grpc.HelloRequest;
import io.grpc.stub.StreamObserver;
import org.springframework.stereotype.Service;

@Service 
public class MyGreeterService extends GreeterGrpc.GreeterImplBase {

    @Override
    public void sayHello(HelloRequest request, StreamObserver<HelloReply> responseObserver) {
        String message = "Hello " + request.getName() + " from Java 25!";
        
        HelloReply reply = HelloReply.newBuilder()
                .setMessage(message)
                .build();

        responseObserver.onNext(reply);
        responseObserver.onCompleted();
    }
}