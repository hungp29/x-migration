# x-migration

Kubernetes Job for running [Flyway](https://flywaydb.org/) database migrations against a PostgreSQL instance, packaged as a Helm chart.

## Repository layout

```
.
├── migrations/
│   ├── Dockerfile          # Build the migration image (Flyway + SQL scripts)
│   └── sql/
│       ├── V1__create_users_table.sql
│       ├── V2__create_orders_table.sql
│       └── V3__add_updated_at_trigger.sql
└── helm/
    └── db-migration/
        ├── Chart.yaml
        ├── values.yaml               # Defaults and documentation
        ├── values-staging.yaml       # Staging overrides
        ├── values-production.yaml    # Production overrides
        └── templates/
            ├── _helpers.tpl
            ├── job.yaml
            ├── configmap.yaml
            └── serviceaccount.yaml
```

## How it works

1. **Build** a Docker image containing Flyway and the versioned SQL scripts.
2. **Deploy** the Helm chart, which creates a Kubernetes `Job` that runs `flyway migrate`.
3. The Job is wired as a **Helm pre-install / pre-upgrade hook**, so migrations always complete before application pods are updated.
4. Credentials are read from a pre-existing Kubernetes `Secret`; they are never stored in values files or ConfigMaps.

## Quickstart

### 1. Build and push the migration image

```bash
docker build -t my-registry/db-migration:latest ./migrations
docker push my-registry/db-migration:latest
```

### 2. Create the credentials Secret

```bash
kubectl create secret generic db-migration-credentials \
  --from-literal=username=myuser \
  --from-literal=password=mysecretpassword \
  --namespace default
```

The Secret must contain the keys `username` and `password`.

### 3. Install / upgrade the Helm chart

```bash
# Staging
helm upgrade --install db-migration ./helm/db-migration \
  -f helm/db-migration/values.yaml \
  -f helm/db-migration/values-staging.yaml \
  --namespace default

# Production
helm upgrade --install db-migration ./helm/db-migration \
  -f helm/db-migration/values.yaml \
  -f helm/db-migration/values-production.yaml \
  --namespace default
```

Helm will run the migration Job before any other resources are updated.

### 4. Check migration status

```bash
# Watch Job progress
kubectl get job -l app.kubernetes.io/name=db-migration -w

# Read logs
kubectl logs -l app.kubernetes.io/name=db-migration --tail=200
```

## Adding a new migration

1. Create a file under `migrations/sql/` following the Flyway naming convention:

   ```
   V<version>__<description>.sql
   ```

   Versions must be strictly increasing integers. Example: `V4__add_audit_log.sql`.

2. Rebuild and push the image with a new tag:

   ```bash
   docker build -t my-registry/db-migration:sha-<git-sha> ./migrations
   docker push my-registry/db-migration:sha-<git-sha>
   ```

3. Update `image.tag` in the appropriate values file and run `helm upgrade`.

## Key configuration reference

| Value | Default | Description |
|---|---|---|
| `image.repository` | `my-registry/db-migration` | Docker image to run |
| `image.tag` | `latest` | Image tag (pin to a SHA in production) |
| `postgresql.host` | `""` | PostgreSQL hostname |
| `postgresql.port` | `5432` | PostgreSQL port |
| `postgresql.database` | `""` | Target database name |
| `postgresql.existingSecret` | `""` | Secret name with `username`/`password` keys |
| `flyway.validateOnMigrate` | `true` | Validate checksums on every run |
| `flyway.outOfOrder` | `false` | Allow out-of-order migrations |
| `job.backoffLimit` | `3` | Retry attempts before Job failure |
| `job.ttlSecondsAfterFinished` | `300` | Auto-delete completed Jobs after N seconds |
| `job.activeDeadlineSeconds` | `600` | Hard timeout for the entire Job |
| `job.hookPhase` | `pre-install,pre-upgrade` | Helm hook lifecycle phases |

See `helm/db-migration/values.yaml` for the full list with documentation.

## Security notes

- The migration pod runs as a **non-root user** (UID 1000) with a read-only root filesystem.
- All Linux capabilities are dropped.
- Database credentials are sourced from a Kubernetes `Secret` via `secretKeyRef`; they never appear in `values.yaml`, ConfigMaps, or Helm release metadata.
- The `ServiceAccount` has no additional RBAC permissions beyond the default.
