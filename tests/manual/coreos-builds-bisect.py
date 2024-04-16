#!/usr/bin/python3
#
# Copyright 2024 Dusty Mabe <dusty@dustymabe.com>
#
#  This program is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation; either
#  version 2 of the License, or (at your option) any later version.
#
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#  Lesser General Public License for more details.
#
#  You should have received a copy of the GNU Lesser General Public
#  License along with this library. If not, see <http://www.gnu.org/licenses/>.
#
#
# This program will bisect a list of CoreOS builds, like what are
# stored in a builds.json file. Example:
#
# It was heavily inspired by rpm-ostree-bisect:
# https://github.com/ostreedev/ostree-releng-scripts/blob/master/rpm-ostree-bisect
#
# Here is some high level representation of what it does:
#
#    grab info on every build in builds.json
#    A -> B -> C -> D -> E -> F -> G
#
#    user provided good/bad builds
#
#    run test script
#    returns 0 for pass and 1 for failure
#
#    known good is A, known bad is G
#
#    start bisect:
#    deploy D, test --> bad
#    mark D, E, F bad
#
#    deploy B, test --> good
#    mark B good
#
#    deploy C, test --> bad
#
#    Failure introduced in B -> C
#
# An example invocation from a cosa build dir looks like:
#
#   cosa buildfetch --force --stream=rawhide # to populate builds/builds.json
#   ./coreos-builds-bisect.py --bad 41.20240404.91.0  \
#                             --good 39.20230813.91.0 \
#                             --testscript=./test.sh
#
# If the testing gets interrupted for some reason you should
# be able to continue it with:
#
#   ./coreos-builds-bisect.py --resume                \
#                             --bad 41.20240404.91.0  \
#                             --good 39.20230813.91.0 \
#                             --testscript=./test.sh
#
# The testcript that gets called from this will get passed one
# argument, which is the ID of the build that should be tested.
# It is up to the test script to pull anything necessary to test
# that build, run the test, and return success or failure.
#
# For example:
# ```
#     cat ./test.sh
#     #!/bin/bash
#     set -eux -o pipefail
#     build=$1
#     cosa buildfetch --force --stream=rawhide --build=$build --artifact=qemu
#     cosa decompress --build=$build
#     cosa kola run --build=$build ext.config.mynewtestiwrote

import argparse
import json
import os
import os.path
import subprocess
import sys
import tempfile
from collections import OrderedDict

DATA_FILE = './coreos-builds-bisect-data.json'
BUILDS_JSON_FILE = './builds/builds.json'

# Inspired by https://stackoverflow.com/a/287944
class colors:
    CLEAR = '\033[0m'
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'

def fatal(msg):
    print(colors.RED + msg + colors.CLEAR, file=sys.stderr)
    sys.exit(1)

def log_color(msg, color):
    print(color + msg + colors.CLEAR)
    sys.stdout.flush()

def log(msg):
    log_color(msg, colors.CYAN)

def log_success(msg):
    log_color(msg, colors.GREEN)

def log_warn(msg):
    log_color(msg, colors.YELLOW)

"""
    Initialize build ID order dict. The array will be a list of
    commits in descending order. Each entry will be a dict with
    key of commitid and value = a dict of version, heuristic
    (TESTED, GIVEN, ASSUMED), and status (GOOD/BAD/UNKNOWN)

    builds = {
        '39.20230813.91.0' => {
                      'heuristic', 'TESTED',
                      'status': 'GOOD',
                    },
    }
"""
def initialize_builds_info(buildsjson, arch, badbuild, goodbuild):
    with open(buildsjson, 'r') as f:
        builds = json.load(f, object_pairs_hook=OrderedDict)
    # Further narrow in on just the list of build dicts
    builds = builds['builds']

    # An ordered dictionary of builds info
    info = OrderedDict()

    # Populate the info dict
    for build in builds:
        # If this build has an entry for this architecture add it to
        # our builds info dict.
        if arch in build['arches']:
            info.update({ build['id']: { 'status': 'UNKNOWN',
                                         'heuristic': 'ASSUMED'}})
    # Mark the bad commit bad and the good commit good
    info[badbuild]['status'] = 'BAD'
    info[badbuild]['heuristic'] = 'GIVEN'
    info[goodbuild]['status'] = 'GOOD'
    info[goodbuild]['heuristic'] = 'GIVEN'
    return info


def load_data(datafile):
    with open(datafile, 'r') as f:
        data = json.load(f, object_pairs_hook=OrderedDict)
    return data


def write_data(datafile, data):
    dirname = os.path.dirname(datafile)
    (_, tmpfile) = tempfile.mkstemp(
                    dir=dirname,
                    prefix="coreos-builds-bisect")

    with open(tmpfile, 'w') as f:
        json.dump(data, f, indent=4)
    os.rename(tmpfile, datafile)


def verify_script(testscript):
    # Verify test script exists and is executable
    if not testscript:
        fatal("Must provide a --testscript to run")
    if not (os.path.isfile(testscript)
         and os.access(testscript, os.X_OK)):
        fatal(f"provided test script: {testscript} is not an executable file")


def bisect(args):
    badbuild  = args.badbuild
    goodbuild = args.goodbuild
    testscript = args.testscript
    datafile = args.datafile

    builds_info = load_data(datafile)

    # Loop until we're done bisecting
    while True:
        # Find list of unknown status builds
        unknowns = []
        lastbad = None
        firstgood = None
        for buildid in builds_info.keys():
            status = builds_info[buildid]['status']
            if status == 'BAD':
                lastbad = buildid
            elif status == 'UNKNOWN':
                unknowns.append(buildid)
            elif status == 'GOOD':
                firstgood = buildid
                break

        # If we have no unknowns then we're done!
        if len(unknowns) == 0:
            log("BISECT TEST RESULTS:")
            if firstgood is None:
                log("No good builds were found in the history!")
                return 0
            # Do a sanity check to see if the good commit was actually tested.
            if builds_info[firstgood]['heuristic'] == 'GIVEN':
                log_warn("WARNING: The good build detected was the one given by the user.")
                log_warn("WARNING: Are you sure this build is good?")
            log(f"Last known good build: {firstgood}")
            log(f"First known bad build: {lastbad}")
            return 0

        # Bisect to find new build id to test and then run the test
        # //2 makes sure to give us an integer rather than a float
        newbuildid = unknowns[len(unknowns)//2]
        revisions = len(unknowns)
        steps = 0
        while revisions > 0:
            revisions //= 2
            steps += 1
        log(f"Executing test for new build: {newbuildid}. ~{steps} steps left")
        ec = subprocess.call([testscript, newbuildid])
        if ec == 0:
            log_success(f"{newbuildid} passed")
            success = True
        else:
            log_warn(f"{newbuildid} failed")
            success = False


        # update the data with the results
        if success:
            for b in reversed(builds_info.keys()):
                builds_info[b]['status'] = 'GOOD'
                if b == newbuildid:
                    break
        else:
            for b in builds_info.keys():
                builds_info[b]['status'] = 'BAD'
                if b == newbuildid:
                    break
        builds_info[b]['heuristic'] = 'TESTED'

        # Save the state in case the script gets interrupted
        write_data(datafile, builds_info)


def main():

    parser = argparse.ArgumentParser()
    parser.add_argument("--arch", dest='arch',
                        help="What architecture to target", action='store')
    parser.add_argument("--buildsjson", dest='buildsjson',
                        help="Path to builds.json file",
                        action='store', default=BUILDS_JSON_FILE)
    parser.add_argument("--bad", dest='badbuild',
                        help="Known Bad Build", action='store')
    parser.add_argument("--good", dest='goodbuild',
                        help="Known Good Build", action='store')
    parser.add_argument("--testscript", help="A test script to run",
                        action='store')
    parser.add_argument("--resume", help="Resume a running bisection",
                        action='store_true')
    parser.add_argument("--datafile", help="data file to use for state",
                        action='store', default=DATA_FILE)
    args = parser.parse_args()
    log(f"Using data file at: {args.datafile}")

    verify_script(args.testscript)

    if not args.arch:
        cp = subprocess.run(['arch'], capture_output=True)
        args.arch = cp.stdout.decode('utf-8').strip()
    log(f"Targetting architecture: {args.arch}")

    if args.resume:
        if not os.path.exists(args.datafile):
            fatal(f"Datafile at {args.datafile} must pre-exist with --resume")
    else:
        if not args.badbuild or not args.goodbuild:
            fatal("Must specify both a bad and a good build via --bad and --good")
        if not os.path.exists(args.buildsjson):
            fatal(f"A builds.json file does not exist at {args.buildsjson}")
        if os.path.exists(args.datafile) and not args.resume:
            log(f"A datafile exists at {args.datafile} but --resume not specified")
            log("If you want to resume a bisect pass --resume")
            fatal("If you want to start a new bisect delete the datafile")

        # initialize data
        builds_info = initialize_builds_info(args.buildsjson,
                                             args.arch,
                                             args.badbuild,
                                             args.goodbuild)
        # Write data to file
        write_data(args.datafile, builds_info)

    bisect(args)

if __name__ == '__main__':
    main()
