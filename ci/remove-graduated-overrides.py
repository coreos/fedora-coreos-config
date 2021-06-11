#!/usr/bin/python3

import os
import sys
import json
import yaml
import subprocess

import dnf
import hawkey

ARCHES = ['s390x', 'x86_64', 'ppc64le', 'aarch64']

OVERRIDES_HEADER = """
# This lockfile should be used to pin to a package version (`type: pin`) or to
# fast-track packages ahead of Bodhi (`type: fast-track`). Fast-tracked
# packages will automatically be removed once they are in the stable repos.
#
# IMPORTANT: YAML comments *will not* be preserved. All `pin` overrides *must*
# include a URL in the `metadata.reason` key. Overrides of type `fast-track`
# *should* include a URL in the `metadata.reason` key, though it's acceptable to
# omit one for FCOS-specific packages (e.g. ignition, afterburn, etc...).
"""


def main():
    treefile = get_treefile()
    base = get_dnf_base(treefile)
    setup_repos(base, treefile)

    for fn in get_lockfiles():
        update_lockfile(base, fn)


def get_treefile():
    treefile = subprocess.check_output(['rpm-ostree', 'compose', 'tree',
                                        '--print-only', 'manifest.yaml'])
    return json.loads(treefile)


def get_dnf_base(treefile):
    base = dnf.Base()
    base.conf.reposdir = "."
    base.conf.releasever = treefile['releasever']
    base.read_all_repos()
    return base


def setup_repos(base, treefile):
    for repo in base.repos.values():
        repo.disable()

    print("Enabled repos:")
    for repo in treefile['repos']:
        base.repos[repo].enable()
        print(f"- {repo}")

    print("Downloading metadata")
    base.fill_sack(load_system_repo=False)


def get_lockfiles():
    lockfiles = ['manifest-lock.overrides.yaml']
    # TODO: for now, we only support the archless variant; supporting
    # arch-specific lockfiles will require making dnf fetch metadata not just
    # for the basearch on which we're running
    # lockfiles += [f'manifest-lock.overrides.{arch}.yaml' for arch in ARCHES]
    return lockfiles


def update_lockfile(base, fn):
    if not os.path.exists(fn):
        return

    with open(fn) as f:
        lockfile = yaml.load(f)
    if 'packages' not in lockfile:
        return

    new_packages = {}
    for name, lock in lockfile['packages'].items():
        if ('metadata' not in lock or
                lock['metadata'].get('type') != "fast-track"):
            new_packages[name] = lock
            continue

        if 'evra' in lock:
            nevra = f"{name}-{lock['evra']}"
        else:
            # it applies to all arches, so we can just check our arch (see
            # related TODO above)
            nevra = f"{name}-{lock['evr']}.{base.conf.basearch}"
        graduated = sack_has_nevra_greater_or_equal(base, nevra)
        if not graduated:
            new_packages[name] = lock
        else:
            print(f"{fn}: {nevra} has graduated")

    if lockfile['packages'] != new_packages:
        lockfile['packages'] = new_packages
        with open(fn, 'w') as f:
            f.write(OVERRIDES_HEADER.strip())
            f.write('\n\n')
            yaml.dump(lockfile, f)
    else:
        print(f"{fn}: no packages graduated")


def sack_has_nevra_greater_or_equal(base, nevra):
    nevra = hawkey.split_nevra(nevra)
    pkgs = base.sack.query().filterm(name=nevra.name).latest().run()

    if len(pkgs) == 0:
        # Odd... the only way I can imagine this happen is if we fast-track a
        # brand new package from Koji which hasn't hit the updates repo yet.
        # Corner-case, but let's be nice.
        print(f"couldn't find package {nevra.name}; assuming not graduated")
        return False

    nevra_latest = hawkey.split_nevra(str(pkgs[0]))
    return nevra_latest >= nevra


if __name__ == "__main__":
    sys.exit(main())
