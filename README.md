# Nix Cache Backends

## Google Cloud Storage over S3

<https://fzakaria.com/2021/06/22/setting-up-a-nix-google-cloud-storage-gcs-binary-cache.html>

### Pros

- Hosted on Google Cloud
- Nix native

### Cons

- Complex setup (installing AWS keys)

### Instructions

Dependencies:

```sh
nix shell nixpkgs#{google-cloud-sdk,awscli}
```

Create a Google Cloud Storage bucket:

```sh
PROJECT_ID=$(gcloud config get project)
CACHE_NAME=nix-cache-testing

gsutil mb gs://$CACHE_NAME
gsutil du -s gs://$CACHE_NAME
```

Add service account to bucket:

```sh
gcloud iam service-accounts create $CACHE_NAME \
  --description="Service account for Nix GCS cache" \
  --display-name="Nix GCS Service Account"

gcloud iam service-accounts list

gsutil hmac create $CACHE_NAME@$PROJECT_ID.iam.gserviceaccount.com \
  | sed -e '1i[gcp]' \
    -e 's/^ *Access ID: */aws_access_key_id = /' \
    -e 's/^ *Secret: */aws_secret_access_key = /' \
  >> ~/.aws/credentials

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$CACHE_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.admin" --condition=None

aws s3 ls --profile gcp --endpoint-url https://storage.googleapis.com
```

Build and copy to cache:

```sh
export AWS_EC2_METADATA_DISABLED=true # to skip some bullshit
SUB_URI="s3://$CACHE_NAME?endpoint=https://storage.googleapis.com&profile=gcp"

nix copy --to "$SUB_URI"
```

Or if you want to sign binaries, first generate a signing key:

```sh
nix key generate-secret --key-name $CACHE_NAME-1 > secret.pem
```

Then append `&secret-key=<PATH TO KEY FILE>` to the cache URI to sing uploads:

```sh
nix copy --to "$SUB_URI&secret-key=$PWD/secret.pem"
```

List the online store:

```sh
aws s3 ls $CACHE_NAME --profile=gcp --endpoint-url https://storage.googleapis.com
gsutil ls gs://$CACHE_NAME
nix store ls $(nix build --no-link --print-out-paths) --store "$SUB_URI"
```

Add to your user Nix config (signed):

```sh
cat >> ~/.config/nix/nix.conf <<EOF
extra-substituters = $SUB_URI&trusted=true
EOF
```

Or if signed:

```sh
cat >> ~/.config/nix/nix.conf <<EOF
extra-substituters = $SUB_URI
extra-trusted-public-keys = $(nix key convert-secret-to-public < ./secret.pem)
EOF
```

If running Nix in multi-user mode, add store credentials to root user so that
the nix-daemon has access as well:

```sh
sudo tee -a /root/.aws/credentials <~/.aws/credentials
sudo tee -a /etc/nix/nix.conf <<<"trusted-substituters = $SUB_URI&trusted=true"
```

Optional but recommended: To speedup S3 lookups you also have to set
`AWS_EC2_METADATA_DISABLED=true` env var for the `nix-daemon`. On
Linux with `systemd` this is relatively simple with: `systemctl edit
nix-daemon.service`. This is maybe harder on MacOS or other unknown
installations.

Try installing derivation and see if it downloads from cache, or if not,
starts to build locally:

```sh
nix store delete
nix build --no-link --option narinfo-cache-negative-ttl 0
```


## Casync

<https://github.com/flokli/nix-casync>

### Pros

- Content addressed cache store
- Written in Go-lang

### Cons

- Only self hosted
- Alpha


## Harmonia

<https://github.com/helsinki-systems/harmonia>

### Pros

- Written in Rust
- Used in production

### Cons

- Only self hosted
- Alpha
