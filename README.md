## Description

These scripts will help you in compiling Python from source for Apple Intel and Apple Silicon.

**Tested on Apple Intel macOS BigSur and Apple M1 macOS Montgomery.**

## Usage

**Usage:** `./install-python-macos.sh {pythonVersion} {installBaseDir}`

This script will download the given version of the Python source code, compile it, and install it to the given location.

**NOTE:** Currently only macOS is supported!

**Supported Python versions:** `2.7.18`**,** `3.6.15`**,** `3.7.14`**,** `3.8.14`**,** `3.9.14`**,** `3.10.7`.

The given `installBaseDir` will not be the final install directory, but a sub-directory in that.
For example in case of Python 3.8 it will be `{installBaseDir}/Python3.8-compiled`.

**Optional arguments:**
* **--non-interactive** - If given then we won't ask for confirmations.

* **--extra-links** - In case of Python 3 besides the pip3.x, python3.x and virtualenv3.x symbolic links, this will also create the pip3, python3 and virtualenv3 links

## Requirements

The `installBaseDir` should be a directory where you have write access.
After you've compiled and installed Python into this directory, you cannot move it from here.
If you want to move it, you need to re-compile the whole thing again into the new desired directory.

**You need to install a couple of dependencies with brew:**

```shell
brew install asciidoc autoconf bzip2 coreutils dialog diffutils findutils \
             fontconfig gawk gcc gdbm gdk-pixbuf gettext glib gmp gnu-getopt \
             gnu-indent gnu-sed gnu-tar gnu-time gnu-which gnunet gnupg \
             gnutls graphite2 grep jpeg jq libev libevent libextractor libffi \
             libgcrypt libgpg-error libidn2 libmicrohttpd libmpc libnghttp2 \
             libpng libpthread-stubs libsodium libtasn1 libtiff libtool \
             libunistring libx11 libxau libxcb libxdmcp libxext libxrender \
             lzo mpdecimal ncurses nettle nghttp2 ngrep openssl@1.1 p7zip \
             pixman pkg-config python@3.9 readline source-highlight sqlite \
             tcl-tk unbound unzip watch wget xz zlib
```

After that add the `gnu sed` installed with the above command to the `PATH` -- **IMPORTANT:** The default sed on macOS does not work with this script.

We also suggest adding the `gnu tar`, and `wget` to the PATH as that's what we've tested this script with.

**For this you need to add the following directories to the `PATH`:**
* **On Apple Intel:**
  * `/usr/local/bin`
  * `/usr/local/opt/gsed/libexec/gnubin`
  * `/usr/local/opt/gnu-tar/libexec/gnubin`

* **On Apple Silicon:**
  * `/opt/homebrew/bin`
  * `/opt/homebrew/opt/gsed/libexec/gnubin`
  * `/opt/homebrew/opt/gnu-tar/libexec/gnubin`
