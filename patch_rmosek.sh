#!/usr/bin/env bash
#
# patch_rmosek.sh
#
# Patches Rmosek 9.3.2 to work with R Matrix >= 1.6-2 and MOSEK 9 C API.
# Produces Rmosek_9.3.2-1.tar.gz in the same directory.
#
# Fixes applied:
#  1. DESCRIPTION               - version 9.3.2 -> 9.3.2-1 (via sed;
#                                 original has CRLF line endings)
#  2. R/toCSCMatrix.R            - modern Matrix coercion paths;
#                                 add toSTMatrix() function
#  3. src/rmsk_obj_matrices.cc  - replace Matrix_isclass_Csparse();
#                                 fix MSK_getacolslice() (removed surp[] arg)
#  4. src/rmsk_obj_mosek.cc      - fix Rf_error() format string
#  5. src/rmsk_obj_qobj.cc       - fix MSK_getqobj() (removed surp[] arg)
#  6. src/rmsk_msg_base.cc       - fix Rprintf/REprintf format strings
#  7. src/rmsk_utils_interface.cc - replace removed MSK_IPAR_WRITE_DATA_PARAM
#
# Requirements: R, tar, patch (BSD or GNU), base64
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_TARBALL="$SCRIPT_DIR/Rmosek_9.3.2.tar.gz"
OUT_TARBALL="$SCRIPT_DIR/Rmosek_9.3.2-1.tar.gz"

if [ ! -f "$SRC_TARBALL" ]; then
  echo "ERROR: $SRC_TARBALL not found" >&2
  exit 1
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

EXPECTED_CHECKSUM="00d6347faf8eeb958ae40b4553a91748e49eb5290f5e2a2c6baf2a109bff8354"
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
sed -i.bak 's/^Version: 9\.3\.2/Version: 9.3.2-1/' "$WORK_DIR/Rmosek/DESCRIPTION"
rm -f "$WORK_DIR/Rmosek/DESCRIPTION.bak"

# ---------------------------------------------------------------------------
# 2-7. All source / R files: apply unified diff patch.
#      The patch is base64-encoded below to avoid shell quoting issues.
#      Generated with:
#        diff -ruN --strip-trailing-cr Rmosek9/Rmosek Rmosek_patched \
#          --exclude="*.bak" --exclude="DESCRIPTION" \
#          | sed -e "s|^--- Rmosek9/Rmosek/|--- a/|" \
#                -e "s|^+++ Rmosek_patched/|+++ b/|" > rmosek_src.patch
#        base64 -i rmosek_src.patch -o rmosek_src.patch.b64
# ---------------------------------------------------------------------------
echo "==> Applying source patch ..."
patch -p1 -d "$WORK_DIR/Rmosek" --no-backup-if-mismatch << 'EOF'
diff -ruN a/R/toCSCMatrix.R b/R/toCSCMatrix.R
--- a/R/toCSCMatrix.R	2021-08-17 21:08:12
+++ b/R/toCSCMatrix.R	2026-02-25 18:34:19
@@ -7,7 +7,7 @@
     # No coercion
   }
   else if (is(obj,"dgTMatrix")) {
-    obj <- as(obj,"dgCMatrix")
+    obj <- as(obj,"CsparseMatrix")
   }
   else if (is(obj,"list") && setequal(names(obj),c("i","j","v","ncol","nrow"))) {
     obj <- sparseMatrix( i=obj[['i']],
@@ -18,10 +18,39 @@
   else if (canCoerce(obj,"dgCMatrix")) {
     # Assume coercion is meaningful, and that
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
diff -ruN a/src/rmsk_msg_base.cc b/src/rmsk_msg_base.cc
--- a/src/rmsk_msg_base.cc	2021-08-17 21:08:12
+++ b/src/rmsk_msg_base.cc	2026-02-25 18:38:39
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

diff -ruN a/src/rmsk_obj_matrices.cc b/src/rmsk_obj_matrices.cc
--- a/src/rmsk_obj_matrices.cc	2021-08-17 21:08:12
+++ b/src/rmsk_obj_matrices.cc	2026-02-25 23:35:26
@@ -5,6 +5,19 @@
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
 ___RMSK_INNER_NS_START___
 using std::string;

@@ -48,7 +61,7 @@
   {

     // Read a column compressed sparse matrix using package Matrix
-    if (Matrix_isclass_Csparse(val)) {
+    if (is_dgCMatrix(val)) {
       initialized = true;
       matrixhandle.protect( val );

@@ -59,7 +72,7 @@
       _nnz = numeric_cast<int>( Rf_length(GET_SLOT(matrixhandle, Matrix_xSym)) );
     }
     else {
-      throw msk_exception("Internal error in dgCMatrix::R_read: Call to Matrix_isclass_Csparse returned false.");
+      throw msk_exception("Internal error in dgCMatrix::R_read: Call to is_dgCMatrix returned false.");
     }
   }
 }
@@ -104,11 +117,9 @@
   MSKint32t *ptrb = static_cast<MSKint32t*>(tmp->p);
   MSKint32t  *sub = static_cast<MSKint32t*>(tmp->i);
   MSKrealt   *val = static_cast<MSKrealt*>(tmp->x);
-  MSKint32t surp[1] = { numeric_cast<MSKint32t>(nzmax) };
-
   if( ncol>=1 )
   {
-    errcatch( MSK_getacolslice(task, 0, ncol, nzmax, surp,
+    errcatch( MSK_getacolslice(task, 0, ncol, nzmax,
         ptrb, ptrb+1, sub, val) );

     tmp->sorted = ( (nrow<=1) ? true : issorted(ncol,ptrb,sub) );
diff -ruN a/src/rmsk_obj_mosek.cc b/src/rmsk_obj_mosek.cc
--- a/src/rmsk_obj_mosek.cc	2021-08-17 21:08:12
+++ b/src/rmsk_obj_mosek.cc	2026-02-25 23:35:26
@@ -28,7 +28,7 @@
   MSKint32t major, minor, revision;
   MSK_getversion(&major, &minor, &revision);

-  Rf_error(("\n\n"
+  Rf_error("%s", ("\n\n"
             "A fatal error in MOSEK may have caused memory corruption!\n"
             "We strongly recommend you to save your data and restart the R session immediately.\n"
             "  VERSION: " + tostring(major) + "." +  tostring(minor) + "." + tostring(revision) + "\n"
diff -ruN a/src/rmsk_obj_qobj.cc b/src/rmsk_obj_qobj.cc
--- a/src/rmsk_obj_qobj.cc	2021-08-17 21:08:12
+++ b/src/rmsk_obj_qobj.cc	2026-02-25 23:35:26
@@ -67,14 +67,12 @@
     SEXP_Vector val;     val.initREAL(numqobjnz);    qobj_val.protect(val);
     MSKrealt *pval   = REAL(val);

-    MSKint32t surp[1] = { numqobjnz };
     MSKint32t numqobjnz_again;

     printdebug("Start Calling MSK_getqobj");

     errcatch( MSK_getqobj(task,
       numqobjnz,
-      surp,
       &numqobjnz_again,
       psubi,
       psubj,
diff -ruN a/src/rmsk_utils_interface.cc b/src/rmsk_utils_interface.cc
--- a/src/rmsk_utils_interface.cc	2021-08-17 21:08:12
+++ b/src/rmsk_utils_interface.cc	2026-02-25 23:35:26
@@ -220,10 +220,10 @@

   // Set export-parameters for whether to write all parameters
   if (options.useparam) {
-    errcatch( MSK_putintparam(task, MSK_IPAR_WRITE_DATA_PARAM,MSK_ON) );
+    errcatch( MSK_putintparam(task, MSK_IPAR_PTF_WRITE_PARAMETERS,MSK_ON) );
     errcatch( MSK_putintparam(task, MSK_IPAR_OPF_WRITE_PARAMETERS,MSK_ON) );
   } else {
-    errcatch( MSK_putintparam(task, MSK_IPAR_WRITE_DATA_PARAM,MSK_OFF) );
+    errcatch( MSK_putintparam(task, MSK_IPAR_PTF_WRITE_PARAMETERS,MSK_OFF) );
     errcatch( MSK_putintparam(task, MSK_IPAR_OPF_WRITE_PARAMETERS,MSK_OFF) );
   }

EOF

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
echo "==> Running R CMD build ..."
cd "$WORK_DIR"
R CMD build Rmosek 2>&1

cp "$WORK_DIR/Rmosek_9.3.2-1.tar.gz" "$OUT_TARBALL"

echo ""
echo "Done. Output: $OUT_TARBALL"
echo ""
echo "To install (adjust MSK_HOME for your platform):"
echo "  R CMD INSTALL --configure-args=\"MSK_HOME=/opt/mosek/9.3/tools/platform/osxaarch64\" \\"
echo "    \$SCRIPT_DIR/Rmosek_9.3.2-1.tar.gz"
