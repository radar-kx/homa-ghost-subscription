#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d -t homa-sub-integration.XXXXXXXX)"

cleanup() {
  case "$TEST_ROOT" in /tmp/homa-sub-integration.*) find "$TEST_ROOT" -depth -delete ;; esac
}
trap cleanup EXIT

fail() { echo "integration failure: $*" >&2; exit 1; }

TEMPLATE_DIR="$TEST_ROOT/templates/subscription"
CONFIG_DIR="$TEST_ROOT/config"
BACKUP_ROOT="$TEST_ROOT/backups"
MANAGER_BIN="$TEST_ROOT/bin/homa-sub"
ENV_FILE="$TEST_ROOT/marzban.env"
install -m 0600 /dev/null "$ENV_FILE"

COMMON_ENV=(
  HOMA_GHOST_TEST_MODE=1
  HOMA_GHOST_TEMPLATE_DIR="$TEMPLATE_DIR"
  HOMA_GHOST_CONFIG_DIR="$CONFIG_DIR"
  HOMA_GHOST_BACKUP_ROOT="$BACKUP_ROOT"
  HOMA_GHOST_BIN_PATH="$MANAGER_BIN"
  HOMA_GHOST_SKIP_RESTART=1
  MARZBAN_ENV_FILE="$ENV_FILE"
)

run_install() { env "${COMMON_ENV[@]}" bash "$PROJECT_DIR/install.sh"; }
run_manager() { env "${COMMON_ENV[@]}" "$MANAGER_BIN" "$@"; }

run_install >/dev/null
[[ -s "$TEMPLATE_DIR/index.html" ]] || fail "template was not installed"
[[ -s "$TEMPLATE_DIR/vendor/qrcode.js" ]] || fail "QR vendor was not installed"
[[ -s "$TEMPLATE_DIR/config.js" ]] || fail "rendered config was not installed"
[[ -x "$MANAGER_BIN" ]] || fail "manager was not installed"
[[ "$(stat -c '%a' "$CONFIG_DIR/config.env")" == 600 ]] || fail "config.env permissions are not 600"
grep -q '^CUSTOM_TEMPLATES_DIRECTORY=' "$ENV_FILE" || fail "custom template env is missing"
grep -q '^SUBSCRIPTION_PAGE_TEMPLATE=' "$ENV_FILE" || fail "subscription template env is missing"
run_manager doctor --quiet
[[ "$(run_manager version)" == 2.3.0 ]] || fail "manager version mismatch"

run_manager configure --non-interactive --no-restart \
  --brand 'هما </script><script>x</script> & "آزمایشی"' \
  --support 'https://t.me/TestSupport' \
  --channel 'https://t.me/TestChannel' \
  --color '#12abEF' \
  --logo 'https://example.com/logo.png' \
  --renewal-message 'تمدید برای {username} با وضعیت {status}' >/dev/null

grep -Fq 'BRAND_NAME=هما </script><script>x</script> & "آزمایشی"' "$CONFIG_DIR/config.env" || fail "brand was not persisted"
grep -Fq 'brandName:"هما \u003c/script\u003e\u003cscript\u003ex\u003c/script\u003e \u0026 \"آزمایشی\""' "$TEMPLATE_DIR/config.js" || fail "brand was not JSON and HTML escaped"
! grep -Fq '</script>' "$TEMPLATE_DIR/config.js" || fail "rendered config contains a script terminator"
grep -Fq 'primaryColor:"#12abEF"' "$TEMPLATE_DIR/config.js" || fail "color was not rendered"
node -e 'global.window={};eval(require("fs").readFileSync(process.argv[1],"utf8"));if(window.HOMA_GHOST_CUSTOM_CONFIG.brandName!==`هما </script><script>x</script> & "آزمایشی"`)process.exit(1)' "$TEMPLATE_DIR/config.js"

CONFIG_HASH="$(sha256sum "$CONFIG_DIR/config.env" | cut -d' ' -f1)"
if run_manager configure --non-interactive --no-restart --brand $'bad\tbrand' >/dev/null 2>&1; then
  fail "manager accepted a control character"
fi
if run_manager configure --non-interactive --no-restart --color '#xyzxyz' >/dev/null 2>&1; then
  fail "manager accepted an invalid color"
fi
if run_manager configure --non-interactive --no-restart --support 'http://insecure.example' >/dev/null 2>&1; then
  fail "manager accepted an insecure support URL"
fi
if run_manager configure --non-interactive --no-restart --support 'https://user:secret@example.com' >/dev/null 2>&1; then
  fail "manager accepted credentials in the support URL"
fi
[[ "$(sha256sum "$CONFIG_DIR/config.env" | cut -d' ' -f1)" == "$CONFIG_HASH" ]] || fail "invalid configuration changed settings"
run_install >/dev/null
[[ "$(sha256sum "$CONFIG_DIR/config.env" | cut -d' ' -f1)" == "$CONFIG_HASH" ]] || fail "update did not preserve configuration"

BACKUP_PATH="$(run_manager backup --quiet --print-path --no-prune)"
printf '\nBROKEN_MARKER\n' >> "$TEMPLATE_DIR/index.html"
run_manager restore --path "$BACKUP_PATH" --yes >/dev/null
! grep -q 'BROKEN_MARKER' "$TEMPLATE_DIR/index.html" || fail "restore did not recover template"

CORRUPT_BACKUP="$(run_manager backup --quiet --print-path --no-prune)"
sed -i 's/^TEMPLATE_CONFIG_FILE=1$/TEMPLATE_CONFIG_FILE=invalid/' "$CORRUPT_BACKUP/manifest"
BEFORE_CORRUPT_RESTORE="$(sha256sum "$TEMPLATE_DIR/index.html" | cut -d' ' -f1)"
if run_manager restore --path "$CORRUPT_BACKUP" --yes >/dev/null 2>&1; then
  fail "manager accepted a corrupt backup manifest"
fi
[[ "$(sha256sum "$TEMPLATE_DIR/index.html" | cut -d' ' -f1)" == "$BEFORE_CORRUPT_RESTORE" ]] || fail "corrupt restore changed the template"

TAMPERED_BACKUP="$(run_manager backup --quiet --print-path --no-prune)"
printf '\nTAMPERED_BACKUP\n' >> "$TAMPERED_BACKUP/template/config.js"
if run_manager restore --path "$TAMPERED_BACKUP" --yes >/dev/null 2>&1; then
  fail "manager accepted a backup with a mismatched checksum"
fi
[[ "$(sha256sum "$TEMPLATE_DIR/index.html" | cut -d' ' -f1)" == "$BEFORE_CORRUPT_RESTORE" ]] || fail "tampered restore changed the template"

OUTSIDE_BACKUP="$TEST_ROOT/outside-backup"
cp -a -- "$BACKUP_PATH" "$OUTSIDE_BACKUP"
mkdir -p "$BACKUP_ROOT/homa-ghost-decoy"
if run_manager restore --path "$BACKUP_ROOT/homa-ghost-decoy/../../outside-backup" --yes >/dev/null 2>&1; then
  fail "manager accepted a path-traversal backup"
fi
find "$BACKUP_ROOT/homa-ghost-decoy" -depth -delete

printf '\nROLLBACK_MARKER\n' >> "$TEMPLATE_DIR/index.html"
ROLLBACK_HASH="$(sha256sum "$TEMPLATE_DIR/index.html" | cut -d' ' -f1)"
FAIL_BIN="$TEST_ROOT/fail-bin"
mkdir -p "$FAIL_BIN"
printf '#!/usr/bin/env bash\nexit 23\n' > "$FAIL_BIN/marzban"
chmod 0755 "$FAIL_BIN/marzban"
if env "${COMMON_ENV[@]}" HOMA_GHOST_SKIP_RESTART=0 PATH="$FAIL_BIN:$PATH" bash "$PROJECT_DIR/install.sh" >/dev/null 2>&1; then
  fail "installer unexpectedly succeeded with a failing Marzban restart"
fi
[[ "$(sha256sum "$TEMPLATE_DIR/index.html" | cut -d' ' -f1)" == "$ROLLBACK_HASH" ]] || fail "failed install did not roll back"
run_install >/dev/null

for _ in 1 2 3 4 5; do run_manager backup --quiet; done
run_manager prune-backups
BACKUP_COUNT="$(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -name 'homa-ghost-*' | wc -l)"
(( BACKUP_COUNT <= 3 )) || fail "backup retention exceeded three copies"

MIGRATION_ROOT="$TEST_ROOT/migration"
MIGRATION_TEMPLATE="$MIGRATION_ROOT/templates/subscription"
MIGRATION_CONFIG="$MIGRATION_ROOT/config"
MIGRATION_BACKUPS="$MIGRATION_ROOT/backups"
MIGRATION_BIN="$MIGRATION_ROOT/bin/homa-sub"
MIGRATION_ENV="$MIGRATION_ROOT/marzban.env"
mkdir -p "$MIGRATION_TEMPLATE"
install -m 0600 /dev/null "$MIGRATION_ENV"
printf '<script>const APP_CONFIG={brandName:"برند قدیمی",supportUrl:"https://t.me/OldSupport",channelUrl:"https://t.me/OldChannel"};</script>\n' > "$MIGRATION_TEMPLATE/index.html"
env HOMA_GHOST_TEST_MODE=1 HOMA_GHOST_TEMPLATE_DIR="$MIGRATION_TEMPLATE" HOMA_GHOST_CONFIG_DIR="$MIGRATION_CONFIG" HOMA_GHOST_BACKUP_ROOT="$MIGRATION_BACKUPS" HOMA_GHOST_BIN_PATH="$MIGRATION_BIN" HOMA_GHOST_SKIP_RESTART=1 MARZBAN_ENV_FILE="$MIGRATION_ENV" bash "$PROJECT_DIR/install.sh" >/dev/null
grep -Fq 'BRAND_NAME=برند قدیمی' "$MIGRATION_CONFIG/config.env" || fail "legacy brand was not migrated"
grep -Fq 'SUPPORT_URL=https://t.me/OldSupport' "$MIGRATION_CONFIG/config.env" || fail "legacy support URL was not migrated"

run_manager doctor --quiet
run_manager uninstall --yes >/dev/null
[[ ! -e "$TEMPLATE_DIR/index.html" ]] || fail "uninstall left the template behind"
[[ ! -e "$MANAGER_BIN" ]] || fail "uninstall left the manager behind"
! grep -q '^SUBSCRIPTION_PAGE_TEMPLATE=' "$ENV_FILE" || fail "uninstall left subscription env enabled"

echo "installer integration: OK"
