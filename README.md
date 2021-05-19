# Fedora CoreOS Config
Base manifest configuration for
[Fedora CoreOS](https://coreos.fedoraproject.org/).

Use https://github.com/coreos/coreos-assembler to build it.

Discussions in
https://discussion.fedoraproject.org/c/server/coreos. Bug
tracking and feature requests at
https://github.com/coreos/fedora-coreos-tracker.

## About this repo

There is one branch for each stream. The default branch is
[`testing-devel`](https://github.com/coreos/fedora-coreos-config/commits/testing-devel),
on which all development happens. See
[the design](https://github.com/coreos/fedora-coreos-tracker/blob/main//Design.md#release-streams)
and [tooling](https://github.com/coreos/fedora-coreos-tracker/blob/main//stream-tooling.md)
docs for more information about streams.

All file changes in `testing-devel` are propagated to other
branches (to `bodhi-updates` through
[config-bot](https://github.com/coreos/fedora-coreos-releng-automation/tree/main/config-bot),
and to `testing` through usual promotion), with the
following exceptions:
- `manifest.yaml`: contains the stream "identity", such as
  the ref, additional commit metadata, and yum input repos.
- lockfiles (`manifest-lock.*` files): lockfiles are
  imported from `bodhi-updates` to `testing-devel`.
  Overrides (`manifest-lock.overrides.*`) are manually
  curated.

## Layout

We intend for Fedora CoreOS to be used directly for a wide variety
of use cases.  However, we also want to support "custom" derivatives
such as Fedora Silverblue, etc.  Hence the configuration in this
repository is split up into reusable "layers" and components on
the rpm-ostree side.

To derive from this repository, the recommendation is to add it
as a git submodule.  Then create your own `manifest.yaml` which does
`include: fedora-coreos-config/ignition-and-ostree.yaml` for example.
You will also want to create an `overlay.d` and symlink in components
in this repository's `overlay.d`.

## Overriding packages

By default, all packages for FCOS come from the stable
Fedora repos. However, it is sometimes necessary to either
hold back some packages, or pull in fixes ahead of Bodhi. To
add such overrides, one needs to add the packages to
`manifest-lock.overrides.$basearch.yaml`. E.g.:

```yaml
packages:
  # document reason here and link to any Bodhi update
  foobar:
    evra: 1.2.3-1.fc31.x86_64
```

Whenever possible, in the case of pulling in a newer
package, it is important that the package be submitted as an
update to Bodhi so that we don't have to carry the override
forever.

Once an override PR is merged,
[`coreos-koji-tagger`](https://github.com/coreos/fedora-coreos-releng-automation/tree/main/coreos-koji-tagger)
will automatically tag overridden packages into the pool.

## Adding packages to the OS

Since `testing-devel` is directly promoted to `testing`, it
must always be in a known state. The way we enforce this is
by requiring all packages to have a corresponding entry in
the lockfile.

Therefore, to add new packages to the OS, one must also add
the corresponding entries in the lockfiles:
- for packages which should follow Bodhi updates, place them
  in `manifest-lock.$basearch.json`
- for packages which should remain pinned, place them
  in `manifest-lock.overrides.$basearch.yaml`

There will be better tooling to come to enable this, though
one easy way to do this is for now:
- add packages to the correct YAML manifest
- run `cosa fetch --update-lockfile`
- commit only the new package entries

## Moving to a new major version (N) of Fedora

[Create a rebase checklist](https://github.com/coreos/fedora-coreos-tracker/issues/new?labels=kind/enhancement&template=rebase.md&title=Rebase+onto+Fedora+N) in fedora-coreos-tracker.

## CoreOS CI

Pull requests submitted to this repo are tested by
[CoreOS CI](https://github.com/coreos/coreos-ci). You can see the pipeline
executed in `.cci.jenkinsfile`. For more information, including interacting with
CI, see the [CoreOS CI documentation](https://github.com/coreos/coreos-ci/blob/main/README-upstream-ci.md).
