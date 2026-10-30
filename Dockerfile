FROM debian:trixie-20261020-slim

ARG CLAUDE_CODE_VERSION=2.1.314
ARG TEMURIN_VERSION=27.0.0.0.0+35-0
ARG NODE_VERSION=22.20.0
ARG NODE_SHA256=00bbd05e306ea68b6e13e17360d0e2f680b493ef95f2fea1c4296ff7437530bc
ARG MAVEN_VERSION=3.9.16
ARG MAVEN_SHA512=831a8591fe20c8243b1dbe7d71e3244f31d1665b0804b2e825e38cbbe5ce0cafb8338851f90780735568773e0a6cd07bbec107cda0b896b008b861075358b6f6
ARG JDTLS_VERSION=1.58.0
ARG JDTLS_BUILD=202604151538
ARG JDTLS_SHA256=2a5bbe55ec91b4325392050dc422cead3220a2459b3766be35e1fff45b4a50d9
ARG USER_NAME
ARG USER_UID
ARG USER_GID

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git less procps python3 ripgrep xz-utils \
 && install -d -m 0755 /etc/apt/keyrings \
 && curl -fsSLo /etc/apt/keyrings/adoptium.asc https://packages.adoptium.net/artifactory/api/gpg/key/public \
 && echo "deb [signed-by=/etc/apt/keyrings/adoptium.asc] https://packages.adoptium.net/artifactory/deb trixie main" \
      > /etc/apt/sources.list.d/adoptium.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends "temurin-27-jdk=${TEMURIN_VERSION}" \
 && rm -rf /var/lib/apt/lists/*

RUN curl -fsSLo /tmp/node.tar.xz "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" \
 && echo "${NODE_SHA256}  /tmp/node.tar.xz" | sha256sum -c - \
 && tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 \
 && rm /tmp/node.tar.xz

RUN curl -fsSLo /tmp/maven.tar.gz "https://repo.maven.apache.org/maven2/org/apache/maven/apache-maven/${MAVEN_VERSION}/apache-maven-${MAVEN_VERSION}-bin.tar.gz" \
 && echo "${MAVEN_SHA512}  /tmp/maven.tar.gz" | sha512sum -c - \
 && mkdir /opt/maven \
 && tar -xzf /tmp/maven.tar.gz -C /opt/maven --strip-components=1 \
 && rm /tmp/maven.tar.gz

RUN curl -fsSLo /tmp/jdtls.tar.gz "https://download.eclipse.org/jdtls/milestones/${JDTLS_VERSION}/jdt-language-server-${JDTLS_VERSION}-${JDTLS_BUILD}.tar.gz" \
 && echo "${JDTLS_SHA256}  /tmp/jdtls.tar.gz" | sha256sum -c - \
 && mkdir /opt/jdtls \
 && tar -xzf /tmp/jdtls.tar.gz -C /opt/jdtls \
 && rm /tmp/jdtls.tar.gz

ENV PATH=/opt/jdtls/bin:/opt/maven/bin:$PATH \
    DISABLE_AUTOUPDATER=1

RUN npm install -g "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
 && npm cache clean --force

RUN groupadd -g "${USER_GID}" "${USER_NAME}" \
 && useradd -m -u "${USER_UID}" -g "${USER_GID}" -s /bin/bash "${USER_NAME}"

USER ${USER_NAME}

# Named volumes take ownership from the image, so these must exist before the first run.
RUN mkdir -p "/home/${USER_NAME}/.m2" "/home/${USER_NAME}/.cache/jdtls"

WORKDIR /home/${USER_NAME}

# The container is the isolation boundary; bubblewrap can't create namespaces under Docker's default seccomp profile.
ENTRYPOINT ["claude", "--settings", "{\"sandbox\":{\"enabled\":false}}"]
