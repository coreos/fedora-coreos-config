# Generate the PipelineRun configuration files

The base configuration lives in `./base/base/fedora-coreos.yaml` file. All the common changes must be defined there.
The specific changes must be defined in the `kustomization.yaml` file living in the directory of the respective pipelinerun.
After any manual changes, the script below must be run to generate the configuration files properly.

Script prerequisites:
- kustomize

```bash
./ci/generate-tekton-pipelinerun
```
