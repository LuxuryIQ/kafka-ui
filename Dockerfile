# LuxuryIQ vendor build (infra's vendor-image): the jar with the frontend bundled,
# then api/Dockerfile's runtime stage. The context is the checkout itself: the
# frontend and the git-properties plugin read the commit from .git.
FROM eclipse-temurin:25-jdk AS build
RUN apt-get update && apt-get install -y --no-install-recommends git \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /src
COPY . .
RUN git config --global --add safe.directory /src \
 && ./gradlew :api:bootJar -Pinclude-frontend=true -Pversion="$(git describe --tags --always)" --no-daemon \
 && cp api/build/libs/api-*.jar /api.jar

FROM azul/zulu-openjdk-alpine:25.0.2-jre-headless@sha256:ff319ed64315a5deed026bb6c8d78b8c446d2de2a9f525b4cf6f819b847fc709

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
