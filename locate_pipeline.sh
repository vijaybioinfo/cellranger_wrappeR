#!/bin/bash

if [[ ! -s .config.yaml ]]; then cp config.yaml .config.yaml; fi
PIPELINE_DIR=`pwd`
echo "Pipeline: ${PIPELINE_DIR}"
sed -i 's|\./|'${PIPELINE_DIR}'/|g' config.yaml

if ! grep -q "cellranger_wrappeR" ~/.bash_alias; then
  echo "Adding alias"
  echo "alias cellranger_wrappeR='sh ${PIPELINE_DIR}/run.sh'" >> ~/.bash_alias
else
  echo "cellranger_wrappeR has an alias"
fi

if ! grep -q "bash_alias" ~/.bash*; then
  echo "Adding alias sourcing to ~/.bashrc"
  echo "source ~/.bash_alias" >> ~/.bashrc
fi
