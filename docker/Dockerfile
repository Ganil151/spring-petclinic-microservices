FROM eclipse-temurin:21 AS builder
#FROM docker.io/eclipse-temurin:21 AS builder
WORKDIR /application

# Use a default value for JAR_FILE if not provided during build
ARG JAR_FILE=application.jar
# Copy the JAR file into the builder stage
COPY ${JAR_FILE} application.jar

# Extract the JAR layers using Spring Boot's layertools
RUN java -Djarmode=layertools -jar application.jar extract

# Use the JRE-based Alpine image for the final stage
FROM eclipse-temurin:21-jre-alpine
#FROM docker.io/eclipse-temurin:21-jre-alpine
WORKDIR /application

# Copy the extracted layers from the builder stage
COPY --from=builder /application/dependencies/ ./
COPY --from=builder /application/spring-boot-loader/ ./
COPY --from=builder /application/snapshot-dependencies/ ./
COPY --from=builder /application/application/ ./

# Expose the port the application runs on (adjust if different)
EXPOSE 8080

# Use PropertiesLauncher to run the layered application
ENTRYPOINT [ "java", "org.springframework.boot.loader.launch.PropertiesLauncher" ]