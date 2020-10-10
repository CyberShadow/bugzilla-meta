#!/bin/bash
set -eEuo pipefail

# Remove old pull request IDs
# (for changes that are resubmitted to another branch)
sed -i 's/ (#[0-9][0-9]*)$//' "$@"
