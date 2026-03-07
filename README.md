# Patches for Rmosek 9.2 and 9.3

Older releases of the `Rmosek` package are incompatible with recent versions
of the `Matrix` package (≥ 1.6‑2) and, in the case of 9.3, with the MOSEK 9
C API.  This repository contains two shell scripts that perform the required
modifications on a source tarball for either version.

* `patch_rmosek_9.2.sh` — targets the 9.2.48 release
* `patch_rmosek_9.3.sh` — targets the 9.3.2 release

Each script will look for the corresponding `Rmosek_*.tar.gz` file in the
working directory; if the archive is missing it is automatically downloaded
from the MOSEK servers.

## High‑level overview of changes

Both patch scripts carry out the same set of source edits:

1. **Version bump.**  `DESCRIPTION` is updated (e.g. `9.3.2 → 9.3.2-1`).
2. **Modernise Matrix coercions.**  `R/toCSCMatrix.R` is rewritten to use current
   `Matrix` conversion paths, and a new `toSTMatrix()` helper is added.
3. **Deprecated Matrix helpers.**  Calls to `Matrix_isclass_Csparse()`/
   `Matrix_isclass_triplet()` are replaced with an `R_check_class_etc` helper
   in `src/rmsk_obj_matrices.cc`.
4. **Adjust MOSEK API calls.**  Remove the obsolete `surp[]` argument from
   `MSK_getacolslice()` and `MSK_getqobj()` invocations.
5. **Format‑string fixes.**  Correct various uses of `Rf_error()`, `Rprintf()`
   and `REprintf()` to supply explicit `"%s"` format specifiers.
6. **Update constants.**  Replace the removed `MSK_IPAR_WRITE_DATA_PARAM` with
   `MSK_IPAR_PTF_WRITE_PARAMETERS` in `src/rmsk_utils_interface.cc`.

## Instructions

1. Choose the appropriate script for the version you wish to patch:

   1. `patch_rmosek_9.2.sh` – for the 9.2.48 source release
   2. `patch_rmosek_9.3.sh` – for the 9.3.2 source release

2. Ensure you are running the script from the directory that contains the
   patch; the script will look for a `Rmosek_*.tar.gz` archive in the same
   folder.  If the tarball isn’t present it will automatically be downloaded
   from the MOSEK website using `curl`.

3. Execute the chosen script with bash:

   ```bash
   # Mosek 9.2
   bash patch_rmosek_9.2.sh   
   # Mosek 9.3
   bash patch_rmosek_9.3.sh
   ```

4. A patched archive (`Rmosek_9.2.48-1.tar.gz` or
   `Rmosek_9.3.2-1.tar.gz`) will be created in the current directory.

### Installing the patched package

Before installation, ensure the following environment variables point to your
MOSEK installation (either export them in the shell or pass via the
`configure.vars`/`--configure-args` mechanism):

* `MSK_BINDIR` – binary directory containing `mosek` executables
* `MSK_HEADERDIR` – include directory for MOSEK headers
* `MSK_LIB` – name of the MOSEK library (e.g. `libmosek64`)

Example using R’s `install.packages()`:

```r
install.packages(
  "Rmosek_9.3.2-1.tar.gz",  # substitute appropriate file
  type = "source",
  configure.vars = paste0(
    "MSK_BINDIR=/usr/local/mosek/9.3/tools/platform/osxaarch64/bin ",
    "MSK_HEADERDIR=/usr/local/mosek/9.3/tools/platform/osxaarch64/h ",
    "MSK_LIB=libmosek64"
  )
)
```

Or from the shell:

```bash
R CMD INSTALL --configure-args="MSK_BINDIR=/usr/local/mosek/9.3/tools/platform/osxaarch64/bin \
                                MSK_HEADERDIR=/usr/local/mosek/9.3/tools/platform/osxaarch64/h \
                                MSK_LIB=libmosek64" \
  Rmosek_9.3.2-1.tar.gz
```