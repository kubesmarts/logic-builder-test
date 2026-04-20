# Declare the LOGIC_BUILDER_IMAGE argument so Docker accepts it from the Makefile
ARG LOGIC_BUILDER_IMAGE="quay.io/dhanak/logic-builder:latest"
# Declare the Nexus URL argument so Docker accepts it from the Makefile
ARG NEXUS_REPO_URL="https://repository.jboss.org/nexus/content/groups/public/"

FROM ${LOGIC_BUILDER_IMAGE} AS builder

ARG QUARKUS_EXTENSIONS="org.kie:kie-addons-quarkus-persistence-jdbc,io.quarkus:quarkus-jdbc-postgresql,io.quarkus:quarkus-agroal"
ARG QUARKUS_ADD_EXTENSION_ARGS
ARG QUARKUS_CREATE_ARGS
ARG MAVEN_ARGS_APPEND="-Dmaven.wagon.http.ssl.insecure=true -Dmaven.wagon.http.ssl.allowall=true"

ENV MAVEN_MIRROR_URL=${NEXUS_REPO_URL}

COPY --chown=1001 . ./resources
RUN /home/kogito/launch/build-app.sh ./resources

# --- Runtime Stage ---
FROM registry.access.redhat.com/ubi9/openjdk-17-runtime:latest

ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en'

COPY --from=builder --chown=185 /home/kogito/serverless-workflow-project/target/quarkus-app/lib/ /deployments/lib/
COPY --from=builder --chown=185 /home/kogito/serverless-workflow-project/target/quarkus-app/*.jar /deployments/
COPY --from=builder --chown=185 /home/kogito/serverless-workflow-project/target/quarkus-app/app/ /deployments/app/
COPY --from=builder --chown=185 /home/kogito/serverless-workflow-project/target/quarkus-app/quarkus/ /deployments/quarkus/

EXPOSE 8080
USER 185

ENV AB_JOLOKIA_OFF=""
ENV JAVA_OPTS="-Dquarkus.http.host=0.0.0.0 -Djava.util.logging.manager=org.jboss.logmanager.LogManager"
ENV JAVA_APP_JAR="/deployments/quarkus-run.jar"

