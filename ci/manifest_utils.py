#!/usr/bin/python

# This script provides utility functions for handling FCOS manifests and lockfiles.

import json
import os
import subprocess
import tempfile
import yaml


def get_treefile(manifest_path, deriving=False):
    """
    Parses an rpm-ostree manifest using 'rpm-ostree compose tree'.
    If deriving is True, it ensures that the treefile represents only the
    CoreOS bits and doesn't recurse into fedora-bootc.
    """
    with tempfile.NamedTemporaryFile(suffix='.json', mode='w') as tmp_manifest:
        json.dump({
            "variables": {
                "deriving": deriving
            },
            "include": manifest_path
        }, tmp_manifest)
        tmp_manifest.flush()
        data = subprocess.check_output(['rpm-ostree', 'compose', 'tree',
                                        '--print-only', tmp_manifest.name])
    return json.loads(data)


def get_locked_nevras(contextdir, arch, as_strings=False):
    """
    Gathers all locked packages from the manifest-lock files.
    The return format can be a dictionary of {pkgname: evr} or a list
    of strings in the format 'pkgname-evr'.
    For example:
    - as_strings=False: {'rpm-ostree': '2024.4-1.fc40'}
    - as_strings=True: ['rpm-ostree-2024.4-1.fc40']
    """
    lockfile_path = os.path.join(contextdir, f"manifest-lock.{arch}.json")
    overrides_path = os.path.join(contextdir, "manifest-lock.overrides.yaml")
    overrides_arch_path = os.path.join(contextdir, f"manifest-lock.overrides.{arch}.json")

    locks = {}
    for path in [lockfile_path, overrides_path, overrides_arch_path]:
        if os.path.exists(path):
            with open(path) as f:
                if path.endswith('.yaml'):
                    data = yaml.safe_load(f)
                else:
                    data = json.load(f)
                # this essentially re-implements the merge semantics of rpm-ostree
                locks.update({pkgname: v.get('evra') or v.get('evr')
                              for (pkgname, v) in data['packages'].items()})

    if as_strings:
        return [f'{k}-{v}' for (k, v) in locks.items()]
    return locks
