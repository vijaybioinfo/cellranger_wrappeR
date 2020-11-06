#!/bin/bash

set -euo pipefail

function usage () {
    cat >&2 <<EOF

USAGE: $0 [-y] [options]
  -y <config file> : Path to the YAML config file. Required.
  -v Verbose.
  -h Print the usage info.

EOF
}
# initial : makes this loop silent and now requires '?)'
# ${opt} is each option and ${OPTARG} its the argumet (if a colon is there ${opt}:)
VERBOSE=FALSE
while getopts ":y:vh" opt; do
  case ${opt} in
    y) CONFIG_FILE=${OPTARG};;
    v) VERBOSE=TRUE;;
    h) usage; exit 1;;
    \?) echo "No -${OPTARG} argument found."; usage; exit 1;;
  esac
done
if [[ ${OPTIND} -eq 1 ]] ; then
    usage; exit 1
fi

if grep -q 'pipeline:' "${CONFIG_FILE}"; then
  PIPELINE_DIR=$(grep 'pipeline:' "${CONFIG_FILE}" | awk '{print $2}' | sed 's/\"//g')
else
  PIPELINE_DIR=$(dirname "${0}")
fi
PIPELINE_DIR=${PIPELINE_DIR%/}

echo "Configuration: ${CONFIG_FILE}"
echo "Verbose: ${VERBOSE}"
echo "Pipeline: ${PIPELINE_DIR}"

Rscript "${PIPELINE_DIR}"/demultiplexing_cells.R -y "${CONFIG_FILE}" -v ${VERBOSE}
if grep -q "aggregation:" "${CONFIG_FILE}"; then
  Rscript "${PIPELINE_DIR}"/aggregate.R -y "${CONFIG_FILE}" -v ${VERBOSE}
fi

echo "Check outputs at: $(grep "output_dir" "${CONFIG_FILE}" | sed 's/.*: //; s/ #.*//')"
