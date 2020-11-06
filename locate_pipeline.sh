#!/bin/bash

if [[ ! -s .config.yaml ]]; then cp config.yaml .config.yaml; fi
cd "$(dirname "${0}")" || exit

TOOL_NAME=cellranger_wrappeR
PIPELINE_DIR=$(pwd -P)

echo "Pipeline: ${PIPELINE_DIR}"
sed -i 's|\./|'"${PIPELINE_DIR}"'/|g' config.yaml

if ! grep -q "${TOOL_NAME}" ~/.bash_alias; then
  echo "Adding alias"
  echo "alias ${TOOL_NAME}='sh ${PIPELINE_DIR}/run.sh'" >> ~/.bash_alias
else
  echo "Substituting existing alias"
  sed -i 's|.*'"${TOOL_NAME}"'.*|alias '"${TOOL_NAME}"'="sh '"${PIPELINE_DIR}"'/run.sh"|' ~/.bash_alias
fi

if ! grep -q "bash_alias" ~/.bash*; then
  echo "Adding alias sourcing to ~/.bashrc"
  echo "source ~/.bash_alias" >> ~/.bashrc
fi
source ~/.bash_alias
