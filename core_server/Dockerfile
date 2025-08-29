ARG I2B2_CORE_SERVER_TAG=latest
FROM i2b2/i2b2-core-server:${I2B2_CORE_SERVER_TAG}

# Remove Oracle JDBC driver (not needed if you're only using PostgreSQL)
RUN rm -f /opt/jboss/wildfly/standalone/deployments/i2b2.war/WEB-INF/lib/ojdbc8.jar
