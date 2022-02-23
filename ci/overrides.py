#!/usr/bin/python3

import argparse
import functools
import os
import sys
import json
import requests
from urllib.parse import urlparse
import yaml
import subprocess

import bodhi.client
import dnf
import hawkey
import koji

KOJI_URL = 'https://koji.fedoraproject.org/kojihub'
ARCHES = ['s390x', 'x86_64', 'ppc64le', 'aarch64']
TRIVIAL_FAST_TRACKS = [
    # Packages that don't need a reason URL when fast-tracking
    'console-login-helper-messages',
    'ignition',
    'ostree',
    'rpm-ostree',
    'rust-afterburn',
    'rust-bootupd',
    'rust-coreos-installer',
    'rust-fedora-coreos-pinger',
    'rust-ignition-config',
    'rust-zincati',
]
BUILDS_JSON_URL_TEMPLATE = 'https://builds.coreos.fedoraproject.org/prod/streams/{stream}/builds/builds.json'
GENERATED_LOCKFILE_URL_TEMPLATE = 'https://builds.coreos.fedoraproject.org/prod/streams/{stream}/builds/{version}/{arch}/manifest-lock.generated.{arch}.json'

OVERRIDES_HEADER = """
# This lockfile should be used to pin to a package version (`type: pin`) or to
# fast-track packages ahead of Bodhi (`type: fast-track`). Fast-tracked
# packages will automatically be removed once they are in the stable repos.
#
# IMPORTANT: YAML comments *will not* be preserved. All `pin` overrides *must*
# include a URL in the `metadata.reason` key. Overrides of type `fast-track`
# *should* include a Bodhi update URL in the `metadata.bodhi` key and a URL
# in the `metadata.reason` key, though it's acceptable to omit a `reason`
# for FCOS-specific packages (ignition, afterburn, etc.).
"""

basedir = os.path.normpath(os.path.join(os.path.dirname(sys.argv[0]), '..'))


def main():
    parser = argparse.ArgumentParser(description='Manage overrides.')
    # "dest" to work around https://bugs.python.org/issue29298
    subcommands = parser.add_subparsers(title='subcommands', required=True,
            dest='command')

    fast_track = subcommands.add_parser('fast-track',
            description='Fast-track Bodhi updates.')
    fast_track.add_argument('update', nargs='+',
            help='ID or URL of Bodhi update to fast-track')
    fast_track.add_argument('-r', '--reason',
            help='URL explaining the reason for the fast-track')
    fast_track.add_argument('--ignore-dist-mismatch', action='store_true',
            help='ignore mismatched Fedora major version')
    fast_track.set_defaults(func=do_fast_track)

    pin = subcommands.add_parser('pin', description='Pin source RPMs.')
    pin.add_argument('nvr', nargs='+',
            help='NVR of SRPM to pin')
    pin.add_argument('-r', '--reason', required=True,
            help='URL explaining the reason for the pin')
    pin.add_argument('--ignore-dist-mismatch', action='store_true',
            help='ignore mismatched Fedora major version')
    pin.set_defaults(func=do_pin)

    srpms = subcommands.add_parser('srpms',
            description='Name the source RPMs for a Bodhi update.')
    srpms.add_argument('update', help='ID or URL of Bodhi update')
    srpms.set_defaults(func=do_srpms)

    graduate = subcommands.add_parser('graduate',
            description='Remove graduated overrides.')
    graduate.set_defaults(func=do_graduate)

    args = parser.parse_args()
    args.func(args)


def do_fast_track(args):
    overrides = {}
    dist = get_expected_dist_tag()
    if args.reason:
        check_url(args.reason)
    for update in args.update:
        update = get_bodhi_update(update)
        source_nvrs = get_source_nvrs(update)
        for source_nvr in source_nvrs:
            source_name = '-'.join(source_nvr.split('-')[:-2])
            if not args.reason and source_name not in TRIVIAL_FAST_TRACKS:
                raise Exception(f'No reason URL specified and source package {source_name} not in {TRIVIAL_FAST_TRACKS}')
        for n, info in get_binary_packages(source_nvrs).items():
            if not args.ignore_dist_mismatch:
                check_dist_tag(n, info, dist)
            info['metadata'] = dict(
                type='fast-track',
                bodhi=update['url'],
            )
            if args.reason:
                info['metadata']['reason'] = args.reason
            overrides[n] = info
    if not overrides:
        raise Exception('specified updates contain no binary packages listed in lockfiles')
    for lockfile_path in get_lockfiles():
        merge_overrides(lockfile_path, overrides)


def do_pin(args):
    overrides = {}
    dist = get_expected_dist_tag()
    check_url(args.reason)
    for n, info in get_binary_packages(args.nvr).items():
        if not args.ignore_dist_mismatch:
            check_dist_tag(n, info, dist)
        info['metadata'] = dict(
            type='pin',
            reason=args.reason,
        )
        overrides[n] = info
    if not overrides:
        raise Exception('specified source packages produce no binary packages listed in lockfiles')
    for lockfile_path in get_lockfiles():
        merge_overrides(lockfile_path, overrides)


def do_srpms(args):
    for nvr in get_source_nvrs(get_bodhi_update(args.update)):
        print(nvr)


def do_graduate(_args):
    treefile = get_treefile()
    base = get_dnf_base(treefile)
    setup_repos(base, treefile)

    for fn in get_lockfiles():
        graduate_lockfile(base, fn)


def get_treefile():
    treefile = subprocess.check_output(['rpm-ostree', 'compose', 'tree',
                                        '--print-only',
                                        os.path.join(basedir, 'manifest.yaml')])
    return json.loads(treefile)


def get_dnf_base(treefile):
    base = dnf.Base()
    base.conf.reposdir = basedir
    base.conf.releasever = treefile['releasever']
    base.read_all_repos()
    return base


@functools.cache
def get_stream():
    '''Get the current stream name.'''
    with open(os.path.join(basedir, 'manifest.yaml')) as fh:
        manifest = yaml.safe_load(fh)
    return manifest['variables']['stream']


@functools.cache
def get_build_list():
    '''Return list of official builds fetched from builds.json for the current
    stream.'''
    stream_url = BUILDS_JSON_URL_TEMPLATE.format(stream=get_stream())
    resp = requests.get(stream_url)
    resp.raise_for_status()
    return resp.json()['builds']


@functools.cache
def get_manifest_packages(arch):
    '''Return manifest lock package map for the specified arch.'''

    # If this branch has any lockfiles in it, return the lockfile for the
    # specified arch, or an empty dict if missing.
    lockfile_path = lambda arch: os.path.join(basedir, f'manifest-lock.{arch}.json')
    if any(os.path.exists(lockfile_path(a)) for a in ARCHES):
        try:
            with open(lockfile_path(arch)) as f:
                manifest = json.load(f)
            return manifest['packages']
        except FileNotFoundError:
            return {}

    # Otherwise we're on a mechanical branch.  Pull the generated lockfile
    # from the most recent successful CI build, or return an empty dict if
    # we've never built for this arch.  Thus, different arches may return
    # lockfiles from different builds if a recent build failed on some arches.
    versions = [b['id'] for b in get_build_list() if arch in b['arches']]
    if not versions:
        return {}
    print(f'Reading generated lockfile from build {versions[0]} on {arch}')
    lockfile_url = GENERATED_LOCKFILE_URL_TEMPLATE.format(stream=get_stream(),
            version=versions[0], arch=arch)
    resp = requests.get(lockfile_url)
    resp.raise_for_status()
    return resp.json()['packages']


def get_bodhi_update(id_or_url):
    '''Query Bodhi for the specified update ID or URL and return an info
    dict.'''
    # discard rest of URL if any
    id = id_or_url.split('/')[-1]
    client = bodhi.client.bindings.BodhiClient()
    result = client.query(updateid=id)
    if not result.updates:
        raise Exception(f'Update {id} not found')
    return result.updates[0]


def get_source_nvrs(update):
    '''Return list of source NVRs from the update info dict.'''
    return [b['nvr'] for b in update.builds]


def get_binary_packages(source_nvrs):
    '''Return name => info dict for the specified source NVRs.  The info
    dict contains "evr" for archful packages and "evra" for noarch ones.
    A binary package is included if it is in the manifest lockfiles.'''
    binpkgs = {}
    accepted_in_arch = {}
    client = koji.ClientSession(KOJI_URL)

    archful = lambda arch: arch != 'noarch'

    def arches_with_package(name, arch):
        '''For a given package and arch, return the arches that list the
        package in their lockfiles.  There may be more than one, since we
        check noarch packages against every candidate architecture.'''
        candidates = [arch] if archful(arch) else ARCHES
        return [a for a in candidates if name in get_manifest_packages(a)]

    for source_nvr in source_nvrs:
        for binpkg in client.listBuildRPMs(source_nvr):
            name = binpkg['name']
            evr = f'{binpkg["version"]}-{binpkg["release"]}'
            if binpkg['epoch'] is not None:
                evr = f'{binpkg["epoch"]}:{evr}'
            for arch in arches_with_package(name, binpkg['arch']):
                if archful(binpkg['arch']):
                    binpkgs[name] = {'evr': evr}
                else:
                    binpkgs[name] = {'evra': evr + '.noarch'}
                accepted_in_arch.setdefault(arch, set()).add(name)

    # Check that every arch has the same package set
    if list(accepted_in_arch.values())[:-1] != list(accepted_in_arch.values())[1:]:
        raise Exception(f'This tool cannot handle arch-specific overrides: {accepted_in_arch}')

    return binpkgs


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
    return [os.path.join(basedir, f) for f in lockfiles]


def graduate_lockfile(base, fn):
    if not os.path.exists(fn):
        return

    with open(fn) as f:
        lockfile = yaml.safe_load(f)
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
        write_lockfile(fn, lockfile)
    else:
        print(f"{fn}: no packages graduated")


def sack_has_nevra_greater_or_equal(base, nevra):
    nevra = hawkey.split_nevra(nevra)
    pkgs = base.sack.query().filterm(name=nevra.name,
                                     arch=nevra.arch).latest().run()

    if len(pkgs) == 0:
        # Odd... the only way I can imagine this happen is if we fast-track a
        # brand new package from Koji which hasn't hit the updates repo yet.
        # Corner-case, but let's be nice.
        print(f"couldn't find package {nevra.name}; assuming not graduated")
        return False

    nevra_latest = hawkey.split_nevra(str(pkgs[0]))
    return nevra_latest >= nevra


def merge_overrides(fn, overrides):
    '''Modify the file fn by applying the specified package overrides.'''
    with open(fn) as f:
        lockfile = yaml.safe_load(f)
    lockfile.setdefault('packages', {}).update(overrides)
    write_lockfile(fn, lockfile)


def write_lockfile(fn, contents):
    with open(fn, 'w') as f:
        f.write(OVERRIDES_HEADER.strip())
        f.write('\n\n')
        yaml.dump(contents, f)


def check_url(u):
    p = urlparse(u)
    if p.scheme not in ('http', 'https'):
        raise Exception(f'Invalid URL: {u}')


def get_expected_dist_tag():
    with open(os.path.join(basedir, 'manifest.yaml')) as f:
        releasever = yaml.safe_load(f)['releasever']
    return f'.fc{releasever}'


def check_dist_tag(name, info, dist):
    if 'evr' in info and not info['evr'].endswith(dist):
        raise Exception(f"Package {name}-{info['evr']} doesn't match expected dist tag {dist}")
    if 'evra' in info and not info['evra'].endswith(dist + '.noarch'):
        raise Exception(f"Package {name}-{info['evra']} doesn't match expected dist tag {dist}")


if __name__ == "__main__":
    sys.exit(main())
