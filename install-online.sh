#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="${HOMA_GHOST_VERSION:-2.3.0}"
REPOSITORY="${HOMA_GHOST_REPOSITORY:-radar-kx/homa-ghost-subscription}"
DEFAULT_BASE_URL="https://raw.githubusercontent.com/${REPOSITORY}/main"
BASE_URL="${HOMA_GHOST_BASE_URL:-$DEFAULT_BASE_URL}"
ARCHIVE="Homa-Ghost-Subscription-v${VERSION}.zip"
CHECKSUM_FILE="${ARCHIVE}.sha256"
EXTRACTED_DIR="Homa-Ghost-Subscription-v${VERSION}"
MANAGER_BIN="${HOMA_GHOST_BIN_PATH:-/usr/local/bin/homa-sub}"
TEMP_DIR=""

fail() { echo "خطا: $*" >&2; exit 1; }

cleanup() {
  if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
    case "$TEMP_DIR" in /tmp/homa-ghost.*|"${TMPDIR:-/tmp}"/homa-ghost.*) find "$TEMP_DIR" -depth -delete ;; esac
  fi
}
trap cleanup EXIT

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  case "${HOMA_GHOST_TEST_MODE:-0}:${HOMA_GHOST_TEMPLATE_DIR:-}:${HOMA_GHOST_CONFIG_DIR:-}:${HOMA_GHOST_BACKUP_ROOT:-}:${HOMA_GHOST_BIN_PATH:-}:${MARZBAN_ENV_FILE:-}" in
    1:/tmp/*:/tmp/*:/tmp/*:/tmp/*:/tmp/*) ;;
    *) fail "نصب باید با دسترسی root اجرا شود؛ دستور تک‌خطی را با sudo bash اجرا کن." ;;
  esac
fi

for command_name in awk curl find mktemp sha256sum; do
  command -v "$command_name" >/dev/null 2>&1 || fail "دستور ${command_name} روی سرور نصب نیست."
done

if ! command -v unzip >/dev/null 2>&1; then
  echo "ابزار unzip پیدا نشد؛ در حال نصب پیش‌نیاز..."
  if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y unzip
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y unzip
  elif command -v yum >/dev/null 2>&1; then
    yum install -y unzip
  else
    fail "نصب خودکار unzip ممکن نیست؛ ابتدا unzip را نصب کن."
  fi
fi

TEMP_DIR="$(mktemp -d -t homa-ghost.XXXXXXXX)"
ARCHIVE_PATH="${TEMP_DIR}/${ARCHIVE}"
CHECKSUM_PATH="${TEMP_DIR}/${CHECKSUM_FILE}"
UNPACK_DIR="${TEMP_DIR}/unpacked"

CURL_PROTOCOL_OPTIONS=(--proto '=https' --tlsv1.2)
if [[ -n ${HOMA_GHOST_BASE_URL:-} ]]; then CURL_PROTOCOL_OPTIONS=(); fi

echo "در حال دریافت Homa Ghost Subscription v${VERSION}..."
curl "${CURL_PROTOCOL_OPTIONS[@]}" -fsSL --retry 3 --connect-timeout 15 --max-time 300 \
  "${BASE_URL}/dist/${ARCHIVE}" -o "$ARCHIVE_PATH"
curl "${CURL_PROTOCOL_OPTIONS[@]}" -fsSL --retry 3 --connect-timeout 15 --max-time 60 \
  "${BASE_URL}/dist/${CHECKSUM_FILE}" -o "$CHECKSUM_PATH"

echo "در حال بررسی صحت بسته با SHA-256..."
mapfile -t checksum_lines < "$CHECKSUM_PATH"
[[ ${#checksum_lines[@]} -eq 1 ]] || fail "فایل SHA-256 باید دقیقاً یک رکورد داشته باشد."
read -r expected_hash expected_name extra <<< "${checksum_lines[0]}"
expected_name="${expected_name#\*}"
[[ "$expected_hash" =~ ^[0-9A-Fa-f]{64}$ && "$expected_name" == "$ARCHIVE" && -z "${extra:-}" ]] || \
  fail "ساختار فایل SHA-256 معتبر نیست."
(
  cd -- "$TEMP_DIR"
  sha256sum -c -- "$CHECKSUM_FILE"
)

entry_count=0
while IFS= read -r archive_entry; do
  entry_count=$((entry_count+1))
  (( entry_count <= 200 )) || fail "تعداد فایل‌های بسته غیرعادی است."
  case "$archive_entry" in
    /*|../*|*/../*|*/..) fail "مسیر ناامن در فایل ZIP شناسایی شد." ;;
  esac
done < <(unzip -Z1 "$ARCHIVE_PATH")
(( entry_count > 0 )) || fail "بسته ZIP خالی است."
uncompressed_size="$(unzip -l "$ARCHIVE_PATH" | awk 'END {print $1}')"
[[ "$uncompressed_size" =~ ^[0-9]+$ ]] || fail "اندازه محتوای ZIP قابل بررسی نیست."
(( uncompressed_size <= 20 * 1024 * 1024 )) || fail "اندازه بازشده بسته بیش از حد مجاز است."

mkdir -p -- "$UNPACK_DIR"
unzip -q -- "$ARCHIVE_PATH" -d "$UNPACK_DIR"
if [[ -n "$(find "$UNPACK_DIR" -type l -print -quit)" ]]; then
  fail "پیوند نمادین ناامن در بسته ZIP شناسایی شد."
fi

INSTALLER="${UNPACK_DIR}/${EXTRACTED_DIR}/install.sh"
[[ -f "$INSTALLER" ]] || fail "ساختار بسته دانلودشده معتبر نیست؛ install.sh پیدا نشد."
bash -n "$INSTALLER"
bash "$INSTALLER"

echo "نصب آنلاین Homa Ghost Subscription v${VERSION} با موفقیت تمام شد."

if [[ ${HOMA_GHOST_NONINTERACTIVE:-0} != 1 && -r /dev/tty && -w /dev/tty && -x "$MANAGER_BIN" ]]; then
  printf '\nمی‌خواهی نام برند، پشتیبانی، کانال، رنگ و لوگو را الان تنظیم کنی؟ [y/N]: ' > /dev/tty
  IFS= read -r answer < /dev/tty || answer=""
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    "$MANAGER_BIN" configure < /dev/tty > /dev/tty
  else
    echo "بعداً با دستور homa-sub configure می‌توانی شخصی‌سازی کنی." > /dev/tty
  fi
fi
