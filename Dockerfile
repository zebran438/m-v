# Etap 1: budowanie aplikacji (Maven + JDK 21). Testy uruchamia się osobno: mvn test.
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /build
COPY pom.xml .
COPY src ./src
RUN --mount=type=cache,target=/root/.m2 mvn -B -ntp -Dmaven.test.skip=true package

# Etap 2: lekki obraz uruchomieniowy (tylko JRE), aplikacja działa bez uprawnień roota
FROM eclipse-temurin:21-jre
RUN useradd --system --create-home --uid 1001 app \
    && mkdir -p /data/invoices \
    && chown -R app:app /data
WORKDIR /app
COPY --from=build /build/target/site.jar app.jar
USER app
ENV STORAGE_DIR=/data/invoices
EXPOSE 8080
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "-jar", "app.jar"]
