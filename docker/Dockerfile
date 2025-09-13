FROM eclipse-temurin:17 AS builder
WORKDIR /application

ARG JAR_FILE
COPY ${JAR_FILE} application.jar

RUN java -Djarmode=layertools -jar application.jar extract

FROM eclipse-temurin:17-jre-alpine
WORKDIR /application

COPY --from=builder /application/dependencies/ ./
COPY --from=builder /application/spring-boot-loader/ ./
COPY --from=builder /application/snapshot-dependencies/ ./
COPY --from=builder /application/application/ ./

EXPOSE 8080

ENTRYPOINT [ "java", "-jar", "application.jar", "org.springframework.boot.loader.launch.JarLauncher" ]

# # Stage 1: Build the application
# # Dockerfile in the `docker` directory

# FROM eclipse-temurin:17 AS builder
# WORKDIR application
# # Change the build argument name to match the Jenkinsfile
# ARG JAR_FILE 
# # Copy the JAR using the new argument
# COPY ${JAR_FILE} application.jar
# RUN java -Djarmode=layertools -jar application.jar extract


# FROM eclipse-temurin:17
# WORKDIR application

# ARG EXPOSED_PORT
# EXPOSE ${EXPOSED_PORT}

# ENV SPRING_PROFILES_ACTIVE=docker

# COPY --from=builder application/dependencies/ ./
# RUN true
# COPY --from=builder application/spring-boot-loader/ ./
# RUN true
# COPY --from=builder application/snapshot-dependencies/ ./
# RUN true
# COPY --from=builder application/application/ ./

# # # docker/Dockerfile (Multi-stage)
# WORKDIR /application
# COPY ../.mvn ./.mvn
# COPY ../mvnw .
# COPY ../pom.xml .
# COPY ../spring-petclinic-config-server/pom.xml spring-petclinic-config-server/
# COPY ../spring-petclinic-config-server/src spring-petclinic-config-server/src
# RUN mvn clean package -pl spring-petclinic-config-server -am -DskipTests

# # Extract the JAR file for layering (if needed)
# RUN mkdir -p /application/target && cp spring-petclinic-config-server/target/spring-petclinic-config-server-*.jar /application/target/application.jar

# # Stage 2: Create the final, lightweight image
# FROM eclipse-temurin:17-jre-alpine
# WORKDIR /application
# COPY --from=builder /application/spring-petclinic-config-server/target/spring-petclinic-config-server-*.jar ./application.jar

# EXPOSE 8080
# ENTRYPOINT ["java", "-jar", "application.jar"]
