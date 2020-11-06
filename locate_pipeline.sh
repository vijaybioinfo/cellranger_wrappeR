#!/bin/bash

cd "$(dirname "${0}")" || exit

if [[ ! -s .config.yaml ]]; then cp config.yaml .config.yaml; fi

PIPELINE_DIR="$(pwd -P)"
TOOL_NAME="$(basename "${PIPELINE_DIR}")" # extracting folder name

echo "Name: ${TOOL_NAME}"
echo "Pipeline: ${PIPELINE_DIR}"
sed 's|\./|'"${PIPELINE_DIR}"'/|g' .config.yaml > config.yaml

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
