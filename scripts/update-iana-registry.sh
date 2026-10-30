#!/bin/sh
# Refreshes the bundled IANA service-name registry snapshot. Run before tagging a release.
set -eu
cd "$(dirname "$0")/.."
curl -sSL --fail -o nonsource/service-names-port-numbers.csv \
  "https://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.csv"
echo "Updated nonsource/service-names-port-numbers.csv ($(grep -c '' nonsource/service-names-port-numbers.csv) lines)"
