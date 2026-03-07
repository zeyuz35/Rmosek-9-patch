#!/usr/bin/env bash
#
# patch_rmosek_9.2.sh
#
# Patches Rmosek 9.2.48 to work with R Matrix >= 1.6-2.
# Produces Rmosek_9.2.48-1.tar.gz in the same directory.
#
# Fixes applied (Matrix-interface only; MOSEK 9.2 C API calls are unchanged):
#  1. DESCRIPTION               - version 9.2.48 -> 9.2.48-1 (via sed;
#                                 original has CRLF line endings)
#  2. R/toCSCMatrix.R            - modern Matrix coercion paths;
#                                 add toSTMatrix() function
#  3. src/rmsk_obj_matrices.cc  - replace Matrix_isclass_Csparse()
#                                 with R_check_class_etc()-based helper
#  4. src/rmsk_obj_mosek.cc      - fix Rf_error() format string
#  5. src/rmsk_msg_base.cc       - fix Rprintf/REprintf format strings
#
# NOTE: Unlike the 9.3.2 patch, the MOSEK 9.2 C API still requires:
#   - surp[] argument in MSK_getacolslice()
#   - surp[] argument in MSK_getqobj()
#   - MSK_IPAR_WRITE_DATA_PARAM (not yet renamed to MSK_IPAR_PTF_WRITE_PARAMETERS)
# These are therefore left untouched.
#
# Requirements: R, tar, patch (BSD or GNU)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_TARBALL="$SCRIPT_DIR/Rmosek_9.2.48.tar.gz"
OUT_TARBALL="$SCRIPT_DIR/Rmosek_9.2.48-1.tar.gz"

if [ ! -f "$SRC_TARBALL" ]; then
  echo "Source tarball $SRC_TARBALL not found in $SCRIPT_DIR"
  echo "Attempting to download from Mosek server..."
  curl -L -o "$SRC_TARBALL" \
       "https://download.mosek.com/R/9.2/src/contrib/Rmosek_9.2.48.tar.gz"
  if [ ! -f "$SRC_TARBALL" ]; then
    echo "ERROR: failed to obtain $SRC_TARBALL" >&2
    exit 1
  fi
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

EXPECTED_CHECKSUM="690e0166cf38ed2396666939c2fb2f21d307b42ecbd4b0f044113cc1471eac37"
ACTUAL_CHECKSUM=$(sha256sum "$SRC_TARBALL" | awk '{print $1}')
if [ "$ACTUAL_CHECKSUM" != "$EXPECTED_CHECKSUM" ]; then
  echo "ERROR: Checksum mismatch for $SRC_TARBALL" >&2
  echo "Expected: $EXPECTED_CHECKSUM" >&2
  echo "Actual:   $ACTUAL_CHECKSUM" >&2
  exit 1
fi

echo "==> Extracting $SRC_TARBALL ..."
tar xzf "$SRC_TARBALL" -C "$WORK_DIR"

# ---------------------------------------------------------------------------
# 1. DESCRIPTION: bump version.
#    Handle with sed because the original file has CRLF line endings which
#    confuse old BSD patch.
# ---------------------------------------------------------------------------
echo "==> Patching DESCRIPTION ..."
sed -i.bak 's/^Version: 9\.2\.48/Version: 9.2.48-1/' "$WORK_DIR/Rmosek/DESCRIPTION"
rm -f "$WORK_DIR/Rmosek/DESCRIPTION.bak"

# ---------------------------------------------------------------------------
# 2-5. All source / R files: apply unified diff patch.
#      Generated with:
#        diff -ruN --strip-trailing-cr v92/Rmosek rmosek92/Rmosek \
#          --exclude="*.bak" --exclude="DESCRIPTION" \
#          | sed -e "s|^--- v92/Rmosek/|--- a/|" \
#                -e "s|^+++ rmosek92/Rmosek/|+++ b/|" > rmosek92_src.patch
# ---------------------------------------------------------------------------
echo "==> Applying source patch ..."
patch -p1 -d "$WORK_DIR/Rmosek" --no-backup-if-mismatch << 'PATCH_EOF'
--- a/R/toCSCMatrix.R	2021-07-16 18:53:41
+++ b/R/toCSCMatrix.R	2026-03-07 15:06:22
@@ -7,7 +7,7 @@
     # No coercion
   }
   else if (is(obj,"dgTMatrix")) {
-    obj <- as(obj,"dgCMatrix")
+    obj <- as(obj,"CsparseMatrix")
   }
   else if (is(obj,"list") && setequal(names(obj),c("i","j","v","ncol","nrow"))) {
     obj <- sparseMatrix( i=obj[['i']],
@@ -16,12 +16,41 @@
                          dims=c(obj[['nrow']], obj[['ncol']]) )
   }
   else if (canCoerce(obj,"dgCMatrix")) {
-    # Assume coercion is meaningful, and that 
+    # Assume coercion is meaningful, and that
     # users are aware of computational overhead.
-    obj <- as(obj,"dgCMatrix")
+    obj <- as(as(as(as(obj,"Matrix"),"generalMatrix"),"dMatrix"),"CsparseMatrix")
   }
   else {
     stop(paste0("Variable '", objname, "' could not be coerced to the compressed sparse column format 'dgCMatrix' from the Matrix package."))
+  }
+
+  return(obj)
+}
+
+#
+# Convert input object 'obj' to the sparse triplet format 'dgTMatrix' from the Matrix package.
+#
+toSTMatrix <- function(obj, objname) {
+  if (is(obj, "dgTMatrix")){
+    # No coercion
+  }
+  else if (is(obj,"dgCMatrix")) {
+    obj <- as(obj,"TsparseMatrix")
+  }
+  else if (is(obj,"list") && setequal(names(obj),c("i","j","v","ncol","nrow"))) {
+    tmp <- sparseMatrix( i=obj[['i']],
+                         j=obj[['j']],
+                         x=obj[['v']],
+                         dims=c(obj[['nrow']], obj[['ncol']]) )
+    obj <- as(tmp, "dgTMatrix")
+  }
+  else if (canCoerce(obj,"dgTMatrix")) {
+    # Assume coercion is meaningful, and that
+    # users are aware of computational overhead.
+    obj <- as(as(as(as(obj,"Matrix"),"generalMatrix"),"dMatrix"),"TsparseMatrix")
+  }
+  else {
+    stop(paste0("Variable '", objname, "' could not be coerced to the sparse triplet format 'dgTMatrix' from the Matrix package."))
   }
 
   return(obj)
--- a/src/rmsk_msg_base.cc	2021-07-16 18:53:41
+++ b/src/rmsk_msg_base.cc	2026-03-07 15:06:01
@@ -31,9 +31,9 @@
 #endif
   {
     if (typeERROR == strtype)
-      REprintf(str.c_str());
+      REprintf("%s", str.c_str());
     else
-      Rprintf(str.c_str());
+      Rprintf("%s", str.c_str());
   }
 }
 
--- a/src/rmsk_obj_matrices.cc	2021-07-16 18:53:41
+++ b/src/rmsk_obj_matrices.cc	2026-03-07 15:05:11
@@ -5,6 +5,20 @@
 #include "rmsk_obj_mosek.h"
 
 
+// ###################################################
+// Matrix 1.6-2 removed the following:
+// - Matrix_isclass_Csparse
+// - Matrix_isclass_triplet
+// The replacement is R_check_class_etc:
+
+static int is_dgCMatrix(SEXP x)
+{
+  static const char *valid[] = { "dgCMatrix", "" };
+  return R_check_class_etc(x, valid) >= 0;
+}
+// ###################################################
+
+
 ___RMSK_INNER_NS_START___
 using std::string;
 
@@ -48,7 +62,7 @@
   {
 
     // Read a column compressed sparse matrix using package Matrix
-    if (Matrix_isclass_Csparse(val)) {
+    if (is_dgCMatrix(val)) {
       initialized = true;
       matrixhandle.protect( val );
 
@@ -59,7 +73,7 @@
       _nnz = numeric_cast<int>( Rf_length(GET_SLOT(matrixhandle, Matrix_xSym)) );
     }
     else {
-      throw msk_exception("Internal error in dgCMatrix::R_read: Call to Matrix_isclass_Csparse returned false.");
+      throw msk_exception("Internal error in dgCMatrix::R_read: Call to is_dgCMatrix returned false.");
     }
   }
 }
--- a/src/rmsk_obj_mosek.cc	2021-07-16 18:53:41
+++ b/src/rmsk_obj_mosek.cc	2026-03-07 15:06:10
@@ -28,7 +28,7 @@
   MSKint32t major, minor, revision;
   MSK_getversion(&major, &minor, &revision);
 
-  Rf_error(("\n\n"
+  Rf_error("%s", ("\n\n"
             "A fatal error in MOSEK may have caused memory corruption!\n"
             "We strongly recommend you to save your data and restart the R session immediately.\n"
             "  VERSION: " + tostring(major) + "." +  tostring(minor) + "." + tostring(revision) + "\n"

patch -p1 -d "$WORK_DIR/Rmosek" --no-backup-if-mismatch << 'PATCH_EOF'
PATCH_EOF
# ...existing code...

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
echo "==> Running R CMD build ..."
cd "$WORK_DIR"
R CMD build Rmosek 2>&1

cp "$WORK_DIR/Rmosek_9.2.48-1.tar.gz" "$OUT_TARBALL"

echo ""
echo "Done. Output: $OUT_TARBALL"
echo ""
echo "To install (adjust MSK_HOME for your platform):"
echo "  R CMD INSTALL --configure-args=\"MSK_HOME=/opt/mosek/9.2/tools/platform/linux64x86\" \\"
echo "    \$SCRIPT_DIR/Rmosek_9.2.48-1.tar.gz"