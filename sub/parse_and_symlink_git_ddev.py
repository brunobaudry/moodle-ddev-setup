import argparse
import os
import re
import sys
import yaml
from pathlib import Path

parser = argparse.ArgumentParser(description='Parse and symlink Moodle plugin git repos to DDEV target')
parser.add_argument('-r','--gitRoot', required=True, help='Path to git repo directory containing Moodle plugin repos')
parser.add_argument('-t','--ddevTarget', required=True, help='Path to ddev target (Moodle root directory)')
parser.add_argument('--dry-run', action='store_true', help='Show what would be done without making changes')
parser.add_argument('--moodle-version', type=float, default=5.1, help='Moodle version (default: 5.1). Versions >= 5.1 use public/ folder')

# Moodle plugin type to directory mapping
PLUGIN_TYPE_MAP = {
    'qtype': 'question/type',
    'qbehaviour': 'question/behaviour',
    'qbank': 'question/bank',
    'block': 'blocks',
    'tool': 'admin/tool',
    'tiny': 'lib/editor/tiny',
    'atto': 'lib/editor/atto',
    'editor':'lib/editor',
    'codemirror': 'lib/editor/codemirror',
    'format': 'course/format',
    'checklist': 'mod',  # special case
    'mod': 'mod',
    'theme': 'theme',
    'local': 'local',
    'auth': 'auth',
    'enrol': 'enrol',
    'filter': 'filter',
    'report': 'report',
    'repository': 'repository',
    'quiz': 'mod/quiz/report',
    'assignment': 'mod/assignment/type',
    'assignsubmission': 'mod/assign/submission',
    'assignfeedback': 'mod/assign/feedback',
    'webservice':'webservice'
}

def parse_plugin_name(repo_name):
    """Parse Moodle plugin repo name (e.g., moodle-mod_example.git or moodle-mod_example)"""
    match = re.match(r"moodle-([^_]+)_(.+?)(?:\.git)?$", repo_name)
    if match:
        plugin_type = match.group(1)
        plugin_name = match.group(2)
        return plugin_type, plugin_name
    return None, None

def get_plugin_directory(plugin_type, plugin_name, moodle_version=5.1):
    """Get the target directory path for a plugin"""
    if plugin_type in PLUGIN_TYPE_MAP:
        base_dir = PLUGIN_TYPE_MAP[plugin_type]
        plugin_path = os.path.join(base_dir, plugin_name)

        # Moodle 5.1+ uses public/ folder for web-accessible files
        if moodle_version >= 5.1 or moodle_version >= 501 :
            return os.path.join('public', plugin_path)
        return plugin_path
    return None

def create_symlink(source, target, dry_run=False):
    """Create a symlink from source to target"""
    if dry_run:
        print(f"[DRY RUN] Would create symlink: {target} -> {source}")
        return True

    # Create parent directory if it doesn't exist
    os.makedirs(os.path.dirname(target), exist_ok=True)

    # Remove existing symlink or directory if it exists
    if os.path.islink(target):
        os.unlink(target)
        print(f"Removed existing symlink: {target}")
    elif os.path.exists(target):
        print(f"WARNING: Target exists and is not a symlink: {target}")
        return False

    # Create symlink
    os.symlink(source, target)
    print(f"Created symlink: {target} -> {source}")
    return True

def create_docker_compose_mounts(plugins, ddev_target, dry_run=False):
    """Create docker-compose.mounts.yaml file with volume mounts for plugins"""
    ddev_dir = os.path.join(ddev_target, '.ddev')
    compose_file = os.path.join(ddev_dir, 'docker-compose.mounts.yaml')

    # Build mounts configuration
    mounts = []
    for source, target_rel in plugins:
        # mount = {
        #     'type': 'bind',
        #     'source': source,
        #     'target': f'/var/www/html/{target_rel}'
        # }
        mount = f'{source}:/var/www/html/moodle/{target_rel}'
        mounts.append(mount)

    compose_config = {
        'services': {
            'web': {
                'volumes': mounts
            }
        }
    }

    if dry_run:
        print(f"\n[DRY RUN] Would create {compose_file} with content:")
        print(yaml.dump(compose_config, default_flow_style=False, sort_keys=False))
        return

    # Ensure .ddev directory exists
    os.makedirs(ddev_dir, exist_ok=True)

    # Write docker-compose file
    with open(compose_file, 'w') as f:
        yaml.dump(compose_config, f, default_flow_style=False, sort_keys=False)

    print(f"\nCreated docker-compose mounts file: {compose_file}")
    print(f"Total mounts configured: {len(mounts)}")

def main():
    if len(sys.argv) < 2:
        parser.print_help()
        sys.exit(1)

    args = parser.parse_args()

    git_root = args.gitRoot
    ddev_target = args.ddevTarget
    dry_run = args.dry_run
    moodle_version = args.moodle_version

    # Validate paths
    if not os.path.exists(git_root):
        print(f"ERROR: Git root directory does not exist: {git_root}")
        sys.exit(1)

    if not os.path.exists(ddev_target) and not dry_run:
        print(f"ERROR: DDEV target directory does not exist: {ddev_target}")
        sys.exit(1)

    print(f"Git root: {git_root}")
    print(f"DDEV target: {ddev_target}")
    print(f"Moodle version: {moodle_version}")
    print(f"Dry run: {dry_run}\n")

    # Parse git repos
    plugins = []
    repos = os.listdir(git_root)

    for repo in repos:
        repo_path = os.path.join(git_root, repo)

        # Skip if not a directory
        if not os.path.isdir(repo_path):
            continue

        # Parse plugin name
        plugin_type, plugin_name = parse_plugin_name(repo)

        if not plugin_type or not plugin_name:
            print(f"Skipping {repo}: Not a valid Moodle plugin repo name")
            continue

        # Get target directory
        target_rel = get_plugin_directory(plugin_type, plugin_name, moodle_version)

        if not target_rel:
            print(f"WARNING: Unknown plugin type '{plugin_type}' for {repo}")
            continue

        target_path = os.path.join(ddev_target,'moodle', target_rel)

        # Create symlink
        if create_symlink(repo_path, target_path, dry_run):
            plugins.append((repo_path, target_rel))

        print(f"  Type: {plugin_type}, Name: {plugin_name}")
        print(f"  Target: {target_rel}\n")

    # Create docker-compose mounts file
    if plugins:
        create_docker_compose_mounts(plugins, ddev_target, dry_run)
        print(f"\nProcessed {len(plugins)} plugins successfully")
    else:
        print("No valid Moodle plugin repos found")


if __name__ == "__main__":
    main()
