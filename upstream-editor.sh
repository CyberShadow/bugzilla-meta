#!/bin/bash
set -eEuo pipefail

sed -i 's/ (#[0-9][0-9]*)$//' "$@"
