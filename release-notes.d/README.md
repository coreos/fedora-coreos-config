# Fedora CoreOS Release Note

This directory stores the Fedora CoreOS release note yaml snippets which will be picked up by `fedora-coreos-releng-automation/coreos-release-note-generator` [1] script to produce `release-notes.yaml` with the corresponding latest release ID for the target stream.

Release notes will be organized according to the origin of the change, i.e. the project name. Otherwise miscellaneous changes will be stored under `miscellaneous`. Therefore, the schema of each yaml snippet is designed as follows:

```yaml
# Each yaml file consists of a list of dictionaries which looks like this
- component (required): [Custom Project Name] | miscellaneous
  subject (required): xxx
  body (optional): xxxxx
```

An example `release-notes.yaml`:
```
- 32.20200715.3.0:
    coreos-assembler:
      - subject: add a new sub-command that automates xxx
      - subject: fix a bug that result in https://github.com/coreos/fedora-coreos-tracker/issues/xxx
    miscellaneous:
      - subject: introduce a new config file to facilitate xxx workflow
        body: the config file as described in https://github.com/coreos/fedora-coreos-tracker/issues/xxx helps users to monitor xxx
- 32.20200706.3.0:
    afterburn:
      - subject: add support for platform xxx
- 32.20200620.1.0:
    ignition:
      - subject: fix a minor issue https://github.com/coreos/fedora-coreos-tracker/issues/xxx
...
```

[1] https://github.com/coreos/fedora-coreos-releng-automation
