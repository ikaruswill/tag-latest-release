# tag-latest-release
A bash script to tag a repository with the latest release tag of an upstream repo.

## Usage
```bash
docker run --rm \
-e "REPO_URL=git@github.com:username/repo.git" \
-e "UPSTREAM_URL=git@github.com:upstream_user/repo.git" \
-e "SSH_PRIVATE_KEY_FILE=/id_rsa" \
-v path/to/ssh/privatekey:/id_rsa \
ikaruswill/tag-latest-release
```

## Environment variables
```
REPO_URL              : Forked repository URL
UPSTREAM_URL          : Upstream repository URL
SSH_PRIVATE_KEY_FILE  : Path to SSH private key with push access
```

## Volumes
```
/repos                : Repository cache (to avoid clone on every run)