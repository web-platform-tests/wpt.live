# Provisioning scripts

This directory contains instructions for configuring a computer to run the
web-platform-tests server. The instructions are intended to be executed using
[the Ansible configuration management tool](https://www.ansible.com/), and the
target computer is expected to be running the Ubuntu 18.04 distribution of
GNU/Linux.

`playbook.yml` is the main ansible playbook for this project. It
installs the required packages, clones
https://github.com/web-platform-tests/wpt into the
`/root/web-platform-tests` directory and creates a system.d service
named `wpt` to run the wptserver.

[systemd](https://freedesktop.org/wiki/Software/systemd/) is used to schedule
recurrent tasks, including:

- fetching the latest code from the WPT repository
- detecting unresponsiveness and responding by restarting the process
- updating the TLS certificate provided by Let's Encrypt (in production)
