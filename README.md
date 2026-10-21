# Moodle DDEV Setup

A complete suite of Bash and Python scripts to automate the installation, configuration, testing, and management of [Moodle](https://moodle.org/) development environments using [DDEV](https://ddev.com/) on macOS and Linux (compatible with Windows WSL2).

Deploy a clean, fully-configured Moodle instance ready on `localhost` / `*.ddev.site` in under a minute without needing to manually configure web servers, database servers, or test runners.

---

## Key Features

- **Multi-Version Moodle Support**: Deploy any Moodle version from 4.1 (`401`) to 5.3+ (`503`), using standard version codes (e.g., `405`, `502`) or semantic versions (e.g., `4.5.1`, `5.1.0`).
- **Moodle 5.1+ Web Root Handling**: Automatically configures DDEV docroot for Moodle 5.1+ (`moodle/public`) and earlier versions (`moodle/`).
- **PHP Version Matrix**: Supports PHP 7.4 through 8.4 with automated compatibility validation against Moodle versions.
- **Database Engine Flexibility**: Choose MariaDB, MySQL, or PostgreSQL (`mariadb`, `mysqli`/`mysql`, `pgsql`/`postgres`/`postgresql`). Automatically applies the minimum required database version or accepts custom version tags (e.g., `mariadb:10.11`, `mysql:8.0`, `postgres:16`).
- **Flexible Source Modes**: 
  - Install via Composer (default behaviour when only passing the Moodle version number)
  - clone any Git repository and branch (e.g. `--repo git@github.com:user/moodle.git@MDL-12345-main`).
- **Automated Test Runners (PHPUnit & Behat)**:
  - Generates `en_AU.UTF-8` locale in `.ddev/web-build/Dockerfile` required by Moodle test runners.
  - Automatically configures `$CFG->phpunit_*` and `$CFG->behat_*` (including Selenium Chrome and Firefox browser profiles) in `config.php`.
  - Automatically runs PHPUnit and Behat CLI environment initializations (`admin/tool/phpunit/cli/init.php` and `admin/tool/behat/cli/init.php`).
- **In-Container Moodle Cron Service**:
  - Automatically provisions and runs cron within the web container (`/etc/cron.d/moodle-cron`) every minute under the container web user.
  - Automatically logs task executions to `/var/log/moodle-cron.log`.
- **MoMoPDA AI Agent Support**:
  - Automatically integrates the [MoMoPDA](https://github.com/wilenius/momopda) (Modular Moodle Plugin Development Assistant) prompt library into generated projects.
  - Creates orchestrator and rule files for all major AI assistants: Claude Code (`CLAUDE.md`), Cursor (`.cursorrules`, `.cursor/rules/moodle-momopda.mdc`), Windsurf (`.windsurfrules`), GitHub Copilot (`.github/copilot-instructions.md`), JetBrains Junie (`.junie/guidelines.md`), Gemini (`GEMINI.md`), and general agents (`AGENTS.md`, `.prompts/`).
  - Sets `MOODLE_DIR` and `MOMOPDA_DIR` in `.env`, `.env.ai`, `.ddev/docker-compose.momopda.yaml`, and container profile scripts for Moodle Plugin CI validation.
- **Plugin Symlinking & Mutagen Bind-Mounting**:
  - Discovers local Moodle plugin git repositories from `MOODLE_PLUGINS_REPO` and symlinks them into Moodle. So that you can run multiple instances but keeping your plugins git synched.
  - Generates `.ddev/docker-compose.mounts.yaml` bind-mounts and updates `.ddev/mutagen/mutagen.yml` ignore rules to ensure seamless bidirectional synchronization without broken container symlinks.
- **Pre-set Admin Configuration via CSV**: Pass a CSV table (`--admincfg-csv`) with `NAME,VALUE` or `NAME,VALUE,COMPONENT` pairs to pre-configure Moodle settings (e.g. debug level, cache settings, language lists).
- **Language Packs & Test Courses**:
  - Automatically installs language packs from `MOODLE_LANG_PACKS_DIR`.
  - Restores default backup test courses (`.mbz`).
- **Pre- & Post-Install Lifecycle Hooks**: Extensible hook system (`pre_custom_scripts/` and `post_custom_scripts/`) receiving 6 contextual parameters.
- **IDE Auto-Detection & Launch**: Detects installed IDEs (PhpStorm, VS Code, Cursor, Windsurf, Sublime Text, Eclipse, etc.) and opens the generated project automatically with `--ide`.
- **Batch Management**: Batch-install whole matrices of Moodle, PHP, and DB combinations with `run_all.sh`, batch-inspect with `ddev_describe_all.sh`, and batch-delete with `delete_all.sh`.
- **Safe Rollback & Clean Deletion**: Automatically cleans up containers and directories if installation fails. `moodle_ddev_delete.sh` and `--force` cleanly purge Docker containers and database volumes.

---

## Scripts Overview

| Script | Description |
|---|---|
| `moodle_ddev.sh` | Main installer script (interactive or CLI flags) to create a fully configured Moodle instance. |
| `moodle_ddev_delete.sh` | Cleanly removes a single Moodle instance, its DDEV containers, and database Docker volume. |
| `run_all.sh` | Batch installer to generate all compatible combinations of Moodle, PHP, and database engines.(this is a lot of instances and make sure your docker setup can handle it) see [Docker Subnet / Address Pool Limit](#docker-subnet--address-pool-limit)|
| `delete_all.sh` | Batch cleaner to delete all DDEV Moodle instances within a target folder. |
| `ddev_describe_all.sh` | Scans a folder and displays status, URLs, database ports, and Mailpit links for all projects. |
| `sub/list_available_ide.sh` | Detects and lists available IDEs on the host machine. |

---

## Prerequisites

1. **[DDEV](https://ddev.com/) v1.21+**
2. **[Docker](https://ddev.com/get-started/)** (Docker Desktop, OrbStack, or Colima)
3. **[Composer](https://getcomposer.org/)**
4. **[jq](https://jqlang.org/)** (JSON processor for DDEV metadata)
   - macOS: `brew install jq`
   - Linux: `sudo apt-get install jq` / `sudo dnf install jq`
   - Windows
      - Use winget to install jq with `winget install jqlang.jq`.
      - Use scoop to install jq with `scoop install jq`.
      - Use Chocolatey NuGet to install jq with `choco install jq`.

5. **Python 3 with PyYAML** (used for plugin parsing and Mutagen mount generation):
   ```bash
   python3 -m venv .venv
   source .venv/bin/activate
   pip install pyyaml
   ```

Make sure scripts are executable:
```bash
chmod +x moodle_ddev.sh moodle_ddev_delete.sh run_all.sh delete_all.sh sub/*.sh post_custom_scripts/*.sh
```

---

## Environment Variables (Optional)

Configure these in your shell profile (e.g., `~/.zshrc` or `~/.bashrc`):

| Variable | Description |
|---|---|
| `MOODLE_DDEVS_DIR` | Default parent directory where all Moodle DDEV instances will be created (defaults to current directory `.`). |
| `MOODLE_PLUGINS_REPO` | Directory containing your local Moodle plugin git repositories (named `moodle-TYPE_name`). |
| `MOODLE_LANG_PACKS_DIR` | Directory containing Moodle language pack `.zip` files to auto-install into `moodledata/lang/`. |
| `MOMOPDA_REPO` | Custom git URL for the MoMoPDA AI prompt repository (defaults to `https://github.com/wilenius/momopda.git`). |

---

## Usage: `moodle_ddev.sh` (Main Script)

### Syntax

#### Interactive Mode

```bash
./moodle_ddev.sh
```

#### Passing arguments

```bash
./moodle_ddev.sh --php <php_version> --version <moodle_version> [OPTIONS]
```

### Options

| Option | Description |
|---|---|
| `--version <version>` | Moodle version (e.g. `401`..`503` or `4.1.0`..`5.3.0`). Defaults to `502`. |
| `--php <version>` | PHP version (`7.4`, `8.0`, `8.1`, `8.2`, `8.3`, `8.4`). Defaults to `8.4`. |
| `--db <type[:version]>` | Database type: `mariadb`, `mysql`/`mysqli`, `pgsql`/`postgres`/`postgresql`. Optional version suffix (e.g. `mariadb:10.11`, `mysql:8.0`, `postgres:16`). Defaults to `mariadb`. |
| `--repo <composer\|URL[@branch]>` | Source to install from: `composer` (default) or a Git repository with optional `@branch`. |
| `--root <folder>` | Parent directory for the installation. Defaults to `$MOODLE_DDEVS_DIR` or current directory. |
| `--admincfg-csv <path>` | Path to a CSV file with `NAME,VALUE` or `NAME,VALUE,COMPONENT` pairs to pre-configure Moodle admin settings. |
| `--ide [IDE_NAME]` | Open project in specified IDE (e.g. `phpstorm`, `code`, `cursor`) or prompt from available IDEs upon completion. |
| `--momopda [REPO_URL]` | Specify a custom MoMoPDA AI prompt repository or fork. |
| `--no-momopda` | Disable MoMoPDA AI agent configuration. |
| `--force` | Cleanly purge existing DDEV project (containers, database volume, and directory) before recreating. |

### Projects naming

To generate meaningfull and secured folder names,
the engine will normallize the project name with the following format and principle :
`<composer|repouser>-<nomalized-version>-<php-version>-<db-engine>-<dbversion>`

- removing spaces
- removing special chars
- lowercase
- db version even if default used

### Examples

**Default installation (Interactive prompt):**
```bash
./moodle_ddev.sh
```

**Moodle 5.0 with PHP 8.4 and MariaDB:**
```bash
./moodle_ddev.sh --php 8.4 --version 500
# composer-500-84-mariadb-106
```

**Moodle 5.2 with PostgreSQL 16, custom admin settings, and custom target folder:**
```bash
./moodle_ddev.sh --php 8.4 --version 502 --db postgres:16 --root ~/dev/moodles --admincfg-csv ./admin_cfg.csv
# composer-502-84-postgres-16
```

**Install from a specific Git repository and feature branch:**
```bash
./moodle_ddev.sh --php 8.4 --version 5.3 --db mariadb --repo git@github.com:janedoe/moodle.git@MOODLE_503_STABLE
# janedoe-503-84-mariadb-114
```

---

## Admin Configuration via CSV (`--admincfg-csv`)

Pre-set any Moodle core or plugin admin configuration automatically during installation using a CSV file.

Example `admin_cfg.csv`:
```csv
NAME,VALUE,COMPONENT
debug,30719,
debugdisplay,1,
cachejs,0,
langlist,"de,fr,en",
theme,boost,
```

- `NAME`: The configuration setting key (as used in `$CFG-><name>`).
- `VALUE`: The value to set.
- `COMPONENT`: (Optional) Plugin component name if setting a plugin configuration.

---

## Project Structure

Projects are named using the Moodle version, PHP version, and database engine:

### Moodle 4.x and 5.0 Structure:
```
moodle405-php8.3-mariadb/
├── moodle/               # Moodle core code
├── moodledata/           # Moodle data directory
├── momopda/              # MoMoPDA prompt library
├── .prompts/ -> momopda/.prompts/
├── AGENTS.md -> momopda/AGENTS.md
├── CLAUDE.md
├── .cursorrules
├── .cursor/rules/moodle-momopda.mdc
├── .windsurfrules
├── .github/copilot-instructions.md
├── .junie/guidelines.md
├── GEMINI.md
├── .env / .env.ai
└── .ddev/
    ├── config.yaml
    ├── docker-compose.momopda.yaml
    ├── docker-compose.mounts.yaml
    ├── web-build/
    │   ├── Dockerfile
    │   └── Dockerfile.cron
    └── web-entrypoint.d/
        ├── moodle-cron.sh
        └── moodle-ai-env.sh
```

### Moodle 5.1+ Structure (`public/` directory):
```
moodle502-php8.4-mariadb/
├── moodle/
│   ├── ...
│   └── public/           # Document root for Moodle 5.1+
├── moodledata/
├── momopda/
...
```

---

## MoMoPDA AI Agent Support

All generated projects are pre-wired for seamless integration with AI coding assistants using the [MoMoPDA](https://github.com/wilenius/momopda) prompt library.

- **Orchestration & Rules**: Projects include linked instruction files for Claude Code (`CLAUDE.md`), Cursor (`.cursorrules`, `.cursor/rules/moodle-momopda.mdc`), Windsurf (`.windsurfrules`), GitHub Copilot (`.github/copilot-instructions.md`), JetBrains Junie (`.junie/guidelines.md`), Gemini (`GEMINI.md`), and general agentic frameworks (`AGENTS.md`, `.prompts/`).
- **Environment Exports**: Automatically configures `MOODLE_DIR` (pointing to Moodle core) and `MOMOPDA_DIR` in `.env`, `.env.ai`, and DDEV web containers for plugin CI validation tools (PHP Lint, CodeChecker, PHPUnit, Behat).
- **Control**: Use `--momopda [REPO_URL]` to point to a custom fork, or `--no-momopda` to omit AI agent files.

---

## Plugin Symlinking & Bind Mounts

If `MOODLE_PLUGINS_REPO` is set, `post_custom_scripts/install_plugins_symlinks.sh` automatically scans the plugin directory for repositories matching `moodle-<type>_<name>` (e.g., `moodle-mod_questionnaire`, `moodle-block_activity_results`, `moodle-qtype_stack`).

1. **Host Symlinks**: Creates symlinks in the Moodle tree (e.g. `moodle/mod/questionnaire` -> local git repo) so host IDEs can index and edit plugin code.
2. **Container Mounts**: Generates `.ddev/docker-compose.mounts.yaml` to mount plugins into `/var/www/html/moodle/...`.
3. **Mutagen Synchronization**: Automatically updates Mutagen ignore rules in `.ddev/mutagen/mutagen.yml` so Docker mounts function cleanly without broken container symlinks.

---

## In-Container Moodle Cron

Moodle cron is configured automatically by `post_custom_scripts/setup_moodle_cron.sh`.

- Runs every minute as the container's web user:
  ```
  * * * * * <webuser> /usr/bin/php /var/www/html/moodle/admin/cli/cron.php >>/var/log/moodle-cron.log 2>&1
  ```
- To monitor cron tasks:
  ```bash
  ddev exec tail -f /var/log/moodle-cron.log
  ```
- To run cron manually:
  ```bash
  ddev exec php moodle/admin/cli/cron.php
  ```

---

## Custom Lifecycle Hooks

You can add custom automation scripts before or after Moodle installation by placing executable `.sh` scripts in `pre_custom_scripts/` or `post_custom_scripts/`.

Every hook script receives 6 positional arguments:
1. `$1`: Project root directory (host path)
2. `$2`: Moodle public docroot (`./moodle` or `./moodle/public`)
3. `$3`: DDEV describe JSON data (`ddev describe -j`)
4. `$4`: Moodle version (e.g. `502`)
5. `$5`: PHP version (e.g. `8.4`)
6. `$6`: Database type (e.g. `mariadb:10.11`)

---

## Batch Scripts

### `run_all.sh` (Batch Installer)

Install multiple Moodle environments in batch. Automatically skips incompatible Moodle/PHP combinations.

```bash
./run_all.sh [OPTIONS]
```

**Options:**
- `--moodle <"405 500 501 502">`: Space-separated list of Moodle versions.
- `--php <"8.2 8.3 8.4">`: Space-separated list of PHP versions.
- `--db <"mariadb pgsql">`: Space-separated list of DB types.
- `--moodle-csv <"405,500,501,502">`: Comma-separated list of Moodle versions.
- `--php-csv <"8.2,8.3,8.4">`: Comma-separated list of PHP versions.
- `--db-csv <"mariadb,pgsql">`: Comma-separated list of DB types.
- `--admincfg-csv <path>`: Admin configuration CSV file.
- `--root <folder>`: Target parent folder.
- `--force`: Overwrite existing folders and databases.

### `ddev_describe_all.sh` (Batch Status Inspector)

Displays the URL, database port, Mailpit web interface, and container status for all DDEV projects in a directory:

```bash
./ddev_describe_all.sh [--root <folder>]
```

Example output:
```
===== ALL DDEVs in /Users/dev/moodles =====
moodle501-php8-4-mariadb (💚)
    Root ←          /Users/dev/moodles/moodle501-php8.4-mariadb
    Web ←           https://moodle501-php8-4-mariadb.ddev.site
    Database ←      127.0.0.1:32834  
    Mailpit ←       https://moodle501-php8-4-mariadb.ddev.site:8026  
--------
moodle502-php8-4-pgsql_16 (🔴)
    Root ←          /Users/dev/moodles/moodle502-php8-4-pgsql_16
    Web ←           https://moodle502-php8-4-pgsql-16.ddev.site
    Database ←      127.0.0.1:32789  
    Mailpit ←       https://moodle502-php8-4-pgsql-16.ddev.site:8026  
```

🔴 = ddev not started
💚 = running in docker

### `moodle_ddev_delete.sh` (Single Delete)

Cleanly delete an instance along with its database volume and project directory:

```bash
./moodle_ddev_delete.sh <path_to_project_folder> [--silent]
```

### `delete_all.sh` (Batch Delete)

Cleanly delete all DDEV Moodle instances found inside a directory:

```bash
./delete_all.sh [--root <folder>]
```

---

## Troubleshooting

### `Moodle CLI installation failed` / `Database tables already present`
DDEV stores databases in named Docker volumes. If a project folder was deleted without running `ddev delete`, the volume persists. Use `--force` with `moodle_ddev.sh` or delete manually:
```bash
ddev delete --omit-snapshot -y <project_name>
```

### `Required locale 'en_AU.UTF-8' is not installed`
Moodle test runners hardcode `en_AU.UTF-8` for date/time formatting. `sub/dockerfiles.sh` automatically adds this locale to `.ddev/web-build/Dockerfile`. To repair an existing container:
```bash
ddev exec -s web sudo bash -c "echo 'en_AU.UTF-8 UTF-8' >> /etc/locale.gen && locale-gen"
ddev restart
```

### Docker Subnet / Address Pool Limit
When running numerous concurrent DDEV instances, Docker may exhaust IP subnets (`all predefined address pools have been fully subnetted`). Configure larger address pools in `/etc/docker/daemon.json` (or Docker Desktop -> Docker Engine):
```json
{
  "default-address-pools": [
    { "base": "172.80.0.0/16", "size": 24 },
    { "base": "172.90.0.0/16", "size": 24 }
  ]
}
```
Restart Docker after saving.

### `Moodle upgrade pending, cron execution suspended`
If plugins are symlinked into Moodle, cron suspends execution until the upgrade completes. Run:
```bash
ddev exec php ./moodle/admin/cli/upgrade.php --non-interactive --allow-unstable
```