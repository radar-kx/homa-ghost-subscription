#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="2.1.0"
TEMPLATE_DIR="/var/lib/marzban/templates/subscription"
TEMPLATE_FILE="${TEMPLATE_DIR}/index.html"
VENDOR_DIR="${TEMPLATE_DIR}/vendor"
VENDOR_FILE="${VENDOR_DIR}/qrcode.js"
ENV_FILE="${MARZBAN_ENV_FILE:-/opt/marzban/.env}"
SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_FILE="${SOURCE_DIR}/index.html"
VENDOR_SOURCE="${SOURCE_DIR}/vendor/qrcode.js"
BACKUP_ROOT="/var/lib/marzban/templates/backups"
STAMP="$(date +%Y%m%d-%H%M%S)-$$"
BACKUP_DIR="${BACKUP_ROOT}/homa-ghost-${STAMP}"
HAD_TEMPLATE=0
HAD_VENDOR=0
INSTALL_COMPLETE=0

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "این نصب‌کننده باید با کاربر root اجرا شود." >&2
  exit 1
fi

for required_file in "$SOURCE_FILE" "$VENDOR_SOURCE" "$ENV_FILE"; do
  if [[ ! -f "$required_file" ]]; then
    echo "فایل لازم پیدا نشد: $required_file" >&2
    exit 1
  fi
done

if ! grep -Fq '{{ user.username }}' "$SOURCE_FILE" ||
   ! grep -Fq 'user.subscription_url' "$SOURCE_FILE" ||
   ! grep -Fq 'subscription/vendor/qrcode.js' "$SOURCE_FILE"; then
  echo "ساختار index.html معتبر نیست؛ نصب متوقف شد." >&2
  exit 1
fi

install -d -m 0755 "$TEMPLATE_DIR" "$VENDOR_DIR" "$BACKUP_DIR"

if [[ -f "$TEMPLATE_FILE" ]]; then
  HAD_TEMPLATE=1
  cp -a -- "$TEMPLATE_FILE" "${BACKUP_DIR}/index.html"
fi

if [[ -f "$VENDOR_FILE" ]]; then
  HAD_VENDOR=1
  cp -a -- "$VENDOR_FILE" "${BACKUP_DIR}/qrcode.js"
fi

cp -a -- "$ENV_FILE" "${BACKUP_DIR}/marzban.env"

rollback() {
  local exit_code=$?
  if [[ $INSTALL_COMPLETE -eq 1 ]]; then
    return
  fi

  set +e
  echo "نصب کامل نشد؛ بازگردانی نسخه قبلی..." >&2

  if [[ $HAD_TEMPLATE -eq 1 ]]; then
    install -m 0644 -- "${BACKUP_DIR}/index.html" "$TEMPLATE_FILE"
  else
    rm -f -- "$TEMPLATE_FILE"
  fi

  if [[ $HAD_VENDOR -eq 1 ]]; then
    install -m 0644 -- "${BACKUP_DIR}/qrcode.js" "$VENDOR_FILE"
  else
    rm -f -- "$VENDOR_FILE"
  fi

  install -m 0600 -- "${BACKUP_DIR}/marzban.env" "$ENV_FILE"
  if command -v marzban >/dev/null 2>&1; then
    marzban restart >/dev/null 2>&1 || true
  fi

  echo "نسخه قبلی از ${BACKUP_DIR} بازیابی شد." >&2
  exit "$exit_code"
}
trap rollback ERR INT TERM

install -m 0644 -- "$SOURCE_FILE" "$TEMPLATE_FILE"
install -m 0644 -- "$VENDOR_SOURCE" "$VENDOR_FILE"

upsert_env() {
  local key="$1"
  local value="$2"
  if grep -qE "^[[:space:]#]*${key}=" "$ENV_FILE"; then
    sed -i -E "s|^[[:space:]#]*${key}=.*$|${key}=${value}|" "$ENV_FILE"
  else
    printf '\n%s=%s\n' "$key" "$value" >> "$ENV_FILE"
  fi
}

upsert_env "CUSTOM_TEMPLATES_DIRECTORY" '"/var/lib/marzban/templates/"'
upsert_env "SUBSCRIPTION_PAGE_TEMPLATE" '"subscription/index.html"'

if command -v marzban >/dev/null 2>&1; then
  marzban restart
  RESTART_MESSAGE="مرزبان ری‌استارت شد و قالب فعال است."
else
  RESTART_MESSAGE="دستور marzban پیدا نشد؛ برای فعال‌شدن قالب، مرزبان را دستی ری‌استارت کن."
fi

INSTALL_COMPLETE=1
trap - ERR INT TERM

echo "قالب Homa Ghost v${VERSION} نصب شد."
echo "$RESTART_MESSAGE"
echo "بکاپ نصب در این مسیر است: ${BACKUP_DIR}"
