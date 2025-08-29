#!/usr/bin/env bash
# init_i2b2data.sh
# Create a production CRC schema by cloning structure from i2b2demodata,
# create/update a dedicated DB user, set ownership & grants,
# and optionally switch the running i2b2 core (WildFly) to the new schema.
#
# Usage:
#   ./init_i2b2data.sh <NEW_SCHEMA> <CRC_DB_USER> <CRC_DB_PASS> [--drop-first] [--switch-core]
#
# Examples:
#   ./init_i2b2data.sh i2b2patientdata i2b2crc_prod 'StrongPass!'
#   ./init_i2b2data.sh i2b2patientdata i2b2crc_prod 'StrongPass!' --drop-first --switch-core
#
# Notes:
# - No changes to docker-compose.yml or .env.
# - If --switch-core is used, WildFly datasources are updated at runtime (reverts if the container is recreated later).

set -euo pipefail

# ---- args -------------------------------------------------------------------
if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <NEW_SCHEMA> <CRC_DB_USER> <CRC_DB_PASS> [--drop-first] [--switch-core]"
  exit 1
fi

NEW_SCHEMA="$1"
CRC_USER="$2"
CRC_PASS="$3"
DROP_FIRST="no"
SWITCH_CORE="no"

shift 3
while [[ $# -gt 0 ]]; do
  case "$1" in
    --drop-first)  DROP_FIRST="yes" ;;
    --switch-core) SWITCH_CORE="yes" ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

# ---- config you likely don't need to change ---------------------------------
DB_CONT="i2b2-data-pgsql"
CORE_CONT="i2b2-core-server"
DB_NAME="i2b2"
PG_SUPERUSER="postgres"
SRC_SCHEMA="i2b2demodata"
CRC_DS_NAME="QueryToolDemoDS"  # typical name in i2b2 images

# ---- helpers ----------------------------------------------------------------
say() { printf "\033[1;34m[*]\033[0m %s\n" "$*"; }
ok()  { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn(){ printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
die() { printf "\033[1;31m[x]\033[0m %s\n" "$*"; exit 1; }

# escape single quotes for SQL literals
SQLPASS=${CRC_PASS//\'/\'\'}

# ---- preflight --------------------------------------------------------------
say "Checking containers..."
docker ps --format '{{.Names}}' | grep -qx "$DB_CONT"   || die "DB container '$DB_CONT' not running."
if [[ "$SWITCH_CORE" == "yes" ]]; then
  docker ps --format '{{.Names}}' | grep -qx "$CORE_CONT" || die "Core container '$CORE_CONT' not running (needed for --switch-core)."
fi

say "Waiting for Postgres to be ready..."
docker exec -i "$DB_CONT" bash -lc "pg_isready -U $PG_SUPERUSER -d $DB_NAME -h localhost"

say "Verifying source schema '$SRC_SCHEMA' exists..."
SCHEMA_EXISTS=$(docker exec -i "$DB_CONT" psql -tA -U "$PG_SUPERUSER" -d "$DB_NAME" \
  -c "SELECT 1 FROM information_schema.schemata WHERE schema_name='$SRC_SCHEMA';")
[[ "$SCHEMA_EXISTS" == "1" ]] || die "Source schema '$SRC_SCHEMA' not found."

# ---- optional drop -----------------------------------------------------------
if [[ "$DROP_FIRST" == "yes" ]]; then
  warn "Dropping schema '$NEW_SCHEMA' (CASCADE) if it exists ..."
  docker exec -i "$DB_CONT" psql -U "$PG_SUPERUSER" -d "$DB_NAME" \
    -c "DROP SCHEMA IF EXISTS $NEW_SCHEMA CASCADE;"
fi

# ---- create schema (idempotent) ---------------------------------------------
say "Creating schema '$NEW_SCHEMA' (idempotent, owner=$PG_SUPERUSER) ..."
docker exec -i "$DB_CONT" psql -U "$PG_SUPERUSER" -d "$DB_NAME" <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = '$NEW_SCHEMA') THEN
    EXECUTE 'CREATE SCHEMA $NEW_SCHEMA AUTHORIZATION $PG_SUPERUSER';
  END IF;
END
\$\$;
SQL
ok "Schema ensured."

# ---- create/alter CRC user --------------------------------------------------
say "Creating/altering login role '$CRC_USER' ..."
docker exec -i "$DB_CONT" psql -U "$PG_SUPERUSER" -d "$DB_NAME" <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '$CRC_USER') THEN
    EXECUTE 'CREATE ROLE $CRC_USER LOGIN PASSWORD ''$SQLPASS''';
  ELSE
    EXECUTE 'ALTER ROLE $CRC_USER WITH LOGIN PASSWORD ''$SQLPASS''';
  END IF;
END
\$\$;
SQL
ok "Role ensured."

# ---- clone structure from demo schema ---------------------------------------
say "Cloning structure from '$SRC_SCHEMA' to '$NEW_SCHEMA' ..."
# Steps:
#  1) Dump schema-only DDL for SRC_SCHEMA.
#  2) Replace schema name to NEW_SCHEMA.
#  3) Strip CREATE/ALTER/COMMENT ON SCHEMA, GRANT/REVOKE, SET ROLE.
#  4) Normalize search_path.
#  5) Rewrite OWNER TO <CRC_USER> so new objects belong to the app user.
docker exec -i "$DB_CONT" bash -lc "
  set -e
  TMP_SQL=\$(mktemp /tmp/crc_schema.XXXX.sql)
  pg_dump -U $PG_SUPERUSER -d $DB_NAME -n $SRC_SCHEMA -s > \$TMP_SQL

  sed -i -E '
    s/\\b$SRC_SCHEMA\\b/$NEW_SCHEMA/g;
    /^CREATE SCHEMA /d;
    /^ALTER SCHEMA /d;
    /^COMMENT ON SCHEMA /d;
    /^SET ROLE /d;
    s/^SET search_path = .+;/SET search_path = $NEW_SCHEMA, pg_catalog;/
    /^GRANT /d;
    /^REVOKE /d;
    s/OWNER TO [^;]+;/OWNER TO $CRC_USER;/
  ' \$TMP_SQL

  psql -v ON_ERROR_STOP=1 -U $PG_SUPERUSER -d $DB_NAME -f \$TMP_SQL
  rm -f \$TMP_SQL
"
ok "Structure created in '$NEW_SCHEMA' with owner=$CRC_USER."

# ---- grants -----------------------------------------------------------------
say "Granting privileges to '$CRC_USER' on '$NEW_SCHEMA' ..."
docker exec -i "$DB_CONT" psql -U "$PG_SUPERUSER" -d "$DB_NAME" <<SQL
GRANT USAGE ON SCHEMA $NEW_SCHEMA TO $CRC_USER;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES    IN SCHEMA $NEW_SCHEMA TO $CRC_USER;
GRANT USAGE, SELECT                ON ALL SEQUENCES IN SCHEMA $NEW_SCHEMA TO $CRC_USER;

ALTER DEFAULT PRIVILEGES IN SCHEMA $NEW_SCHEMA
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO $CRC_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA $NEW_SCHEMA
  GRANT USAGE, SELECT ON SEQUENCES TO $CRC_USER;
SQL
ok "Privileges granted."

warn "No data loaded yet. ETL your production data into '$NEW_SCHEMA' (patient_dimension, visit_dimension, concept_dimension, observation_fact, etc.)."

# ---- optionally switch core (runtime) ---------------------------------------
if [[ "$SWITCH_CORE" == "yes" ]]; then
  say "Switching i2b2 core to new CRC schema/user (runtime via JBoss CLI) ..."
  DS_LIST=$(docker exec -i "$CORE_CONT" /opt/jboss/wildfly/bin/jboss-cli.sh --connect \
    --commands='/subsystem=datasources:read-children-names(child-type=data-source)' | tr -d '\r')

  if ! echo "$DS_LIST" | grep -q "$CRC_DS_NAME"; then
    warn "Datasource '$CRC_DS_NAME' not found. Available datasources:"
    echo "$DS_LIST"
    warn "Setting only system property DS_CRC_SCHEMA; adjust DS user/password manually if needed."
    docker exec -i "$CORE_CONT" /opt/jboss/wildfly/bin/jboss-cli.sh --connect \
      --commands="/system-property=DS_CRC_SCHEMA:write-attribute(name=value,value=$NEW_SCHEMA),:reload"
  else
    docker exec -i "$CORE_CONT" bash -lc "cat >/tmp/switch_crc.cli" <<CLI
/subsystem=datasources/data-source=$CRC_DS_NAME:write-attribute(name=user-name,value=$CRC_USER)
/subsystem=datasources/data-source=$CRC_DS_NAME:write-attribute(name=password,value=$CRC_PASS)
/system-property=DS_CRC_SCHEMA:write-attribute(name=value,value=$NEW_SCHEMA)
:reload
CLI
    docker exec -i "$CORE_CONT" /opt/jboss/wildfly/bin/jboss-cli.sh --connect --file=/tmp/switch_crc.cli
    docker exec -i "$CORE_CONT" rm -f /tmp/switch_crc.cli
  fi

  ok "Core reconfigured (runtime). Note: this reverts if the container is recreated."
else
  warn "Not switching the core automatically (no --switch-core)."
  warn "To persistently point CRC to '$NEW_SCHEMA', update your core env and recreate container:"
  echo "  DS_CRC_SCHEMA=$NEW_SCHEMA"
  echo "  DS_CRC_USER=$CRC_USER"
  echo "  DS_CRC_PASS=<hidden>"
fi

ok "All done."
