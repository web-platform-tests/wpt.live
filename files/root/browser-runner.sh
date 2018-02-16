#!/bin/bash -e

export BROWSER=
export FLAGS=--total-chunks=100

if [ -f "/root/browser-is-running.txt" ]; then
    echo "Not running, browser tests are running"
else

    rm -rf /tmp/.com.google.Chro*
    rm -rf /tmp/.org.chromium.Chrom*

    touch /root/browser-is-running.txt

    #    rm -rf ~/wptdbuild/*
    cd /root/wptdashboard/ && ./run/run.py $BROWSER $FLAGS  2>&1 | tee browser-`date +%s`.log

    rm /root/browser-is-running.txt

fi


exit 0
