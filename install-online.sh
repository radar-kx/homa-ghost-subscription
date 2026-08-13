#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="${HOMA_GHOST_VERSION:-2.2.0}"
REPOSITORY="${HOMA_GHOST_REPOSITORY:-radar-kx/homa-ghost-subscription}"
DEFAULT_BASE_URL="https://raw.githubusercontent.com/${REPOSITORY}/main"
BASE_URL="${HOMA_GHOST_BASE_URL:-$DEFAULT_BASE_URL}"
ARCHIVE="Homa-Ghost-Subscription-v${VERSION}.zip"
CHECKSUM_FILE="${ARCHIVE}.sha256"
EXTRACTED_DIR="Homa-Ghost-Subscription-v${VERSION}"
TEMP_DIR=""

fail() {
  echo "خطا: $*" >&2
  exit 1
}

cleanup() {
  if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
    rm -rf -- "$TEMP_DIR"
  fi
}

trap cleanup EXIT

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  fail "نصب باید با دسترسی root اجرا شود؛ دستور تک‌خطی را با sudo bash اجرا کن."
fi

for command_name in curl mktemp sha256sum; do
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
if [[ -n ${HOMA_GHOST_BASE_URL:-} ]]; then
  CURL_PROTOCOL_OPTIONS=()
fi

echo "در حال دریافت Homa Ghost Subscription v${VERSION}..."
curl "${CURL_PROTOCOL_OPTIONS[@]}" -fsSL --retry 3 --connect-timeout 15 --max-time 300 \
  "${BASE_URL}/dist/${ARCHIVE}" -o "$ARCHIVE_PATH"
curl "${CURL_PROTOCOL_OPTIONS[@]}" -fsSL --retry 3 --connect-timeout 15 --max-time 60 \
  "${BASE_URL}/dist/${CHECKSUM_FILE}" -o "$CHECKSUM_PATH"

echo "در حال بررسی صحت بسته با SHA-256..."
(
  cd -- "$TEMP_DIR"
  sha256sum -c -- "$CHECKSUM_FILE"
)

mkdir -p -- "$UNPACK_DIR"
unzip -q -- "$ARCHIVE_PATH" -d "$UNPACK_DIR"

INSTALLER="${UNPACK_DIR}/${EXTRACTED_DIR}/install.sh"
[[ -f "$INSTALLER" ]] || fail "ساختار بسته دانلودشده معتبر نیست؛ install.sh پیدا نشد."

bash "$INSTALLER"

echo "نصب آنلاین Homa Ghost Subscription v${VERSION} با موفقیت تمام شد."
