# [web-platform-tests.live](http://web-platform-tests.live)

A live version of [wpt](https://github.com/web-platform-tests/wpt)

This repo contains a deployment automation for running a live instance of the
web platform tests project that people can visit and run file by file in their
favorite web browser.

## Overview

The web-platform-tests server is known to be unreliable, so in order to offer a
consistent experience, this project uses a non-trivial server layout in Google
Cloud Platform.


    *Let's Encrypt*                                     *GitHub*
          |                                                 |
    [TLS certificate]                                [WPT source code]
          |                                .------------.   |
          V                             .->| wpt server |<--+
    .--------------.   +++++++++++++++  |  '------------'   |
    | cert-renewer |-->+ certificate +--+                   |
    '--------------'   +    store    +  |  .------------.   |
                       +++++++++++++++  '->| wpt server |<--'
                                           '------------'
    Legend
                        .---.               +++++
    *   * external      |   | GCE           +   + object     [   ] message
          service       '---' instance      +++++ store            contents

The server is run by multiple Google Compute Engine instances deployed in
parallel. These are members of a Managed Instance Group, so when one fails, it
is automatically destroyed, and a new instance is created in its place. Many of
the web-platform-tests concern the semantics of the HTTP protocol, so load
balancing is provided at the TCP level in order to avoid interference.

In addition to serving the web-platform-tests, each server performs a few tasks
on a regular interval. These include:

- fetching the latest revision of the web-platform-tests project from the
  canonical git repository hosted on GitHub.com
- fetching TLS certificates from the internally-managed object store (see
  below)

When any of these periodic tasks complete, the web-platform-tests server
process is restarted in order to apply the changes.

A separate Google Compute Engine instance interfaces with the Let's Encrypt
service to retrieve TLS certificates for the WPT servers. It integrates with
Google Cloud Platform's DNS management in order to prove ownership of the
system's domain name. It stores the certificates in a Google Cloud Platform
Storage bucket for retrieval by the web-platform-tests servers.

The functionality described to this point is provided by the "tot" (or
"tip-of-tree") server. This project also includes a "submissions" server, which
offers the same functionality and also automatically publishes the contents of
some patches submitted to [the web-platform-tests project hosted on
GitHub.com](https://github.com/web-platform-tests/wpt).

### Server virtualization

Each server described above runs its application code in a Docker container. A
single container does not provide any benefit in terms of isolation. It does
add value in two other ways:

1. Ease of deployment. Contributors can build images, run them locally, and
   publish them for use in the production environment. These operations have
   been abstracted in the project's `Makefile`.
2. Error recovery. In production, the containers are executed with the "always"
   restart policy. This ensures that if a sub-system fails, it is automatically
   revived from a consistent state.

In the case of the web-platform-tests server, an additional layer of error
recovery is provided via a Google Cloud Platform "health check." If the Google
Compute Engine instance fails to respond to HTTP requests, then it will be
destroyed and a new one created in its place.

## Contributing

Requirements:

- [Docker](https://www.docker.com/)
- [GNU Make](https://www.gnu.org/software/make/)

The following commands will build Docker images for the respective sub-systems:

    make cert-renewer
    make wpt-server-tot
    make wpt-server-submissions

The following commands will build the Docker images and run them on the local
system:

    make run-cert-renewer
    make run-wpt-server-tot
    make run-wpt-server-submissions

Running these containers requires the specification of a number of environment
variables. See the appropriate `Dockerfile` for a definition of the expected
variables.

## Deploying

Requirements:

- [Docker](https://www.docker.com/)
- [GNU Make](https://www.gnu.org/software/make/)
- [Terraform](https://www.terraform.io/) version 0.11.14
- [Python 3](https://python.org)
- access credentials to the Google Cloud Platform project, saved to a file named
  `google-cloud-platform-credentials.json` in the root pf this repository

The following commands will build Docker images for the respective sub-systems
and upload them to Google Cloud Platform:

    make publish-cert-renewer
    make publish-wpt-server-tot
    make publish-wpt-server-submissions

The following command will synchronize the infrastructure running in Google
Cloud Platform with the state described by the configuration files in this
directory:

    terraform apply
