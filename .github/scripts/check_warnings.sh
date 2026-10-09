#!/bin/bash
# Fails if the build log contains compiler or build warnings from this project.
# Xcode's App Intents metadata note appears in every app build and is not a project warning.
set -uo pipefail
log="$1"
warnings=$(grep -E "warning:" "$log" \
  | grep -v "appintentsmetadataprocessor" \
  | grep -v "Metadata extraction skipped" \
  | sort -u)
if [ -n "$warnings" ]; then
  echo "::error::Build produced warnings"
  echo "$warnings"
  exit 1
fi
echo "No warnings."
