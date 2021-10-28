#!/bin/bash
# note: untested!
set JRC_DIRECTORY="$(dirname "${BASH_SOURCE[0]}")"
set CURRENT_DIRECTORY=$pwd
set JRC_PARAMETERS="$@"
jai $JRC_DIRECTORY/../jrc.jai -- "$CURRENT_DIRECTORY" $JRC_PARAMETERS
rm ".build" -rf
