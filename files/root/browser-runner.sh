#!/bin/bash -e

if [ -f "/root/browser-is-running.txt" ]; then
    echo "Not running, browser tests are running"
else

    touch /root/browser-is-running.txt

    #    rm -rf ~/wptdbuild/*
    cd /root/wptdashboard/ && ./run/run.py safari-11.0-macos-10.12-sauce --wpt_sha b0ff0ea414db44f9847394f25f488fc19f7d33d7 --upload --create-testrun --total-chunks 100 2>&1 | tee browser-`date +%s`.log

    rm /root/browser-is-running.txt

fi


exit 0
