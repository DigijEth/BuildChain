#!/bin/bash
set -e
cd "$(dirname "$0")"

ZIP="BuildChain-v1.0.0.zip"
rm -f "$ZIP"

zip -r9 "$ZIP" \
    module.prop \
    customize.sh \
    post-fs-data.sh \
    service.sh \
    uninstall.sh \
    tools/ \
    scripts/ \
    webroot/ \
    -x "*.git*" "build.sh" "sepolicy/*"

echo "Built: $ZIP ($(du -h "$ZIP" | cut -f1))"
