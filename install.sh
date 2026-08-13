#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="2.3.0"
TEMPLATE_DIR="${HOMA_GHOST_TEMPLATE_DIR:-/var/lib/marzban/templates/subscription}"
TEMPLATE_FILE="${TEMPLATE_DIR}/index.html"
VENDOR_DIR="${TEMPLATE_DIR}/vendor"
VENDOR_FILE="${VENDOR_DIR}/qrcode.js"
TEMPLATE_CONFIG_FILE="${TEMPLATE_DIR}/config.js"
CONFIG_DIR="${HOMA_GHOST_CONFIG_DIR:-/etc/homa-ghost-subscription}"
CONFIG_FILE="${CONFIG_DIR}/config.env"
ENV_FILE="${MARZBAN_ENV_FILE:-/opt/marzban/.env}"
BACKUP_ROOT="${HOMA_GHOST_BACKUP_ROOT:-/var/lib/marzban/templates/backups}"
MANAGER_BIN="${HOMA_GHOST_BIN_PATH:-/usr/local/bin/homa-sub}"
SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_FILE="${SOURCE_DIR}/index.html"
VENDOR_SOURCE="${SOURCE_DIR}/vendor/qrcode.js"
CONFIG_DEFAULT_SOURCE="${SOURCE_DIR}/config.default.env"
MANAGER_SOURCE="${SOURCE_DIR}/homa-sub"
BACKUP_DIR=""
INSTALL_COMPLETE=0
CREATED_CONFIG=0
MIGRATED_BRAND=""
MIGRATED_SUPPORT=""
MIGRATED_CHANNEL=""

fail() { echo "خطا: $*" >&2; exit 1; }

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  case "${HOMA_GHOST_TEST_MODE:-0}:$TEMPLATE_DIR:$CONFIG_DIR:$BACKUP_ROOT:$MANAGER_BIN:$ENV_FILE" in
    1:/tmp/*:/tmp/*:/tmp/*:/tmp/*:/tmp/*) ;;
    *) fail "این نصب‌کننده باید با کاربر root اجرا شود." ;;
  esac
fi

for required_file in "$SOURCE_FILE" "$VENDOR_SOURCE" "$CONFIG_DEFAULT_SOURCE" "$MANAGER_SOURCE" "$ENV_FILE"; do
  [[ -f "$required_file" ]] || fail "فایل لازم پیدا نشد: $required_file"
done

bash -n "$MANAGER_SOURCE"

if ! grep -Fq '{{ user.username }}' "$SOURCE_FILE" ||
   ! grep -Fq 'user.subscription_url' "$SOURCE_FILE" ||
   ! grep -Fq 'subscription/vendor/qrcode.js' "$SOURCE_FILE" ||
   ! grep -Fq 'subscription/config.js' "$SOURCE_FILE"; then
  fail "ساختار index.html معتبر نیست؛ نصب متوقف شد."
fi

if [[ ! -f "$CONFIG_FILE" && -f "$TEMPLATE_FILE" ]]; then
  MIGRATED_BRAND="$(sed -nE 's/.*brandName:"([^"]*)".*/\1/p' "$TEMPLATE_FILE" | head -n1 || true)"
  MIGRATED_SUPPORT="$(sed -nE 's/.*supportUrl:"([^"]*)".*/\1/p' "$TEMPLATE_FILE" | head -n1 || true)"
  MIGRATED_CHANNEL="$(sed -nE 's/.*channelUrl:"([^"]*)".*/\1/p' "$TEMPLATE_FILE" | head -n1 || true)"
fi

BACKUP_DIR="$(
  HOMA_GHOST_TEMPLATE_DIR="$TEMPLATE_DIR" \
  HOMA_GHOST_CONFIG_DIR="$CONFIG_DIR" \
  HOMA_GHOST_BACKUP_ROOT="$BACKUP_ROOT" \
  HOMA_GHOST_BIN_PATH="$MANAGER_BIN" \
  MARZBAN_ENV_FILE="$ENV_FILE" \
  bash "$MANAGER_SOURCE" backup --quiet --print-path --no-prune
)"
[[ -n "$BACKUP_DIR" && -d "$BACKUP_DIR" ]] || fail "ساخت بکاپ پیش از نصب ناموفق بود."

rollback() {
  local exit_code=$?
  [[ $INSTALL_COMPLETE -eq 0 ]] || return 0
  trap - ERR INT TERM
  set +e
  echo "نصب کامل نشد؛ در حال بازگردانی وضعیت قبلی..." >&2
  HOMA_GHOST_TEMPLATE_DIR="$TEMPLATE_DIR" \
  HOMA_GHOST_CONFIG_DIR="$CONFIG_DIR" \
  HOMA_GHOST_BACKUP_ROOT="$BACKUP_ROOT" \
  HOMA_GHOST_BIN_PATH="$MANAGER_BIN" \
  HOMA_GHOST_SKIP_RESTART=1 \
  MARZBAN_ENV_FILE="$ENV_FILE" \
  bash "$MANAGER_SOURCE" restore --path "$BACKUP_DIR" --yes --no-backup --no-restart >/dev/null 2>&1
  if [[ ${HOMA_GHOST_SKIP_RESTART:-0} != 1 ]] && command -v marzban >/dev/null 2>&1; then
    marzban restart >/dev/null 2>&1 || true
  fi
  echo "وضعیت قبلی از ${BACKUP_DIR} بازیابی شد." >&2
  exit "$exit_code"
}
trap rollback ERR INT TERM

install -d -m 0755 -- "$TEMPLATE_DIR" "$VENDOR_DIR"
install -d -m 0700 -- "$CONFIG_DIR"
install -m 0644 -- "$SOURCE_FILE" "$TEMPLATE_FILE"
install -m 0644 -- "$VENDOR_SOURCE" "$VENDOR_FILE"
install -D -m 0755 -- "$MANAGER_SOURCE" "$MANAGER_BIN"

if [[ ! -f "$CONFIG_FILE" ]]; then
  install -m 0600 -- "$CONFIG_DEFAULT_SOURCE" "$CONFIG_FILE"
  CREATED_CONFIG=1
fi

configure_args=(configure --non-interactive --no-backup --no-restart)
if [[ $CREATED_CONFIG -eq 1 ]]; then
  [[ -n "$MIGRATED_BRAND" ]] && configure_args+=(--brand "$MIGRATED_BRAND")
  [[ -n "$MIGRATED_SUPPORT" ]] && configure_args+=(--support "$MIGRATED_SUPPORT")
  [[ -n "$MIGRATED_CHANNEL" ]] && configure_args+=(--channel "$MIGRATED_CHANNEL")
fi
[[ -n ${HOMA_GHOST_BRAND_NAME+x} ]] && configure_args+=(--brand "$HOMA_GHOST_BRAND_NAME")
[[ -n ${HOMA_GHOST_SUPPORT_URL+x} ]] && configure_args+=(--support "$HOMA_GHOST_SUPPORT_URL")
[[ -n ${HOMA_GHOST_CHANNEL_URL+x} ]] && configure_args+=(--channel "$HOMA_GHOST_CHANNEL_URL")
[[ -n ${HOMA_GHOST_PRIMARY_COLOR+x} ]] && configure_args+=(--color "$HOMA_GHOST_PRIMARY_COLOR")
[[ -n ${HOMA_GHOST_LOGO_URL+x} ]] && configure_args+=(--logo "$HOMA_GHOST_LOGO_URL")
[[ -n ${HOMA_GHOST_RENEWAL_MESSAGE+x} ]] && configure_args+=(--renewal-message "$HOMA_GHOST_RENEWAL_MESSAGE")

HOMA_GHOST_TEMPLATE_DIR="$TEMPLATE_DIR" \
HOMA_GHOST_CONFIG_DIR="$CONFIG_DIR" \
HOMA_GHOST_BACKUP_ROOT="$BACKUP_ROOT" \
HOMA_GHOST_BIN_PATH="$MANAGER_BIN" \
HOMA_GHOST_SKIP_RESTART=1 \
MARZBAN_ENV_FILE="$ENV_FILE" \
"$MANAGER_BIN" "${configure_args[@]}" >/dev/null

upsert_env() {
  local key="$1" value="$2"
  if grep -qE "^[[:space:]#]*${key}=" "$ENV_FILE"; then
    sed -i -E "s|^[[:space:]#]*${key}=.*$|${key}=${value}|" "$ENV_FILE"
  else
    printf '\n%s=%s\n' "$key" "$value" >> "$ENV_FILE"
  fi
}

upsert_env "CUSTOM_TEMPLATES_DIRECTORY" '"/var/lib/marzban/templates/"'
upsert_env "SUBSCRIPTION_PAGE_TEMPLATE" '"subscription/index.html"'

HOMA_GHOST_TEMPLATE_DIR="$TEMPLATE_DIR" \
HOMA_GHOST_CONFIG_DIR="$CONFIG_DIR" \
HOMA_GHOST_BACKUP_ROOT="$BACKUP_ROOT" \
HOMA_GHOST_BIN_PATH="$MANAGER_BIN" \
MARZBAN_ENV_FILE="$ENV_FILE" \
"$MANAGER_BIN" doctor --quiet

if [[ ${HOMA_GHOST_SKIP_RESTART:-0} == 1 ]]; then
  RESTART_MESSAGE="ری‌استارت مرزبان طبق تنظیم محیط اجرا نشد."
elif command -v marzban >/dev/null 2>&1; then
  marzban restart
  RESTART_MESSAGE="مرزبان ری‌استارت شد و قالب فعال است."
else
  RESTART_MESSAGE="دستور marzban پیدا نشد؛ برای فعال‌شدن قالب، مرزبان را دستی ری‌استارت کن."
fi

INSTALL_COMPLETE=1
trap - ERR INT TERM

HOMA_GHOST_BACKUP_ROOT="$BACKUP_ROOT" "$MANAGER_BIN" prune-backups

echo "قالب Homa Ghost v${VERSION} نصب یا بروزرسانی شد."
echo "$RESTART_MESSAGE"
echo "تنظیمات شخصی در بروزرسانی‌های بعدی حفظ می‌شود."
echo "مدیریت قالب: homa-sub"
echo "بکاپ نصب در این مسیر است: ${BACKUP_DIR}"
