# Fedora Docs Template

This repository contains the Fedora CoreOS documentation. The format is [AsciiDoc](https://asciidoctor.org/docs/asciidoc-syntax-quick-reference/) to enable integration into the official [Fedora documentation](https://docs.fedoraproject.org/en-US/docs/).

## Structure

```
|-- README.md
|-- antora.yml ....................... 1.
|-- docsbuilder.sh ................... 2.
|-- nginx.conf ....................... 3.
|-- site.yml ......................... 4.
`-- modules
    `-- ROOT ......................... 5.
        |-- assets
        |   `-- images ............... 6.
        |       `-- *
        |-- nav.adoc ................. 7.
        `-- pages .................... 8.
            `-- *.adoc
```

1. Metadata definition.
2. A script that does a local build. It shows a preview of the site in a web browser by running a local web server. Uses podman or Docker.
3. A configuration file used by the local preview web server.
4. A definition file for the build script.
5. A "root module of this documentation component". Please read below for an explanation.
6. **Images** to be used on any page.
7. **Menu definition.** Also defines the hierarchy of all the pages.
8. **Pages with the actual content.** They can be also organised into subdirectories if desired.

## Components and Modules

Antora introduces two new terms:

* **Component** — Simply put, a component is a part of the documentation website with its own menu. Components can also be versioned. In the Fedora Docs, we use separate components for user documentation, the Fedora Project, Fedora council, Mindshare, FESCO, but also subprojects such as CommOps or Modularity.
* **Module** — A component can be broken down into multiple modules. Modules still share a single menu on the site, but their sources can be stored in different git repositories, even owned by different groups. The default module is called "ROOT" (that's what is in this example). If you don't want to use multiple modules, only use "ROOT". But to define more modules, simply duplicate the "ROOT" directory and name it anything you want. You can store modules in one or more git repositories.

## Local preview

This repo includes a script to build and preview the contents of this repository.

**NOTE**: Please note that if you reference pages from other repositories, such links will be broken in this local preview as it only builds this repository. If you want to rebuild the whole Fedora Docs site, please see [the Fedora Docs build repository](https://pagure.io/fedora-docs/docs-fp-o/) for instructions.

The script works on Fedora (using Podman or Docker) and macOS (using Docker).

To build and preview the site, run:

```
$ ./docsbuilder.sh -p
```

The result will be available at http://localhost:8080

To stop the preview:

```
$ ./docsbuilder.sh -k

```

### Installing Podman on Fedora

Fedora Workstation doesn't come with Podman preinstalled by default — so you might need to install it using the following command:

```
$ sudo dnf install podman
```

### Preview as a part of the whole Fedora Docs site

You can also build the whole Fedora Docs site locally to see your changes in the whole context.
This is especially useful for checking if your `xref` links work properly.

To do this, you need to clone the main [Fedora Docs build repository](https://pagure.io/fedora-docs/docs-fp-o), modify the `site.yml` file to reference a repo with your changes, and build it.
Steps:

Clone the main repository and cd into it:

```
$ git clone https://pagure.io/fedora-docs/docs-fp-o.git
$ cd docs-fp-o
```

Find a reference to the repository you're changing in the `site.yml` file, and change it so it points to your change.
So for example, if I made a modification to the Modularity docs, I would find:

```
...
   - url: https://pagure.io/fedora-docs/modularity.git
     branches:
       - master
...
```

And replaced it with a pointer to my fork:
```
...
   - url: https://pagure.io/forks/asamalik/fedora-docs/modularity.git
     branches:
       - master
...
```

I could also point to a local repository, using `HEAD` as a branch to preview the what's changed without the need of making a commit.

**Note:** I would need to move the repository under the `docs-fp-o` directory, because the builder won't see anything above.
So I would need to create a `repositories` directory in `docs-fp-o` and copy my repository into it.

```
...
   - url: ./repositories/modularity
     branches:
       - HEAD
...
```

To build the whole site, I would run the following in the `docs-fp-o` directory.

```
$ ./docsbuilder.sh -p
```
# License

SPDX-License-Identifier: CC-BY-SA-4.0
