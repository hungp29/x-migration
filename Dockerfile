FROM flyway/flyway:10-alpine

# Copy SQL migration scripts into the Flyway migrations directory.
# Flyway scans this path automatically at startup.
COPY migrations/sql/ /flyway/sql/

# The entrypoint is the Flyway CLI. The Job template passes the
# "migrate" command along with connection flags via env vars, so no
# CMD override is needed here.
