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

