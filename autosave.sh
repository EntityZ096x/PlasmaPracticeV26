#!/bin/bash
echo 'autosaving every hour'
while true; do
    git add .
    git commit -m "Hourly backup $(date '+%Y-%m-%d %H:%M:%S')" || true
    git push
    sleep 3600
done