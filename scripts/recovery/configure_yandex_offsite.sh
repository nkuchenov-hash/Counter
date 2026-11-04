#!/usr/bin/env bash
set -euo pipefail
# One-time interactive setup of encrypted offsite staging backups.
# Credentials are read silently over the existing SSH terminal and are never
# printed, written to shell history, or committed to GitHub.
[ "$(id -u)" -eq 0 ] || { echo "ERROR: run as root over SSH." >&2; exit 1; }
[ -t 0 ] || { echo "ERROR: interactive SSH terminal required." >&2; exit 1; }
umask 077
secrets_dir=/etc/lifeos
conf="$secrets_dir/offsite-backup.env"
password_file="$secrets_dir/offsite-repository-password"
if [ -e "$conf" ] || [ -e "$password_file" ]; then
  echo "ERROR: existing offsite config or password found; refusing overwrite." >&2
  exit 1
fi
command -v openssl >/dev/null || { echo "ERROR: openssl is required." >&2; exit 1; }
install -d -m 0700 "$secrets_dir"
printf 'Yandex S3 access key identifier (not the service-account ID): '
IFS= read -r -s access_key
printf '\n'
printf 'Yandex S3 secret key (input hidden): '
IFS= read -r -s secret_key
printf '\n'
[[ "$access_key" =~ ^[[:alnum:]_-]{12,128}$ ]] || {
  echo "ERROR: invalid S3 access key ID." >&2; exit 1;
}
[ "\${#secret_key}" -ge 20 ] || {
  echo "ERROR: S3 secret is unexpectedly short." >&2; exit 1;
}
# Escape values as shell literals; no user-supplied code can be executed.
tmp="$(mktemp "$secrets_dir/.offsite.XXXXXXXX")"
trap 'rm -f "$tmp"' EXIT
{
  printf 'RESTIC_REPOSITORY=%q\n' 's3:https://storage.yandexcloud.net/lifeos-backups-2026-nk47/lifeos-stage'
  printf 'RESTIC_PASSWORD_FILE=%q\n' "$password_file"
  printf 'AWS_DEFAULT_REGION=%q\n' 'ru-central1'
  printf 'AWS_ACCESS_KEY_ID=%q\n' "$access_key"
  printf 'AWS_SECRET_ACCESS_KEY=%q\n' "$secret_key"
} > "$tmp"
unset secret_key access_key
chmod 0600 "$tmp"
chown root:root "$tmp"
mv "$tmp" "$conf"
trap - EXIT
openssl rand -hex 32 > "$password_file"
chmod 0600 "$password_file"
chown root:root "$password_file"
printf 'Credentials are now stored locally with root-only access.\n'
export DEBIAN_FRONTEND=noninteractive
apt-get install -y restic
set -a
source "$conf"
set +a
# This is a newly created, dedicated bucket path. Do not initialize an
# existing repository if a user previously ran this installer.
restic init
bash /opt/lifeos/source/scripts/recovery/install_offsite_stage.sh
echo 'SUCCESS: encrypted offsite transfer and daily timer configured.'
echo 'CRITICAL: copy /etc/lifeos/offsite-repository-password to secure storage OUTSIDE LIFEOS2.'
