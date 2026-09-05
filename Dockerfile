# --- Etape 1 : build ---
FROM eclipse-temurin:21-jdk AS build
WORKDIR /app

# Cache les dependances Maven separement du code source pour accelerer les
# rebuilds (cette couche ne change que si pom.xml change).
COPY .mvn/ .mvn/
COPY mvnw pom.xml ./
RUN chmod +x mvnw && ./mvnw -B -o dependency:go-offline -q || ./mvnw -B dependency:go-offline -q

COPY src/ src/
RUN ./mvnw -B -DskipTests package -q && \
    cp target/*.jar app.jar

# --- Etape 2 : image d'execution ---
FROM eclipse-temurin:21-jre
WORKDIR /app

# Pas d'UID/GID fixe : la valeur 1000 n'etait necessaire que pour le
# securityContext.runAsUser Kubernetes de l'ancien design EKS (abandonne), et
# entrait en conflit avec le GID 1000 deja pris par defaut sur l'image de base.
RUN groupadd --system spring && useradd --system --gid spring spring
COPY --from=build /app/app.jar app.jar
RUN chown spring:spring app.jar
USER spring

# Railway fournit PORT/SERVER_PORT dynamiquement (voir application.properties) ;
# 8080 reste la valeur par defaut (utilisee sur l'EC2, voir infra/terraform).
EXPOSE 8080

# `docker run --restart unless-stopped` (voir templates/deploy-backend.sh.tftpl)
# relance le conteneur s'il crashe ; /actuator/health reste dispo pour vos
# propres verifications manuelles (curl depuis l'instance).
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
