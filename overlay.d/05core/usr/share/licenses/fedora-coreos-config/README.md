# fedora-coreos-config

Today most components of Fedora CoreOS are built as RPMs; this
is the main exception.  fedora-coreos-config is "architecture-independent glue"
and the overhead of building an RPM for each change is onerous.

It's also *the* central point of management (e.g. it contains lockfiles), so having it be
an RPM too would become circular.  Instead, coreos-assembler directly consumes it.

The upstream git repository is: https://github.com/coreos/fedora-coreos-config

From a running system, to find the source commit use:
```
$ rpm-ostree status -b --json | jq -r '.deployments[0]."base-commit-meta"."coreos-assembler.config-gitrev"'
c8dbed9ce223bf86737c82dd763670c8a34e950f
$
```
