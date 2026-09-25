# Build Fedora CoreOS as a container image.
build:
	# Note if you change these build arguments, also change the comment in Containerfile
	podman build --security-opt=label=disable --cap-add=all --device /dev/fuse --build-arg-file build-args.conf -v $PWD:/run/src . -t localhost/fedora-coreos
