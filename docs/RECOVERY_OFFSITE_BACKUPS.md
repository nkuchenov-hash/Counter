# LIFE OS — external encrypted staging backups

Status: opt-in, NOT yet configured on LIFEOS2. This does not recover lost Beget production data. Current archives contain the reconstructed test DB.

Scripts:
- scripts/recovery/sync_offsite_stage.sh: uploads validated staging archives to independently hosted encrypted restic repository.
- scripts/recovery/install_offsite_stage.sh: installs restic and daily timer. Timer stays off until credentials exist and a first upload succeeds.

## Requirements
Provision a separate S3-compatible storage bucket with a provider independent of AdminVPS LIFEOS2. Enable object versioning and retention/immutability if supported. Keep access keys restricted to that bucket.

On LIFEOS2, create /etc/lifeos/offsite-backup.env, owned by root, mode 0600:

```sh
RESTIC_REPOSITORY='s3:https://YOUR-S3-ENDPOINT/YOUR-BUCKET/lifeos-stage'
RESTIC_PASSWORD_FILE='/etc/lifeos/offsite-repository-password'
AWS_ACCESS_KEY_ID='YOUR-BUCKET-SCOPED-ID'
AWS_SECRET_ACCESS_KEY='YOUR-BUCKET-SCOPED-SECRET'
AWS_DEFAULT_REGION='YOUR-REGION'
```

Create /etc/lifeos/offsite-repository-password with a separate strong password, owned by root, mode 0600. Store an independently recoverable copy of the password OUTSIDE LIFEOS2. Never paste credentials in chat or commit them to GitHub.

Initialize once, on the server, then install verified daily uploads:

```sh
set -a
source /etc/lifeos/offsite-backup.env
set +a
restic init
bash /opt/lifeos/source/scripts/recovery/install_offsite_stage.sh
```

The installer checks the first upload using restic check before enabling the daily 04:20 UTC timer. A remote location other than s3:https:// is rejected outside explicit isolated CI tests.

Periodically test a full restore on a DIFFERENT machine: restore latest restic snapshot, verify SHA256 checksums of the archived backup, unpack the PocketBase DB and check SQLite PRAGMA integrity_check. Include actual user records and IDs in a production recovery drill. Secrets for Viktor and Android signing require independent handling.

Do not change production endpoint or create real accounts on staging during the recovery.