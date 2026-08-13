#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d -t homa-online-security.XXXXXXXX)"
SERVE_DIST="$TEST_ROOT/serve"
PORT_FILE="$TEST_ROOT/server.port"
SERVER_LOG="$TEST_ROOT/server.log"
ARCHIVE="Homa-Ghost-Subscription-v2.3.0.zip"
CHECKSUM="${ARCHIVE}.sha256"
SERVER_PID=""

cleanup() {
  if [[ -n "$SERVER_PID" ]]; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  case "$TEST_ROOT" in /tmp/homa-online-security.*) find "$TEST_ROOT" -depth -delete ;; esac
}
trap cleanup EXIT

fail() { echo "online integration failure: $*" >&2; exit 1; }
command -v zip >/dev/null 2>&1 || fail "zip is required for release tests"
install -d -m 0755 "$SERVE_DIST"

write_checksum() {
  (cd "$SERVE_DIST" && sha256sum "$ARCHIVE" > "$CHECKSUM")
}

clear_served_release() {
  find "$SERVE_DIST" -mindepth 1 -maxdepth 1 -type f -delete
}

build_valid_release() {
  clear_served_release
  local stage="$TEST_ROOT/valid-stage" package="$TEST_ROOT/valid-stage/Homa-Ghost-Subscription-v2.3.0"
  if [[ -d "$stage" ]]; then find "$stage" -depth -delete; fi
  install -d -m 0755 "$package/vendor"
  install -m 0644 "$PROJECT_DIR/index.html" "$package/index.html"
  install -m 0644 "$PROJECT_DIR/config.default.env" "$package/config.default.env"
  install -m 0644 "$PROJECT_DIR/vendor/qrcode.js" "$package/vendor/qrcode.js"
  install -m 0755 "$PROJECT_DIR/homa-sub" "$package/homa-sub"
  install -m 0755 "$PROJECT_DIR/install.sh" "$package/install.sh"
  (cd "$stage" && zip -X -q -r "$SERVE_DIST/$ARCHIVE" Homa-Ghost-Subscription-v2.3.0)
  write_checksum
}

node "$PROJECT_DIR/tests/release-server.mjs" "$SERVE_DIST" > "$PORT_FILE" 2> "$SERVER_LOG" &
SERVER_PID=$!
for _ in {1..100}; do
  [[ -s "$PORT_FILE" ]] && break
  kill -0 "$SERVER_PID" 2>/dev/null || fail "release server stopped unexpectedly"
  sleep 0.05
done
[[ -s "$PORT_FILE" ]] || fail "release server did not publish a port"
SERVER_PORT="$(sed -n '1p' "$PORT_FILE")"
[[ "$SERVER_PORT" =~ ^[0-9]+$ ]] || fail "release server returned an invalid port"
BASE_URL="http://127.0.0.1:${SERVER_PORT}"

run_online() {
  local case_name="$1" case_root="$TEST_ROOT/cases/$1"
  install -d -m 0755 "$case_root"
  install -m 0600 /dev/null "$case_root/marzban.env"
  env \
    HOMA_GHOST_TEST_MODE=1 \
    HOMA_GHOST_BASE_URL="$BASE_URL" \
    HOMA_GHOST_NONINTERACTIVE=1 \
    HOMA_GHOST_TEMPLATE_DIR="$case_root/templates/subscription" \
    HOMA_GHOST_CONFIG_DIR="$case_root/config" \
    HOMA_GHOST_BACKUP_ROOT="$case_root/backups" \
    HOMA_GHOST_BIN_PATH="$case_root/bin/homa-sub" \
    HOMA_GHOST_SKIP_RESTART=1 \
    MARZBAN_ENV_FILE="$case_root/marzban.env" \
    bash "$PROJECT_DIR/install-online.sh"
}

expect_failure() {
  local case_name="$1" expected="$2" log
  log="$TEST_ROOT/${case_name}.log"
  if run_online "$case_name" > "$log" 2>&1; then
    fail "${case_name} unexpectedly succeeded"
  fi
  grep -Fq "$expected" "$log" || fail "${case_name} failed for an unexpected reason"
}

build_valid_release
run_online success >/dev/null
SUCCESS_ROOT="$TEST_ROOT/cases/success"
[[ "$($SUCCESS_ROOT/bin/homa-sub version)" == 2.3.0 ]] || fail "successful online install has the wrong version"
env HOMA_GHOST_TEMPLATE_DIR="$SUCCESS_ROOT/templates/subscription" HOMA_GHOST_CONFIG_DIR="$SUCCESS_ROOT/config" HOMA_GHOST_BACKUP_ROOT="$SUCCESS_ROOT/backups" HOMA_GHOST_BIN_PATH="$SUCCESS_ROOT/bin/homa-sub" HOMA_GHOST_SKIP_RESTART=1 MARZBAN_ENV_FILE="$SUCCESS_ROOT/marzban.env" "$SUCCESS_ROOT/bin/homa-sub" doctor --quiet

sed -i "s/  ${ARCHIVE}$/  wrong-name.zip/" "$SERVE_DIST/$CHECKSUM"
expect_failure checksum-name "ساختار فایل SHA-256 معتبر نیست"

build_valid_release
printf 'tampered\n' >> "$SERVE_DIST/$ARCHIVE"
expect_failure checksum-tamper "FAILED"

clear_served_release
TRAVERSAL_ROOT="$TEST_ROOT/traversal"
install -d -m 0755 "$TRAVERSAL_ROOT/safe"
install -m 0644 /dev/null "$TRAVERSAL_ROOT/escape-marker"
(cd "$TRAVERSAL_ROOT/safe" && zip -q "$SERVE_DIST/$ARCHIVE" ../escape-marker)
unzip -Z1 "$SERVE_DIST/$ARCHIVE" | grep -Fxq '../escape-marker' || fail "traversal fixture is invalid"
write_checksum
expect_failure zip-traversal "مسیر ناامن در فایل ZIP شناسایی شد"

clear_served_release
SYMLINK_STAGE="$TEST_ROOT/symlink-stage"
SYMLINK_PACKAGE="$SYMLINK_STAGE/Homa-Ghost-Subscription-v2.3.0"
install -d -m 0755 "$SYMLINK_PACKAGE"
install -m 0755 "$PROJECT_DIR/install.sh" "$SYMLINK_PACKAGE/install.sh"
ln -s install.sh "$SYMLINK_PACKAGE/unsafe-link"
(cd "$SYMLINK_STAGE" && zip -X -q -y -r "$SERVE_DIST/$ARCHIVE" Homa-Ghost-Subscription-v2.3.0)
write_checksum
expect_failure zip-symlink "پیوند نمادین ناامن در بسته ZIP شناسایی شد"

clear_served_release
LARGE_STAGE="$TEST_ROOT/large-stage"
LARGE_PACKAGE="$LARGE_STAGE/Homa-Ghost-Subscription-v2.3.0"
install -d -m 0755 "$LARGE_PACKAGE"
install -m 0755 "$PROJECT_DIR/install.sh" "$LARGE_PACKAGE/install.sh"
truncate -s 22000000 "$LARGE_PACKAGE/payload.bin"
(cd "$LARGE_STAGE" && zip -X -q -r "$SERVE_DIST/$ARCHIVE" Homa-Ghost-Subscription-v2.3.0)
write_checksum
expect_failure zip-size "اندازه بازشده بسته بیش از حد مجاز است"

echo "online installer integration: OK"
