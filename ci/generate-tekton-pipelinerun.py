#!/usr/bin/env python3
"""
Generate Tekton PipelineRun configuration files for Fedora CoreOS builds.

This script uses Jinja2 templates to generate PipelineRun YAML files for each
stream (branch) and event type combination.
"""

import argparse
import os
import sys
from pathlib import Path

try:
    import jinja2
    import yaml
except ImportError as e:
    print(f"Error: Required module not found: {e.name}", file=sys.stderr)
    print("Please install required dependencies:", file=sys.stderr)
    print("  pip install jinja2 pyyaml", file=sys.stderr)
    sys.exit(1)


# Event type configurations
EVENT_CONFIGS = {
    "on-push": {
        "cancel_in_progress": False,
        "cel_expression_base": 'event == "push" && !(files.all.all(f, f.matches("ci/buildroot/") || f.matches(".tekton/fcos-buildroot/")))',
        "output_image_suffix": ":{{revision}}",
        "image_expires_after": None,
    },
    "on-pull-request": {
        "cancel_in_progress": True,
        "cel_expression_base": 'event == "pull_request" && !(files.all.all(f, f.matches("ci/buildroot/") || f.matches(".tekton/fcos-buildroot/"))) && !("manifest-lock.overrides*".pathChanged())',
        "output_image_suffix": ":on-pr-{{revision}}",
        "image_expires_after": "5d",
    },
    "on-pull-request-overrides": {
        "cancel_in_progress": True,
        "cel_expression_base": 'event == "pull_request" && "manifest-lock.overrides*".pathChanged()',
        "output_image_suffix": ":on-pr-{{revision}}",
        "image_expires_after": "5d",
    },
}


def load_streams_config(config_path: Path) -> dict:
    """Load the streams configuration from YAML file."""
    with open(config_path, encoding="utf-8") as f:
        return yaml.safe_load(f)


def setup_jinja_env(template_dir: Path) -> jinja2.Environment:
    """Set up the Jinja2 environment."""
    return jinja2.Environment(
        loader=jinja2.FileSystemLoader(template_dir),
        keep_trailing_newline=True,
        trim_blocks=False,
        lstrip_blocks=False,
    )


def generate_pipelinerun(
    env: jinja2.Environment,
    stream_name: str,
    stream_config: dict,
    event_type: str,
    pipeline_bundle: str,
) -> str:
    """Generate a PipelineRun YAML for a stream and event type."""
    event_config = EVENT_CONFIGS[event_type]

    # Check for custom CEL expression for on-push event
    if event_type == "on-push" and "on_push_cel_expression" in stream_config:
        cel_expression = stream_config["on_push_cel_expression"]
    else:
        # Build the CEL expression with stream-specific branch filter
        cel_expression = f'{event_config["cel_expression_base"]} && target_branch == "{stream_name}"'

    # Build output image URL
    output_image = f"quay.io/konflux-fedora/coreos-tenant/fedora-coreos-{{{{target_branch}}}}{event_config['output_image_suffix']}"

    # Get stream-specific hermetic setting (default: true)
    hermetic = stream_config.get("hermetic", True)

    template = env.get_template("pipelinerun.yaml.j2")
    return template.render(
        stream=stream_name,
        event_type=event_type,
        cancel_in_progress=event_config["cancel_in_progress"],
        cel_expression=cel_expression,
        output_image=output_image,
        image_expires_after=event_config["image_expires_after"],
        pipeline_bundle=pipeline_bundle,
        hermetic=hermetic,
    )


def main():
    parser = argparse.ArgumentParser(
        description="Generate Tekton PipelineRun configuration files"
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Check if generated files are up to date (exit 1 if not)",
    )
    args = parser.parse_args()

    # Determine paths
    script_dir = Path(__file__).parent.resolve()
    repo_root = script_dir.parent
    tekton_dir = repo_root / ".tekton"
    template_dir = tekton_dir / "templates"
    config_path = template_dir / "streams.yaml"

    # Load configuration
    config = load_streams_config(config_path)
    pipeline_bundle = config["config"]["pipeline_bundle"]
    streams = config["streams"]

    # Set up Jinja2
    env = setup_jinja_env(template_dir)

    # Track if any files need updating (for --check mode)
    files_need_update = []

    print("Generating pipelinerun configuration...")

    for stream_config in streams:
        stream_name = stream_config["name"]
        has_overrides = stream_config.get("has_overrides", False)

        # Determine which event types this stream needs
        event_types = ["on-push", "on-pull-request"]
        if has_overrides:
            event_types.append("on-pull-request-overrides")

        for event_type in event_types:
            # Generate the content
            content = generate_pipelinerun(
                env, stream_name, stream_config, event_type, pipeline_bundle
            )

            # Determine output path
            output_dir = tekton_dir / stream_name / event_type
            output_file = output_dir / f"fedora-coreos-{stream_name}-{event_type}.yaml"

            if args.check:
                # Check mode: compare with existing file
                if output_file.exists():
                    existing_content = output_file.read_text(encoding="utf-8")
                    if existing_content != content:
                        files_need_update.append(str(output_file))
                        print(f"  {stream_name}-{event_type}: NEED UPDATE")
                    else:
                        print(f"  {stream_name}-{event_type}: ok")
                else:
                    files_need_update.append(str(output_file))
                    print(f"  {stream_name}-{event_type}: MISSING")
            else:
                # Generate mode: write the file
                output_dir.mkdir(parents=True, exist_ok=True)
                output_file.write_text(content, encoding="utf-8")
                print(f"  generating {stream_name}-{event_type} pipelinerun")

    if args.check:
        if files_need_update:
            print(
                f"\nError: {len(files_need_update)} file(s) need to be regenerated.",
                file=sys.stderr,
            )
            print("Run './ci/generate-tekton-pipelinerun.py' to update them.", file=sys.stderr)
            sys.exit(1)
        else:
            print("\nAll files are up to date.")
    else:
        print("Done.")


if __name__ == "__main__":
    main()
