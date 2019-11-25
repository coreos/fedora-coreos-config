# Fedora CoreOS Config
Base manifest configuration for
[Fedora CoreOS](https://coreos.fedoraproject.org/).

Use https://github.com/coreos/coreos-assembler to build it.

Discussions in
https://discussion.fedoraproject.org/c/server/coreos and
https://github.com/coreos/fedora-coreos-tracker.

## About this repo

There is one branch for each stream. The default branch is
[`testing-devel`](https://github.com/coreos/fedora-coreos-config/commits/testing-devel),
on which all development happens. See
[the design](https://github.com/coreos/fedora-coreos-tracker/blob/master/Design.md#release-streams)
and [tooling](https://github.com/coreos/fedora-coreos-tracker/blob/master/stream-tooling.md)
docs for more information about streams.

All file changes in `testing-devel` are propagated to other
branches (to `bodhi-updates` through
[config-bot](https://github.com/coreos/fedora-coreos-releng-automation/tree/master/config-bot),
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
in this repository's `overlay.d.

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
  in `manifest-lock.overrides.$basearch.json`

There will be better tooling to come to enable this, though
one easy way to do this is for now:
- add packages to the correct YAML manifest
- run `cosa fetch --update-lockfile`
- commit only the new package entries

## Moving to a new major version of Fedora

Updating this repo itself is easy:

1. bump `releasever` in `manifest.yaml`
2. update the repos in `manifest.yaml` if needed
3. run `cosa fetch --update-lockfile`
4. PR the result

Though there are also some releng-related knobs that may need changes:

1. verify that the `f${releasever}-coreos-signing-pending` Koji tag has
   been created
2. update RoboSignatory config so that:
    - [tagged packages are signed with the right key](https://infrastructure.fedoraproject.org/cgit/ansible.git/tree/roles/robosignatory/templates/robosignatory.toml.j2?id=c27f4644d4bc2f7916c9c85dc1c1a9ee9a724cc0#n181)
    - [CoreOS artifacts are signed with the right key](https://infrastructure.fedoraproject.org/cgit/ansible.git/tree/roles/robosignatory/templates/robosignatory.toml.j2?id=c27f4644d4bc2f7916c9c85dc1c1a9ee9a724cc0#n458)
