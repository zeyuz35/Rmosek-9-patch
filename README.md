---
format:
  html:
    embed-resources: true
---

# Patch for Rmosek 9.3.2

Older version of the `Rmosek` package may not be compatible with the latest changes in the `Matrix` package. 
This patch updates the package to ensure compatibility by modifying the C++ code to use function pointers for better integration with the `Matrix` package.

Instructions:

1. Download the original `Rmosek_9.3.2.tar.gz` file from

https://download.mosek.com/R/9.3/src/contrib/Rmosek_9.3.2.tar.gz

2. Download the patch, and place it in the same folder at the tarball. 

3. Apply the patch by running the `patch` command in the terminal:

```bash
patch -p1 < /path/to/patch_rmosek.sh
```