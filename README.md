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

## Contributing

- [Docker](https://www.docker.com/)
- [GNU Make](https://www.gnu.org/software/make/)

## Deploying

- [Terraform](https://www.terraform.io/)
