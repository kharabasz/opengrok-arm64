# Portions Copyright (c) 2018, 2026 Oracle and/or its affiliates. All rights reserved.
# Derived from https://github.com/oracle/opengrok/blob/1.14.20/Dockerfile (CDDL-1.0).
#
# Native (arm64 on Apple Silicon) OpenGrok image. The official opengrok/docker
# image is amd64-only, but its base image is multi-arch, so this follows the
# upstream Dockerfile minus the Maven build: it unpacks the released tarball
# instead. It also drops the SCMs other than git (add any you need to the
# apt-get line) and installs universal-ctags from apt rather than compiling it.
FROM tomcat:10.1.60-jdk21

ARG OPENGROK_VERSION=1.14.20

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get install --no-install-recommends -y git universal-ctags python3 python3-venv && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    ln -s /usr/bin/ctags-universal /usr/local/bin/ctags  # start.py hardcodes this path

ADD https://github.com/oracle/opengrok/releases/download/${OPENGROK_VERSION}/opengrok-${OPENGROK_VERSION}.tar.gz /opengrok.tar.gz
RUN mkdir -p /opengrok/etc /opengrok/data /opengrok/src && \
    tar -zxf /opengrok.tar.gz -C /opengrok --strip-components 1 && \
    rm -f /opengrok.tar.gz && \
    echo -n "$OPENGROK_VERSION" > /opengrok/VERSION && \
    python3 -m venv /venv && \
    /venv/bin/pip install --no-cache-dir /opengrok/tools/opengrok-tools.tar.gz Flask Flask-HTTPAuth waitress

RUN groupadd -g 1111 -r appgroup && useradd -r -g appgroup -u 1111 appuser

ENV SRC_ROOT=/opengrok/src \
    DATA_ROOT=/opengrok/data \
    URL_ROOT=/ \
    CATALINA_HOME=/usr/local/tomcat \
    CATALINA_BASE=/usr/local/tomcat \
    CATALINA_TMPDIR=/usr/local/tomcat/temp \
    PATH=/venv/bin:/usr/local/tomcat/bin:$PATH \
    CLASSPATH=/usr/local/tomcat/bin/bootstrap.jar:/usr/local/tomcat/bin/tomcat-juli.jar \
    JAVA_OPTS="--add-exports=java.base/jdk.internal.ref=ALL-UNNAMED --add-exports=java.base/sun.nio.ch=ALL-UNNAMED \
--add-exports=jdk.unsupported/sun.misc=ALL-UNNAMED --add-exports=jdk.compiler/com.sun.tools.javac.file=ALL-UNNAMED \
--add-opens=jdk.compiler/com.sun.tools.javac=ALL-UNNAMED --add-opens=java.base/java.lang=ALL-UNNAMED \
--add-opens=java.base/java.lang.reflect=ALL-UNNAMED --add-opens=java.base/java.io=ALL-UNNAMED \
--add-opens=java.base/java.util=ALL-UNNAMED"

# Upstream's start scripts, taken from the same release tag.
ADD https://github.com/oracle/opengrok.git#${OPENGROK_VERSION}:docker /scripts
RUN cp /scripts/logging.properties /usr/local/tomcat/conf/logging.properties && \
    sed -i -e 's/Valve/Disabled/' /usr/local/tomcat/conf/server.xml && \
    chmod -R +x /scripts

# The stock entrypoint chowns /opengrok/src, which fails on a read-only mount.
# Ours only fixes the writable dirs, then drops to appuser.
RUN printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' \
    'chown -R appuser:appgroup /usr/local/tomcat/webapps /opengrok/etc /opengrok/data' \
    'exec runuser -u appuser -- "$@"' > /scripts/entrypoint-ro.sh && \
    chmod +x /scripts/entrypoint-ro.sh

WORKDIR $CATALINA_HOME
EXPOSE 8080
ENTRYPOINT ["/scripts/entrypoint-ro.sh"]
CMD ["/scripts/start.py"]
