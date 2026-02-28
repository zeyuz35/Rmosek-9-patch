---
format:
  html:
    embed-resources: true
---

# Patch for Rmosek 9.3.2

Older versions of the `Rmosek` package may not be compatible with the latest changes in the `Matrix` package (>= 1.6-2) and newer MOSEK 9 C APIs.
This patch updates the package to ensure compatibility.

## High-Level Overview of Changes

The included `patch_rmosek.sh` script applies the following fixes:

1. **Version Bump:** Updates the package version in `DESCRIPTION` from `9.3.2` to `9.3.2-1`.
2. **Modernize Matrix Coercions:** Updates `R/toCSCMatrix.R` to use modern `Matrix` coercion paths and adds a new `toSTMatrix()` function.
3. **Replace Deprecated Matrix Functions:** Replaces removed `Matrix_isclass_Csparse()` and `Matrix_isclass_triplet()` in `src/rmsk_obj_matrices.cc` with `R_check_class_etc`.
4. **Fix MOSEK API Function Signatures:** Updates `MSK_getacolslice()` and `MSK_getqobj()` by removing the obsolete `surp[]` argument.
5. **Fix Format Strings:** Fixes `Rf_error()`, `Rprintf()`, and `REprintf()` format strings in C++ sources to prevent potential format string vulnerabilities.
6. **Replace Removed Constants:** Replaces the removed `MSK_IPAR_WRITE_DATA_PARAM` constant with `MSK_IPAR_PTF_WRITE_PARAMETERS` in `src/rmsk_utils_interface.cc`.

## Instructions

1. Download the original `Rmosek_9.3.2.tar.gz` file from MOSEK:

   https://download.mosek.com/R/9.3/src/contrib/Rmosek_9.3.2.tar.gz

2. Download the patch script (`patch_rmosek.sh`), and place it in the same folder as the tarball.

3. Apply the patch by running the bash script in the terminal:

```bash
bash patch_rmosek.sh
```

4. The script will produce a patched tarball named `Rmosek_9.3.2-1.tar.gz` which you can then install.
