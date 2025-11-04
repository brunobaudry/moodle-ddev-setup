# moodle-ddev-setup
bash script to install moodle instances using ddev for development. (without the need to setup a local web server apache or nginx neither the DB engine)
- choose your php version
- choose your moodle version
- choose your DB (mariadb|mysql|postgres)
- choose the directory where you want it installed.
- "ddev start" "ddev stop" "ddev describe" etc...
- Start developping and testing happily

## Install directories
The installs will create the projects main folder with the moodle, the php and the db versions in the name.

```
├── moodle4.3.2-php8.2-mariadb
│   ├── moodle
│   └── moodledata
├── moodle405-php8.4-postgres
│   ├── moodle
│   └── moodledata

## 5.1 structure
├── moodle501-php8.4-mysql
│   ├── moodle
│   |    ├── ...
│   |    └── public
│   └── moodledata
```

## Setup

### Executable
make sure the script is executable 
```bash
chmod +x ./moodle_ddev.sh
```

### Run
The default database is **mariadb**

#### interactive mode
```bash
./moodle_ddev.sh
```
Then you'll be prompted to enter the php version and the moodle version.

**php** allowed versions are 8.2, 8.3 and 8.4 so far
**Moolde** allowed from 4.1 onwards. You can pass it in the "stable" format (expl 401) or with the full version 4.1.0 format.

### passing all the params 
```bash
./moodle_ddev.sh --php <version> --version <moodle_version> [--db <mariadb|mysql|postgres>] [--force] [--root <folder>]
```
Expl :
```bash
./moodle_ddev.sh --php 8.4 --version 501
```

```bash
./moodle_ddev.sh --php 8.4 --version 501 --db postgres --root ~/dev/moodles
```

### --force
pass this when you want to overrite an install.


## Prerequisite

### Platforms 
Runs on linux or Macos. 
(it should work on windows with small adjustments).

### Tools

#### DDEV v1.21+
[ddev](https://ddev.com/) _Container superpowers with zero required Docker skills: environments in minutes, multiple concurrent projects, and less time to deployment._

#### DOCKER
When installing ddev you would also need a docker install follow the get started https://ddev.com/get-started/

#### COMPOSER
https://getcomposer.org/

#### JQ 
MAC:
https://formulae.brew.sh/formula/jq
LINUX:
https://jqlang.org/

## Todo
- add plugins
- add behat and phpunit setup
- add mounts
