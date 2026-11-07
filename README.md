# github-audit-alerter

Send Slack alerts based on GitHub Audit Events, including two major categories of events:

* Excessive repository clones by a single user
* Unexpected events, such as a private repository being made public

This is chiefly to detect whether or not someone's Github credentials have been abused for nefarious purposes, but can be used to notify on secrets shared on repos unintentionally made public.

## Requirements

- go v1.25.0 or newer
- Slack webhook token
- Github auth token

## Usage

You will need a GITHUB_TOKEN with permissions where the `Resource owner` is the organization you are testing. 

For this You can go and [create a new PAT](https://github.com/settings/personal-access-tokens/new) and select `Permissions / Organization Permission / Administration (Manage access to an organization.)` and set it to `Access: read-only`. That is the only permission you need.

Testing:

```
export GITHUB_TOKEN=$(cat <your-github-token-file>)
github-audit-alerter --org chainguard-dev --max-repos-cloned-per-user=3
```

## Installation (Linux VPS)

1. **Build the binary** for Linux:
   ```bash
   GOOS=linux GOARCH=amd64 go build -o github-audit-alerter main.go
   ```

2. **Upload** the binary (`github-audit-alerter`) and the `install.sh` script to your server.

3. **Run the installer**:
   ```bash
   sudo ./install.sh
   ```
   The script will prompt you for:
   - Your GitHub Organization name
   - Your GitHub Personal Access Token (PAT)
   - Your Slack Webhook URL (optional)

   It will automatically set up a systemd service to keep the alerter running.

## Creating a Slack webhook URL

- https://<your instance name>.slack.com/services/B0413S52DFB#message_attachments

## Creating a GitHub auth token

- Visit the [Fine-grained personal access tokens](https://github.com/settings/tokens?type=beta) page
- Click `Generate new token`
- Repository Access: `All repositories`
- Repository permissions: `Administration: Read-only`
- Organization permissions: `Administration: Read-only`, `Events: Read-only`