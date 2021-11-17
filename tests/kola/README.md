# Kola External Tests

For more information about the `kola` external tests, see the [Integrating External Test Suites](https://coreos.github.io/coreos-assembler/kola/external-tests/#integrating-external-test-suites)
topic in the `coreos-assembler` documentation.

## Sharing tests between FCOS/RHCOS

These tests are intended to be shared between FCOS and RHCOS. If you are adding
a new test(s) to this collection, ensure that the test also run on RHCOS.
Otherwise, use the `kola` JSON header to specify that it only runs on FCOS like
so:

```bash
#!/bin/bash
# kola: {"distros": "fcos"}
...
```
