# Production deployment

GitHub Actions builds and validates this Chirpy site, then deploys only the
generated `_site/` contents to `/srv/website/` on the production server.
The existing GitHub Pages workflow remains enabled as an independent fallback.

## GitHub environment secrets

Create a `production` environment and add these required environment secrets:

- `DEPLOY_HOST`: the droplet IPv4 address or DNS hostname
- `DEPLOY_USER`: the dedicated unprivileged account, normally `webdeploy`
- `DEPLOY_SSH_KEY`: the complete private deployment key, including its header
  and footer
- `DEPLOY_KNOWN_HOSTS`: trusted `known_hosts` output for the droplet and port

`DEPLOY_PORT` is optional and defaults to `22`; set it when SSH listens on a
different port.

## One-time server setup

Run as an existing sudo-capable administrator:

```bash
sudo apt-get update
sudo apt-get install --yes openssh-server rsync
id -u webdeploy >/dev/null 2>&1 || sudo useradd --create-home --shell /bin/bash webdeploy
sudo install -d -o webdeploy -g webdeploy -m 0755 /srv/website
sudo -u webdeploy install -d -m 0700 /home/webdeploy/.ssh
```

Generate a key on a trusted local computer (not on the droplet):

```bash
ssh-keygen -t ed25519 -a 100 -f ./github-actions-deploy -C "github-actions:bullet-ant/bullet-ant.github.io"
```

Leave the passphrase empty because the Actions runner cannot answer an
interactive prompt. Protect the private key as a credential. Put the single
line from `github-actions-deploy.pub` into the server file below, prefixed by
`restrict`:

```text
restrict ssh-ed25519 AAAA... github-actions:bullet-ant/bullet-ant.github.io
```

Then run on the server:

```bash
sudoedit /home/webdeploy/.ssh/authorized_keys
sudo chown webdeploy:webdeploy /home/webdeploy/.ssh/authorized_keys
sudo chmod 0600 /home/webdeploy/.ssh/authorized_keys
```

The `webdeploy` user must not receive sudo access. `restrict` disables SSH
forwarding, PTY allocation, and other features while still allowing rsync's
remote command.

## Pin the server host key

From the DigitalOcean web console, record the server's ED25519 fingerprint:

```bash
sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

On the trusted computer, collect the public host key (change the port if
needed), then verify its displayed fingerprint matches the console output:

```bash
ssh-keyscan -p 22 -H YOUR_DROPLET_IP > ./droplet_known_hosts
ssh-keygen -lf ./droplet_known_hosts
```

Use the full contents of `droplet_known_hosts` for `DEPLOY_KNOWN_HOSTS`. Do not
generate this value inside the workflow: verifying a freshly scanned key there
would not protect against a man-in-the-middle attack.

## Add secrets in GitHub

In the repository, go to **Settings > Environments > New environment**, create
`production`, optionally configure required reviewers and restrict deployment
branches to `main`, then add the environment secrets listed above.

They can alternatively be added with GitHub CLI:

```bash
gh secret set DEPLOY_HOST --env production
gh secret set DEPLOY_USER --env production
gh secret set DEPLOY_SSH_KEY --env production < ./github-actions-deploy
gh secret set DEPLOY_PORT --env production
gh secret set DEPLOY_KNOWN_HOSTS --env production < ./droplet_known_hosts
```

Delete the local private-key file after the secret is stored securely, or move
it to an encrypted credential store. Never commit either key file.

## Caddy

Bind-mount `/srv/website` read-only into the Caddy container and point Caddy's
site root at that mount. For example, the Compose service can contain:

```yaml
volumes:
  - /srv/website:/srv/website:ro
```

and the site block can contain:

```caddyfile
root * /srv/website
file_server
```

## Verification

1. Test authentication locally with `ssh -i ./github-actions-deploy webdeploy@YOUR_DROPLET_IP`.
2. Push a content change to `main` or manually run **Build and deploy static site**.
3. Confirm both the build and deploy jobs pass and the build artifact contains an `index.html`.
4. On the server, run `find /srv/website -maxdepth 2 -type f | head` and confirm generated HTML/assets exist, with no repository sources such as `Gemfile` or `_posts`.
5. Run `curl -fsS https://YOUR_DOMAIN/ >/dev/null` and check the updated page in a browser.
6. Create a temporary page, deploy it, remove it, deploy again, and confirm the corresponding server file disappears; this verifies `--delete`.
7. Re-run the same commit and confirm it succeeds without changing site content; this verifies idempotence.
8. Confirm the Caddy bind mount is read-only and that `webdeploy` has no sudo privileges.

The rsync command uses checksums for repeatable no-op deployments, `--delete` to
remove stale files, and delayed updates/deletions to reduce the window in which
Caddy could see a partially updated site. Production deployments are serialized
and are never cancelled while rsync is running.
