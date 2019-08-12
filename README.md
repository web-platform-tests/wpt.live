# [web-platform-tests.live](http://web-platform-tests.live)

This repository contains scripts for deploying [the web-platform-tests project
(WPT)](https://github.com/web-platform-tests/wpt) to the web such that its
tests can be run in a web browser. The deployment has been designed for
stability and for relevancy (by automatically synchronizing with the latest
revision of WPT and submissions from contributors).

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

The server is run by multiple Google Compute Engine (or "GCE") instances
deployed in parallel. These are members of a Managed Instance Group, so when
one fails, it is automatically destroyed, and a new instance is created in its
place. Many of the web-platform-tests concern the semantics of the HTTP
protocol, so load balancing is provided at the TCP level in order to avoid
interference.

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
single container does not provide any benefit in terms of isolation, but it
does add value in two other ways:

1. Ease of deployment. Contributors can build images, run them locally, and
   publish them for use in the production environment. These operations have
   been abstracted in the project's `Makefile`.
2. Error recovery. In production, the containers are executed with the "always"
   restart policy. This ensures that if a sub-system fails, it is automatically
   revived from a consistent state.

Moreover, this project contradicts common practice of Docker-based development
in that it runs multiple processes in a single container (managed by
[Supervisord](http://supervisord.org/)). This further simplifies deployment
because [Google Compute Engine instances can be configured to run Docker
containers](https://cloud.google.com/compute/docs/containers/deploying-containers),
avoiding the complexity introduced by orchestration tools like [Docker
Compose](https://docs.docker.com/compose/) or
[Kubernetes](https://kubernetes.io/).

If the WPT server fails (as indicated by its process exiting), then Docker as
running in the Google Compute Engine Instance will automatically restart the
Docker container.

    container    GCE Instance
       |             |
       x             |
                    err!
       .---restart---'
       |             |
       |            okay

Restarting the container completely refreshes runtime state, and this is
expected to resolve many potential problems in the deployment.

In the case of the web-platform-tests server, an additional layer of error
recovery is provided via a Google Cloud Platform "health check." If the Google
Compute Engine instance fails to respond to HTTP requests, then it will be
destroyed and a new one created in its place. That new instance will
subsequently create a Docker container to run the WPT server.

    container    GCE Instance    GCE Managed Group
       |             |                 |
       x             x                 |
                                      err!
                     .-----restart-----'
                     |                 |
       .---restart---'                 |
       |             |                 |
       |            okay               |
       |             |                 |
       |             |                okay

This second recovery mechanism guards against more persistent problems, e.g.
those stemming from state on disk (since even a running GCE instance will fail
HTTP health checks if restarting the Docker container has no effect).

### Submissions preview

This project defines a second deployment of the WPT server which publishes the
content of patches submitted to [the web-platform-tests repository on
GitHub.com](https://github.com/web-platform-tests/wpt) (also known as "pull
requests"). This second deployment has a similar structure to the first, and it
includes additional scripting to automatically fetch and publish the content of
submissions.

Submissions are identified by the automation infrastructure maintained in the
WPT project. That infrastructure communicates the name and content of the
submissions using specialized git "refs," and this project determines what must
be published by polling the git repository for the refs on a regular interval.

The following flow diagram illustrates how submissions travel from the WPT
contributor to the deployed "submissions" instance of this project.

    Contributor           GitHub.com    git repository     web-platform-tests.live
        |                     |               |                     |
        |                     |               .------[git fetch]----'
        |                     |               '---------------------.
        '---[pull request]---.|               |                     |
                              v               |                     |
                              '--[git tag]---.|                     |
                                              v                     |
                                              |                     |
                                              .------[git fetch]----'
                                              '---------------------.
                                                                    V
                                        (fetching continues on a regular interval)

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

Publishing new images will not directly affect the deployed system. In order to
deploy new images, the GCP managed instance groups must be updated using
Terraform.

The following command will synchronize the infrastructure running in Google
Cloud Platform with the state described by the configuration files in this
repository:

    terraform apply
