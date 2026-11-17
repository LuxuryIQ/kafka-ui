# LuxuryIQ vendor build (infra's vendor-image): the jar with the frontend bundled,
# then api/Dockerfile's runtime stage. The context is the checkout itself: the
# frontend and the git-properties plugin read the commit from .git.
FROM eclipse-temurin:25.0.5_8-jdk@sha256:884a2f8692cc1e2c7e21f95914adf0ae0eafee9a7eb663a12169cc44468256ec AS build
RUN apt-get update && apt-get install -y --no-install-recommends git \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /src
COPY . .
RUN git config --global --add safe.directory /src \
 && ./gradlew :api:bootJar -Pinclude-frontend=true -Pversion="$(git describe --tags --always)" --no-daemon \
 && cp api/build/libs/api-*.jar /api.jar

# Temurin, not api/Dockerfile's zulu: zulu declares ARG ZULU_KEY_SHA256, which Trivy's DS-0031 fails.
FROM eclipse-temurin:25.0.5_8-jre-alpine@sha256:e1898fd6a11fc965a994d8ace186fd3585aeb636cf8f05f47a723fcfee0b0918

RUN apk add --no-cache \
    # snappy codec
    gcompat \
    # configuring timezones
    tzdata
RUN addgroup -S kafkaui && adduser -S kafkaui -G kafkaui

# creating folder for dynamic config usage (certificates uploads, etc)
RUN mkdir /etc/kafkaui/
RUN chown kafkaui /etc/kafkaui

USER kafkaui

COPY --from=build /api.jar /api.jar

ENV JAVA_OPTS=

EXPOSE 8080

# see JmxSslSocketFactory docs to understand why add-opens is needed
CMD java --add-opens java.rmi/javax.rmi.ssl=ALL-UNNAMED  $JAVA_OPTS -jar api.jar
