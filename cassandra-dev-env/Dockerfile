FROM openjdk:11-jre-slim

# Instalar dependencias de runtime
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    procps \
    hostname \
    netcat \
    iputils-ping \
    openssl \
    && rm -rf /var/lib/apt/lists/*

# Crear usuario cassandra primero
RUN groupadd -r cassandra && useradd -r -g cassandra cassandra

# Copiar los binarios pre-compilados de Cassandra
COPY --chown=cassandra:cassandra cassandra/ /opt/cassandra/

# Copiar los binarios pre-compilados del Sidecar (when sidecar is enabled)
COPY --chown=cassandra:cassandra cassandra-sidecar/build/install/apache-cassandra-sidecar/ /opt/sidecar/

# Copiar configuración de debug logging
COPY --chown=cassandra:cassandra logback-debug.xml /opt/cassandra/conf/logback-debug.xml

# Copiar script de entrypoint
COPY --chown=cassandra:cassandra cassandra-entrypoint.sh /usr/local/bin/cassandra-entrypoint.sh
RUN chmod +x /usr/local/bin/cassandra-entrypoint.sh

# Copiar script de generación de certificados SSL
COPY --chown=cassandra:cassandra generate-ssl-certs.sh /generate-ssl-certs.sh
RUN chmod +x /generate-ssl-certs.sh

# Crear directorios necesarios con permisos correctos
RUN mkdir -p /opt/cassandra/logs \
    /var/lib/cassandra/data \
    /var/lib/cassandra/commitlog \
    /var/lib/cassandra/saved_caches \
    /var/lib/cassandra/hints \
    /var/log/cassandra \
    /opt/sidecar/conf \
    /opt/sidecar/logs \
    /opt/ssl-certs \
    /tmp/sidecar-staging \
    && chown -R cassandra:cassandra /opt/cassandra \
    && chown -R cassandra:cassandra /opt/sidecar \
    && chown -R cassandra:cassandra /var/lib/cassandra /var/log/cassandra \
    && chown -R cassandra:cassandra /opt/ssl-certs \
    && chown -R cassandra:cassandra /tmp/sidecar-staging

# Configurar variables de entorno
ENV CASSANDRA_HOME=/opt/cassandra
ENV SIDECAR_HOME=/opt/sidecar
ENV PATH=$CASSANDRA_HOME/bin:$SIDECAR_HOME/bin:$PATH
ENV CASSANDRA_CONFIG=$CASSANDRA_HOME/conf

# Create JMX password file for sidecar authentication
RUN mkdir -p /etc/cassandra && \
    echo "cassandra cassandra" > /etc/cassandra/jmxremote.password && \
    chmod 600 /etc/cassandra/jmxremote.password && \
    chown cassandra:cassandra /etc/cassandra/jmxremote.password

# Exponer puertos (Cassandra + Sidecar)
EXPOSE 7000 7001 7199 9042 9043 9160

# Cambiar al usuario cassandra
USER cassandra

# Comando por defecto usando el entrypoint
CMD ["/usr/local/bin/cassandra-entrypoint.sh"]