# Generate the PipelineRun configuration files

The PipelineRun configuration files are generated from Jinja2 templates.

## Files

- `templates/pipelinerun.yaml.j2` - The Jinja2 template for PipelineRun resources
- `templates/streams.yaml` - Configuration defining all streams and their settings

## Making changes

- **Common changes**: Edit the Jinja2 template in `templates/pipelinerun.yaml.j2`
- **Stream-specific changes**: Edit `templates/streams.yaml` to add/remove streams or modify their settings
- **Pipeline bundle updates**: Update `config.pipeline_bundle` in `templates/streams.yaml`

After any manual changes, run the script below to regenerate the configuration files.

## Script prerequisites

- Python 3.6+
- jinja2 (`pip install jinja2`)
- pyyaml (`pip install pyyaml`)

## Usage
```bash
# Generate all PipelineRun files
./ci/generate-tekton-pipelinerun.py

# Check if files are up to date (useful for CI)
./ci/generate-tekton-pipelinerun.py --check
```
