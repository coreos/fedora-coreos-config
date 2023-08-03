#!/usr/bin/python3
#
# Find all Butane configs in the doc tree, use the podman Butane container
# to run them through butane --strict, and fail on any errors.
#
# A Butane config looks like this:
#
# [source,yaml]
# ----
# variant:[...]
# ----
#
# If variant: is missing, we print a warning but continue, since there
# might be [source,yaml] documents that aren't Butane configs.

import argparse
import os
import re
import subprocess
import sys
import tempfile
import textwrap

ERR = '\x1b[1;31m'
WARN = '\x1b[1;33m'
RESET = '\x1b[0m'

container = os.getenv('BUTANE_CONTAINER', 'quay.io/coreos/butane:release')
matcher = re.compile(r'^\[source,\s*yaml\]\n----\n(.+?\n)----$',
        re.MULTILINE | re.DOTALL)

parser = argparse.ArgumentParser(description='Run validations on docs.')
parser.add_argument('-v', '--verbose', action='store_true',
                    help='log all detected Butane configs')
args = parser.parse_args()

def handle_error(e):
    raise e


# List of files required during verification
tmpfiles = {
    # tutorial-services.adoc
    os.path.join('public-ipv4.sh'): '#!/bin/bash\ntrue',
    os.path.join('issuegen-public-ipv4.service'): '[Unit]\nBefore=systemd-user-sessions.service\n[Install]\nWantedBy=multi-user.target',
    # authentication.adoc
    os.path.join('users', 'core', 'id_rsa.pub'): 'ssh-rsa AAAAB',
    os.path.join('users', 'jlebon', 'id_rsa.pub'): 'ssh-rsa AAAAB',
    os.path.join('users', 'jlebon', 'id_ed25519.pub'): 'ssh-ed25519 AAAAC',
    os.path.join('users', 'miabbott', 'id_rsa.pub'): 'ssh-rsa AAAAB',
    # tutorial-containers.adoc, tutorial-setup.adoc, tutorial-updates.adoc, tutorial-user-systemd-unit-on-boot.adoc
    os.path.join('ssh-key.pub'): 'ssh-rsa AAAAB',
}

ret = 0
with tempfile.TemporaryDirectory() as tmpdocs:
    for path, contents in tmpfiles.items():
        os.makedirs(os.path.join(tmpdocs, os.path.dirname(path)), exist_ok=True)
        with open(os.path.join(tmpdocs, path), 'w') as fh:
            fh.write(contents)
    for dirpath, dirnames, filenames in os.walk('.', onerror=handle_error):
        dirnames.sort()  # walk in sorted order
        for filename in sorted(filenames):
            filepath = os.path.join(dirpath, filename)
            if not filename.endswith('.adoc'):
                continue
            with open(filepath) as fh:
                filedata = fh.read()
            # Iterate over YAML source blocks
            for match in matcher.finditer(filedata):
                bu = match.group(1)
                buline = filedata.count('\n', 0, match.start(1)) + 1
                if not bu.startswith('variant:'):
                    print(f'{WARN}Ignoring non-Butane YAML at {filepath}:{buline}{RESET}')
                    continue
                if args.verbose:
                    print(f'Checking Butane config at {filepath}:{buline}')
                result = subprocess.run(
                    ['podman', 'run', '--rm', '-i', '-v=' + tmpdocs + ':/files-dir', container, '--strict', '--files-dir=/files-dir'],
                    universal_newlines=True,  # can be spelled "text" on >= 3.7
                    input=bu,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.PIPE)
                if result.returncode != 0:
                    formatted = textwrap.indent(result.stderr.strip(), '  ')
                    # Not necessary for ANSI terminals, but required by GitHub's
                    # log renderer
                    formatted = ERR + formatted.replace('\n', '\n' + ERR)
                    print(f'{ERR}Invalid Butane config at {filepath}:{buline}:\n{formatted}{RESET}')
                    ret = 1
sys.exit(ret)
