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
- lockfiles (`manifest-lock.*` files).
