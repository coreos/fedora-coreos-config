#!/usr/bin/python3
# Update Antora attributes for OS and tool versions.

import os
import requests
import sys
import yaml

GITHUB_RELEASES = {
    'butane-version': 'coreos/butane',
    'ignition-version': 'coreos/ignition',
}
FCOS_STREAMS = {
    'stable-version': 'stable',
}

basedir = os.path.normpath(os.path.join(os.path.dirname(sys.argv[0]), '..'))

with open(os.path.join(basedir, 'antora.yml'), 'r+') as fh:
    config = yaml.safe_load(fh)
    attrs = config.setdefault('asciidoc', {}).setdefault('attributes', {})
    orig_attrs = attrs.copy()

    for attr, repo in GITHUB_RELEASES.items():
        resp = requests.get(f'https://api.github.com/repos/{repo}/releases/latest')
        resp.raise_for_status()
        tag = resp.json()['tag_name']
        attrs[attr] = tag.lstrip('v')

    for attr, stream in FCOS_STREAMS.items():
        resp = requests.get(f'https://builds.coreos.fedoraproject.org/streams/{stream}.json')
        resp.raise_for_status()
        # to be rigorous, we should have a separate attribute for each
        # artifact type, but the website doesn't do that either
        attrs[attr] = resp.json()['architectures']['x86_64']['artifacts']['metal']['release']

    if attrs != orig_attrs:
        fh.seek(0)
        fh.truncate()
        fh.write("# Automatically modified by update-versions.py; comments will not be preserved\n\n")
        yaml.safe_dump(config, fh, sort_keys=False)
