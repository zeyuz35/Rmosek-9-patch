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
PATCH_B64=\
'ZGlmZiAtcnVOIGEvUi90b0NTQ01hdHJpeC5SIGIvUi90b0NTQ01hdHJpeC5SCi0tLSBhL1IvdG9D'\
'U0NNYXRyaXguUgkyMDIxLTA4LTE3IDIxOjA4OjEyCisrKyBiL1IvdG9DU0NNYXRyaXguUgkyMDI2'\
'LTAyLTI1IDE4OjM0OjE5CkBAIC03LDcgKzcsNyBAQAogICAgICMgTm8gY29lcmNpb24KICAgfQog'\
'ICBlbHNlIGlmIChpcyhvYmosImRnVE1hdHJpeCIpKSB7Ci0gICAgb2JqIDwtIGFzKG9iaiwiZGdD'\
'TWF0cml4IikKKyAgICBvYmogPC0gYXMob2JqLCJDc3BhcnNlTWF0cml4IikKICAgfQogICBlbHNl'\
'IGlmIChpcyhvYmosImxpc3QiKSAmJiBzZXRlcXVhbChuYW1lcyhvYmopLGMoImkiLCJqIiwidiIs'\
'Im5jb2wiLCJucm93IikpKSB7CiAgICAgb2JqIDwtIHNwYXJzZU1hdHJpeCggaT1vYmpbWydpJ11d'\
'LApAQCAtMTgsMTAgKzE4LDM5IEBACiAgIGVsc2UgaWYgKGNhbkNvZXJjZShvYmosImRnQ01hdHJp'\
'eCIpKSB7CiAgICAgIyBBc3N1bWUgY29lcmNpb24gaXMgbWVhbmluZ2Z1bCwgYW5kIHRoYXQgCiAg'\
'ICAgIyB1c2VycyBhcmUgYXdhcmUgb2YgY29tcHV0YXRpb25hbCBvdmVyaGVhZC4KLSAgICBvYmog'\
'PC0gYXMob2JqLCJkZ0NNYXRyaXgiKQorICAgIG9iaiA8LSBhcyhhcyhhcyhhcyhvYmosIk1hdHJp'\
'eCIpLCJnZW5lcmFsTWF0cml4IiksImRNYXRyaXgiKSwiQ3NwYXJzZU1hdHJpeCIpCiAgIH0KICAg'\
'ZWxzZSB7CiAgICAgc3RvcChwYXN0ZTAoIlZhcmlhYmxlICciLCBvYmpuYW1lLCAiJyBjb3VsZCBu'\
'b3QgYmUgY29lcmNlZCB0byB0aGUgY29tcHJlc3NlZCBzcGFyc2UgY29sdW1uIGZvcm1hdCAnZGdD'\
'TWF0cml4JyBmcm9tIHRoZSBNYXRyaXggcGFja2FnZS4iKSkKKyAgfQorCisgIHJldHVybihvYmop'\
'Cit9CisKKyMKKyMgQ29udmVydCBpbnB1dCBvYmplY3QgJ29iaicgdG8gdGhlIHNwYXJzZSB0cmlw'\
'bGV0IGZvcm1hdCAnZGdUTWF0cml4JyBmcm9tIHRoZSBNYXRyaXggcGFja2FnZS4KKyMKK3RvU1RN'\
'YXRyaXggPC0gZnVuY3Rpb24ob2JqLCBvYmpuYW1lKSB7CisgIGlmIChpcyhvYmosICJkZ1RNYXRy'\
'aXgiKSl7CisgICAgIyBObyBjb2VyY2lvbgorICB9CisgIGVsc2UgaWYgKGlzKG9iaiwiZGdDTWF0'\
'cml4IikpIHsKKyAgICBvYmogPC0gYXMob2JqLCJUc3BhcnNlTWF0cml4IikKKyAgfQorICBlbHNl'\
'IGlmIChpcyhvYmosImxpc3QiKSAmJiBzZXRlcXVhbChuYW1lcyhvYmopLGMoImkiLCJqIiwidiIs'\
'Im5jb2wiLCJucm93IikpKSB7CisgICAgdG1wIDwtIHNwYXJzZU1hdHJpeCggaT1vYmpbWydpJ11d'\
'LAorICAgICAgICAgICAgICAgICAgICAgICAgIGo9b2JqW1snaiddXSwKKyAgICAgICAgICAgICAg'\
'ICAgICAgICAgICB4PW9ialtbJ3YnXV0sCisgICAgICAgICAgICAgICAgICAgICAgICAgZGltcz1j'\
'KG9ialtbJ25yb3cnXV0sIG9ialtbJ25jb2wnXV0pICkKKyAgICBvYmogPC0gYXModG1wLCAiZGdU'\
'TWF0cml4IikKKyAgfQorICBlbHNlIGlmIChjYW5Db2VyY2Uob2JqLCJkZ1RNYXRyaXgiKSkgewor'\
'ICAgICMgQXNzdW1lIGNvZXJjaW9uIGlzIG1lYW5pbmdmdWwsIGFuZCB0aGF0IAorICAgICMgdXNl'\
'cnMgYXJlIGF3YXJlIG9mIGNvbXB1dGF0aW9uYWwgb3ZlcmhlYWQuCisgICAgb2JqIDwtIGFzKGFz'\
'KGFzKGFzKG9iaiwiTWF0cml4IiksImdlbmVyYWxNYXRyaXgiKSwiZE1hdHJpeCIpLCJUc3BhcnNl'\
'TWF0cml4IikKKyAgfQorICBlbHNlIHsKKyAgICBzdG9wKHBhc3RlMCgiVmFyaWFibGUgJyIsIG9i'\
'am5hbWUsICInIGNvdWxkIG5vdCBiZSBjb2VyY2VkIHRvIHRoZSBzcGFyc2UgdHJpcGxldCBmb3Jt'\
'YXQgJ2RnVE1hdHJpeCcgZnJvbSB0aGUgTWF0cml4IHBhY2thZ2UuIikpCiAgIH0KIAogICByZXR1'\
'cm4ob2JqKQpkaWZmIC1ydU4gYS9zcmMvcm1za19tc2dfYmFzZS5jYyBiL3NyYy9ybXNrX21zZ19i'\
'YXNlLmNjCi0tLSBhL3NyYy9ybXNrX21zZ19iYXNlLmNjCTIwMjEtMDgtMTcgMjE6MDg6MTIKKysr'\
'IGIvc3JjL3Jtc2tfbXNnX2Jhc2UuY2MJMjAyNi0wMi0yNSAxODozODozOQpAQCAtMzEsOSArMzEs'\
'OSBAQAogI2VuZGlmCiAgIHsKICAgICBpZiAodHlwZUVSUk9SID09IHN0cnR5cGUpCi0gICAgICBS'\
'RXByaW50ZihzdHIuY19zdHIoKSk7CisgICAgICBSRXByaW50ZigiJXMiLCBzdHIuY19zdHIoKSk7'\
'CiAgICAgZWxzZQotICAgICAgUnByaW50ZihzdHIuY19zdHIoKSk7CisgICAgICBScHJpbnRmKCIl'\
'cyIsIHN0ci5jX3N0cigpKTsKICAgfQogfQogCmRpZmYgLXJ1TiBhL3NyYy9ybXNrX29ial9tYXRy'\
'aWNlcy5jYyBiL3NyYy9ybXNrX29ial9tYXRyaWNlcy5jYwotLS0gYS9zcmMvcm1za19vYmpfbWF0'\
'cmljZXMuY2MJMjAyMS0wOC0xNyAyMTowODoxMgorKysgYi9zcmMvcm1za19vYmpfbWF0cmljZXMu'\
'Y2MJMjAyNi0wMi0yNSAyMzozNToyNgpAQCAtNSw2ICs1LDE5IEBACiAjaW5jbHVkZSAicm1za19v'\
'YmpfbW9zZWsuaCIKIAogCisvLyAjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMj'\
'IyMjIyMjIyMjIyMjIyMKKy8vIE1hdHJpeCAxLjYtMiByZW1vdmVkIHRoZSBmb2xsb3dpbmc6Cisv'\
'LyAtIE1hdHJpeF9pc2NsYXNzX0NzcGFyc2UKKy8vIC0gTWF0cml4X2lzY2xhc3NfdHJpcGxldAor'\
'Ly8gVGhlIHJlcGxhY2VtZW50IGlzIFJfY2hlY2tfY2xhc3NfZXRjOgorCitzdGF0aWMgaW50IGlz'\
'X2RnQ01hdHJpeChTRVhQIHgpCit7CisgIHN0YXRpYyBjb25zdCBjaGFyICp2YWxpZFtdID0geyAi'\
'ZGdDTWF0cml4IiwgIiIgfTsKKyAgcmV0dXJuIFJfY2hlY2tfY2xhc3NfZXRjKHgsIHZhbGlkKSA+'\
'PSAwOworfQorLy8gIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMj'\
'IyMjIyMjCisKIF9fX1JNU0tfSU5ORVJfTlNfU1RBUlRfX18KIHVzaW5nIHN0ZDo6c3RyaW5nOwog'\
'CkBAIC00OCw3ICs2MSw3IEBACiAgIHsKIAogICAgIC8vIFJlYWQgYSBjb2x1bW4gY29tcHJlc3Nl'\
'ZCBzcGFyc2UgbWF0cml4IHVzaW5nIHBhY2thZ2UgTWF0cml4Ci0gICAgaWYgKE1hdHJpeF9pc2Ns'\
'YXNzX0NzcGFyc2UodmFsKSkgeworICAgIGlmIChpc19kZ0NNYXRyaXgodmFsKSkgewogICAgICAg'\
'aW5pdGlhbGl6ZWQgPSB0cnVlOwogICAgICAgbWF0cml4aGFuZGxlLnByb3RlY3QoIHZhbCApOwog'\
'CkBAIC01OSw3ICs3Miw3IEBACiAgICAgICBfbm56ID0gbnVtZXJpY19jYXN0PGludD4oIFJmX2xl'\
'bmd0aChHRVRfU0xPVChtYXRyaXhoYW5kbGUsIE1hdHJpeF94U3ltKSkgKTsKICAgICB9CiAgICAg'\
'ZWxzZSB7Ci0gICAgICB0aHJvdyBtc2tfZXhjZXB0aW9uKCJJbnRlcm5hbCBlcnJvciBpbiBkZ0NN'\
'YXRyaXg6OlJfcmVhZDogQ2FsbCB0byBNYXRyaXhfaXNjbGFzc19Dc3BhcnNlIHJldHVybmVkIGZh'\
'bHNlLiIpOworICAgICAgdGhyb3cgbXNrX2V4Y2VwdGlvbigiSW50ZXJuYWwgZXJyb3IgaW4gZGdD'\
'TWF0cml4OjpSX3JlYWQ6IENhbGwgdG8gaXNfZGdDTWF0cml4IHJldHVybmVkIGZhbHNlLiIpOwog'\
'ICAgIH0KICAgfQogfQpAQCAtMTA0LDExICsxMTcsOSBAQAogICBNU0tpbnQzMnQgKnB0cmIgPSBz'\
'dGF0aWNfY2FzdDxNU0tpbnQzMnQqPih0bXAtPnApOwogICBNU0tpbnQzMnQgICpzdWIgPSBzdGF0'\
'aWNfY2FzdDxNU0tpbnQzMnQqPih0bXAtPmkpOwogICBNU0tyZWFsdCAgICp2YWwgPSBzdGF0aWNf'\
'Y2FzdDxNU0tyZWFsdCo+KHRtcC0+eCk7Ci0gIE1TS2ludDMydCBzdXJwWzFdID0geyBudW1lcmlj'\
'X2Nhc3Q8TVNLaW50MzJ0Pihuem1heCkgfTsKLQogICBpZiggbmNvbD49MSApCiAgIHsKLSAgICBl'\
'cnJjYXRjaCggTVNLX2dldGFjb2xzbGljZSh0YXNrLCAwLCBuY29sLCBuem1heCwgc3VycCwKKyAg'\
'ICBlcnJjYXRjaCggTVNLX2dldGFjb2xzbGljZSh0YXNrLCAwLCBuY29sLCBuem1heCwKICAgICAg'\
'ICAgcHRyYiwgcHRyYisxLCBzdWIsIHZhbCkgKTsKIAogICAgIHRtcC0+c29ydGVkID0gKCAobnJv'\
'dzw9MSkgPyB0cnVlIDogaXNzb3J0ZWQobmNvbCxwdHJiLHN1YikgKTsKZGlmZiAtcnVOIGEvc3Jj'\
'L3Jtc2tfb2JqX21vc2VrLmNjIGIvc3JjL3Jtc2tfb2JqX21vc2VrLmNjCi0tLSBhL3NyYy9ybXNr'\
'X29ial9tb3Nlay5jYwkyMDIxLTA4LTE3IDIxOjA4OjEyCisrKyBiL3NyYy9ybXNrX29ial9tb3Nl'\
'ay5jYwkyMDI2LTAyLTI1IDIzOjM1OjI2CkBAIC0yOCw3ICsyOCw3IEBACiAgIE1TS2ludDMydCBt'\
'YWpvciwgbWlub3IsIHJldmlzaW9uOwogICBNU0tfZ2V0dmVyc2lvbigmbWFqb3IsICZtaW5vciwg'\
'JnJldmlzaW9uKTsKIAotICBSZl9lcnJvcigoIlxuXG4iCisgIFJmX2Vycm9yKCIlcyIsICgiXG5c'\
'biIKICAgICAgICAgICAgICJBIGZhdGFsIGVycm9yIGluIE1PU0VLIG1heSBoYXZlIGNhdXNlZCBt'\
'ZW1vcnkgY29ycnVwdGlvbiFcbiIKICAgICAgICAgICAgICJXZSBzdHJvbmdseSByZWNvbW1lbmQg'\
'eW91IHRvIHNhdmUgeW91ciBkYXRhIGFuZCByZXN0YXJ0IHRoZSBSIHNlc3Npb24gaW1tZWRpYXRl'\
'bHkuXG4iCiAgICAgICAgICAgICAiICBWRVJTSU9OOiAiICsgdG9zdHJpbmcobWFqb3IpICsgIi4i'\
'ICsgIHRvc3RyaW5nKG1pbm9yKSArICIuIiArIHRvc3RyaW5nKHJldmlzaW9uKSArICJcbiIKZGlm'\
'ZiAtcnVOIGEvc3JjL3Jtc2tfb2JqX3FvYmouY2MgYi9zcmMvcm1za19vYmpfcW9iai5jYwotLS0g'\
'YS9zcmMvcm1za19vYmpfcW9iai5jYwkyMDIxLTA4LTE3IDIxOjA4OjEyCisrKyBiL3NyYy9ybXNr'\
'X29ial9xb2JqLmNjCTIwMjYtMDItMjUgMjM6MzU6MjYKQEAgLTY3LDE0ICs2NywxMiBAQAogICAg'\
'IFNFWFBfVmVjdG9yIHZhbDsgICAgIHZhbC5pbml0UkVBTChudW1xb2JqbnopOyAgICBxb2JqX3Zh'\
'bC5wcm90ZWN0KHZhbCk7CiAgICAgTVNLcmVhbHQgKnB2YWwgICA9IFJFQUwodmFsKTsKIAotICAg'\
'IE1TS2ludDMydCBzdXJwWzFdID0geyBudW1xb2JqbnogfTsKICAgICBNU0tpbnQzMnQgbnVtcW9i'\
'am56X2FnYWluOwogCiAgICAgcHJpbnRkZWJ1ZygiU3RhcnQgQ2FsbGluZyBNU0tfZ2V0cW9iaiIp'\
'OwogCiAgICAgZXJyY2F0Y2goIE1TS19nZXRxb2JqKHRhc2ssCiAgICAgICBudW1xb2JqbnosCi0g'\
'ICAgICBzdXJwLAogICAgICAgJm51bXFvYmpuel9hZ2FpbiwKICAgICAgIHBzdWJpLAogICAgICAg'\
'cHN1YmosCmRpZmYgLXJ1TiBhL3NyYy9ybXNrX3V0aWxzX2ludGVyZmFjZS5jYyBiL3NyYy9ybXNr'\
'X3V0aWxzX2ludGVyZmFjZS5jYwotLS0gYS9zcmMvcm1za191dGlsc19pbnRlcmZhY2UuY2MJMjAy'\
'MS0wOC0xNyAyMTowODoxMgorKysgYi9zcmMvcm1za191dGlsc19pbnRlcmZhY2UuY2MJMjAyNi0w'\
'Mi0yNSAyMzozNToyNgpAQCAtMjIwLDEwICsyMjAsMTAgQEAKIAogICAvLyBTZXQgZXhwb3J0LXBh'\
'cmFtZXRlcnMgZm9yIHdoZXRoZXIgdG8gd3JpdGUgYWxsIHBhcmFtZXRlcnMKICAgaWYgKG9wdGlv'\
'bnMudXNlcGFyYW0pIHsKLSAgICBlcnJjYXRjaCggTVNLX3B1dGludHBhcmFtKHRhc2ssIE1TS19J'\
'UEFSX1dSSVRFX0RBVEFfUEFSQU0sTVNLX09OKSApOworICAgIGVycmNhdGNoKCBNU0tfcHV0aW50'\
'cGFyYW0odGFzaywgTVNLX0lQQVJfUFRGX1dSSVRFX1BBUkFNRVRFUlMsTVNLX09OKSApOwogICAg'\
'IGVycmNhdGNoKCBNU0tfcHV0aW50cGFyYW0odGFzaywgTVNLX0lQQVJfT1BGX1dSSVRFX1BBUkFN'\
'RVRFUlMsTVNLX09OKSApOwogICB9IGVsc2UgewotICAgIGVycmNhdGNoKCBNU0tfcHV0aW50cGFy'\
'YW0odGFzaywgTVNLX0lQQVJfV1JJVEVfREFUQV9QQVJBTSxNU0tfT0ZGKSApOworICAgIGVycmNh'\
'dGNoKCBNU0tfcHV0aW50cGFyYW0odGFzaywgTVNLX0lQQVJfUFRGX1dSSVRFX1BBUkFNRVRFUlMs'\
'TVNLX09GRikgKTsKICAgICBlcnJjYXRjaCggTVNLX3B1dGludHBhcmFtKHRhc2ssIE1TS19JUEFS'\
'X09QRl9XUklURV9QQVJBTUVURVJTLE1TS19PRkYpICk7CiAgIH0KIAo='

echo "$PATCH_B64" | base64 -d | \
  patch -p1 -d "$WORK_DIR/Rmosek" --no-backup-if-mismatch

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
