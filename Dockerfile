# syntax=docker/dockerfile:1

# ---------- Estagio 1: build ----------
# Imagem com Maven + JDK 21 apenas para compilar e empacotar o .jar
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app

# Copia so o pom.xml primeiro: as dependencias ficam em cache enquanto o pom nao mudar
COPY pom.xml .
RUN mvn -B -q dependency:go-offline

COPY src ./src
# Os testes rodam em uma etapa propria do pipeline, por isso sao pulados aqui
RUN mvn -B -q package -DskipTests

# ---------- Estagio 2: runtime ----------
# Imagem final enxuta: apenas o JRE (sem Maven, sem codigo-fonte)
FROM eclipse-temurin:21-jre-alpine

# Versao (commit) gravada na imagem pelo pipeline e exibida em /api/info
ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION} \
    JAVA_OPTS="-XX:MaxRAMPercentage=75"

WORKDIR /app

# Usuario sem privilegios de root
RUN addgroup -S esg && adduser -S esg -G esg
COPY --from=build /app/target/cidades-esg.jar app.jar
USER esg

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD wget -qO- "http://localhost:${PORT:-8080}/actuator/health" || exit 1

ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar app.jar"]
