#!/bin/bash

# Script to patch Rmosek_9.3.2.tar.gz and create Rmosek_9.3.2-1.tar.gz

set -e

# Download link
DOWNLOAD_URL="https://download.mosek.com/R/9.3/src/contrib/Rmosek_9.3.2.tar.gz"
TARBALL="Rmosek_9.3.2.tar.gz"

# Check if the original tarball exists, download if not
if [ ! -f "$TARBALL" ]; then
    echo "Tarball not found. Downloading from $DOWNLOAD_URL..."
    if command -v wget &> /dev/null; then
        wget -O "$TARBALL" "$DOWNLOAD_URL"
    elif command -v curl &> /dev/null; then
        curl -L -o "$TARBALL" "$DOWNLOAD_URL"
    else
        echo "Error: Neither wget nor curl found. Please install one of them or download manually."
        exit 1
    fi
    echo "Download complete."
else
    echo "Using existing $TARBALL"
fi

# Create a temporary directory for extraction
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo "Extracting Rmosek_9.3.2.tar.gz..."
tar -xzf Rmosek_9.3.2.tar.gz -C "$TEMP_DIR"

# Navigate to the extracted directory
RMOSEK_DIR="$TEMP_DIR/Rmosek"

echo "Applying patches..."

# Patch local_stubs.h - Add function pointer declaration
cat > "$RMOSEK_DIR/src/local_stubs.h" << 'EOF'
#ifndef RMSK_LOCAL_STUBS_H_
#define RMSK_LOCAL_STUBS_H_

#include <R.h>
#include <R_ext/Rdynload.h>
#include <Rdefines.h>
#include <Rconfig.h>
#include <Rversion.h>
#include "cholmod.h"
#include "Matrix.h"

/* Function pointers for Matrix package */
extern int (*Matrix_isclass_Csparse)(SEXP);

namespace MSK4 {
  namespace MSK3 {
    namespace MSK2 {
      namespace MSK1 {
        extern cholmod_common chol;
      }
    }
  }
}

#endif /* RMSK_LOCAL_STUBS_H_ */
EOF

# Patch local_stubs.cc - Initialize function pointer
cat > "$RMOSEK_DIR/src/local_stubs.cc" << 'EOF'
#include "rmsk_msg_base.h"
#include "local_stubs.h"

#include "Matrix_stubs.c"

/* Initialize function pointers from Matrix package */
int (*Matrix_isclass_Csparse)(SEXP) = NULL;

namespace MSK4 {
  namespace MSK3 {
    namespace MSK2 {
      namespace MSK1 {
        cholmod_common chol;
      }
    }
  }
}
EOF

# Patch rmsk_obj_matrices.cc - Dereference function pointer in the call
sed -i 's/if (Matrix_isclass_Csparse(val))/if ((*Matrix_isclass_Csparse)(val))/' "$RMOSEK_DIR/src/rmsk_obj_matrices.cc"

echo "Creating new tarball: Rmosek_9.3.2-1.tar.gz..."
tar -czf Rmosek_9.3.2-1.tar.gz -C "$TEMP_DIR" Rmosek

echo "Successfully created Rmosek_9.3.2-1.tar.gz"
echo "Done!"
