# tag-latest-release
A bash script to tag a repository with the latest release tag of an upstream repo.
- To be used in a cron job (e.g. K8s CronJob) to trigger CICD pipelines in
  repositories that build on 'tag' events.
- For people who maintain their own docker images based off upstream images and want
  to automate the build process.

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
REPO_URL              : Docker image repository URL
UPSTREAM_URL          : Upstream repository URL
SSH_PRIVATE_KEY_FILE  : Path to SSH private key with push access
```

## Volumes
```
/repos                : Repository cache (to avoid clone on every run)
```

## Notes
- It is possible to miss releases if the upstream repository releases at a frequency higher than your cron frequency, you should set your cronjob to check at at least twice the expected frequency of release.
- Github API has rate-limits of 60 requests per hour (for non-authenticated requests), you should have no more than 60 executions of this script every hour.
- There are currently no plans to implement authenticated requests which will grant rate-limits of 5000 requests per hour.