#!/bin/bash

/usr/bin/chromium-browser --remote-debugging-port=9222 \
        --disable-gpu \
        --disable-software-rasterizer \
        --no-sandbox \
        --headless=new \
        --hide-scrollbars \
        --allow-pre-commit-input \
        --disable-background-networking \
        --disable-background-timer-throttling \
        --disable-backgrounding-occluded-windows \
        --disable-breakpad \
        --disable-client-side-phishing-detection \
        --disable-component-extensions-with-background-pages \
        --disable-crash-reporter \
        --disable-default-apps \
        --disable-dev-shm-usage \
        --disable-extensions \
        --disable-hang-monitor \
        --disable-infobars \
        --disable-ipc-flooding-protection \
        --disable-popup-blocking \
        --disable-prompt-on-repost \
        --disable-renderer-backgrounding \
        --disable-search-engine-choice-screen \
        --disable-sync \
        --enable-automation \
        --export-tagged-pdf \
        --force-color-profile=srgb \
        --generate-pdf-document-outline \
        --metrics-recording-only \
        --no-first-run \
        --password-store=basic \
        --use-mock-keychain \
        &

bundle exec rackup --host 0.0.0.0 -p 42069 &

wait -n

exit $?