#!/bin/bash

# Exit on any error
set -e

# Define the expected checksum
CHECKSUM="383f964ba516a9e4929db0811424319e5a17abddc0b880727879eaa891f130cf"

# 1. Check if the gurobi13.0.0_R.tar.gz tarball exists, otherwise download it.
if [ ! -f gurobi13.0.0_R.tar.gz ]; then
  echo "Downloading gurobi13.0.0_R.tar.gz..."
  curl -O https://packages.gurobi.com/13.0/gurobi13.0.0_R.tar.gz
fi

# Verify the checksum
echo "Verifying checksum..."
echo "$CHECKSUM  gurobi13.0.0_R.tar.gz" | shasum -a 256 -c -

# 2. Untar gurobi13.0.0_R.tar.gz
echo "Untarring gurobi13.0.0_R.tar.gz..."
tar -xzf gurobi13.0.0_R.tar.gz

# 3. cd into gurobiR/gurobi and build/install
echo "Building and installing gurobi package..."
cd gurobiR/gurobi
R CMD build .
R CMD INSTALL gurobi_13.0-0.tar.gz

echo "Successfully installed gurobi R package."

