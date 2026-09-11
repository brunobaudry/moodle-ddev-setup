# Moodle cron in the DDEV dev environment

Moodle's scheduled and adhoc task runner is what makes asynchronous behaviour
work: course backup/restore, bulk enrolment, notifications, search indexing,
badge awarding. Without cron none of it ever completes, and a dev install is
useless for testing those paths.

`post_custom_scripts/setup_moodle_cron.sh` wires it up automatically. It runs
as part of the normal `./moodle_ddev.sh` flow (the post-custom-script loop) and
needs no manual step.

## What it installs

Two files, both inside the generated project's `.ddev/`:

| File | Purpose |
|---|---|
| `.ddev/web-build/Dockerfile.cron` | Guarantees the `cron` package exists in the web image. A separate `Dockerfile.<name>` because `web-build/Dockerfile` is owned by the locale layer (`sub/dockerfiles.sh`) — DDEV concatenates every `Dockerfile*` in that directory. |
| `.ddev/web-entrypoint.d/moodle-cron.sh` | Runs on **every** web-container start: writes `/etc/cron.d/moodle-cron` and starts the cron daemon. |

The resulting schedule, running every minute:

```
* * * * * <webuser> /usr/bin/php /var/www/html/moodle/admin/cli/cron.php >>/var/log/moodle-cron.log 2>&1
```

## Design notes

**Everything happens in the container, nothing on the host.** The daemon and
the crontab live in the web container. The host crontab is never touched.

**The daemon has to be started explicitly.** DDEV's webserver image ships cron
but supervisord never launches it, so a crontab entry alone sits there and
never fires. `service cron start` from the entrypoint is what makes it tick.

**`admin/cli` is not under the docroot.** On Moodle 5.1+ the docroot moves to
`./moodle/public`, but the CLI directory stays at the code root. The cron path
is therefore always `/var/www/html/moodle/admin/cli/cron.php`, derived from the
docroot argument rather than equal to it.

**The job runs as the web user, not root.** DDEV names the container user after
the host user, which is only knowable at runtime — hence `id -un` in the
entrypoint rather than a build-time `ARG`. Running cron.php as root would drop
root-owned files into `moodledata` and break the web server later.

**Startup hook, not image layer.** `web-entrypoint.d/*.sh` is DDEV's documented
startup hook, so the setup re-applies itself after `ddev restart`,
`ddev stop`/`start`, `ddev poweroff`, and image rebuilds.

## Cron will not run while an upgrade is pending

If the log says:

```
Moodle upgrade pending, cron execution suspended.
```

then cron is working but Moodle is deliberately skipping every task. This is
normal right after plugins are symlinked in by
`post_custom_scripts/install_plugins_symlinks.sh`. `moodle_ddev.sh` applies the
upgrade for you after the restart; if it failed, run it by hand:

```bash
ddev exec php ./moodle/admin/cli/upgrade.php --non-interactive --allow-unstable
ddev exec php ./moodle/admin/cli/upgrade.php --is-pending   # exit 2 = still pending
```

## Verifying

The setup script verifies itself and prints the result. To check by hand:

```bash
ddev exec pgrep -a cron                       # daemon alive
ddev exec cat /etc/cron.d/moodle-cron         # the schedule
ddev exec tail -f /var/log/moodle-cron.log    # watch tasks execute
ddev exec php moodle/admin/cli/cron.php       # run once, synchronously
```

Expect the log to gain output within 60 seconds of a start.

## Turning it off

Delete the two `.ddev/` files in the generated project and `ddev restart`, or
remove `setup_moodle_cron.sh` from `post_custom_scripts/` before creating the
project.
