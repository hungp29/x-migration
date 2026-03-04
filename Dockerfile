FROM flyway/flyway:10-alpine

# Copy SQL migration scripts. Flyway 10 deprecates the default "sql" folder;
# we use /flyway/migrations and set flyway.locations in the chart's ConfigMap.
COPY migrations/sql/ /flyway/migrations/

# The entrypoint is the Flyway CLI. The Job template passes the
# "migrate" command along with connection flags via env vars, so no
# CMD override is needed here.
