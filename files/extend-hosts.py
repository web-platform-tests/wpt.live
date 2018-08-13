#!/usr/bin/env python

# Copyright 2018 The WPT Dashboard Project. All rights reserved.
#
# W3C 3-clause BSD License
#
# http://www.w3.org/Consortium/Legal/2008/03-bsd-license.html
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
# * Redistributions of works must retain the original copyright notice,
#   this list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the original copyright
#   notice, this list of conditions and the following disclaimer in the
#   documentation and/or other materials provided with the distribution.
#
# * Neither the name of the W3C nor the names of its contributors may be
#   used to endorse or promote products derived from this work without
#   specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import argparse
import sys

sigil = ' # inserted by extend-hosts.py script'


def main(filename, stream):
    '''Insert newline-separated content into a file, replacing any content that
    was previously inserted using this script. Assumes that the "hash"
    character (`#`) signifies a comment and that appending it to the input will
    not change the semantics of the modified file.

    This script is intended to modify the `/etc/hosts` file on Unix-like
    systems in an idempotent way.'''

    persisting = []
    newly_added = []

    with open(filename) as handle:
        for line in handle:
            line = line.strip()

            if line.endswith(sigil):
                continue

            persisting.append(line)

    for line in stream:
        newly_added.append(line.strip() + sigil)

    with open(filename, 'w') as handle:
        handle.write('\n'.join(persisting + newly_added))


parser = argparse.ArgumentParser(description=main.__doc__)
parser.add_argument('filename')

if __name__ == '__main__':
    main(parser.parse_args().filename, sys.stdin)
