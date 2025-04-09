## Description

This repository provides scripts that assist in compiling Python from source for both Apple Intel and Apple Silicon
platforms.

**Supported Python versions:** `2.7.18`**,** `3.6.15`**,** `3.7.17`**,** `3.8.20`**,** `3.9.22`**,** `3.10.17`
**,** `3.11.12`**,** `3.12.10`.

For older Python versions, specific changes have been incorporated from newer Python releases to ensure compatibility
with recent macOS versions and Apple Silicon hardware. _See [patches](patches)._

**Tested on Apple Intel macOS Big Sur, and Sonoma and Apple M1 macOS Ventura.**

## Usage

**Usage:**

```shell
./install-python-macos.sh --help
```

or

```shell
./install-python-macos.sh {pythonVersion} {installBaseDir}
                          [--dry-run]
                          [--non-interactive]
                          [--extra-links]
                          [--use-x11]
                          [--keep-working-dir]
                          [--keep-test-logs]
```

Running this script will download the specified version of the Python source code, compile it, and install it in the
designated location.

**NOTE:** Currently, only macOS is supported!

The provided `installBaseDir` is **not** the final installation directory, but a sub-directory within it. For example,
for Python 3.8, it will be `{installBaseDir}/python-3.8`.

<ins>**Optional arguments:**</ins>

* **--dry-run** - Only the commands that would be executed will be printed. **NOTE:** Collection of GNU binaries will
  still be performed.

* **--non-interactive** - If provided, **no** confirmation prompts will be displayed.

* **--extra-links** - For Python 3, this option creates additional symbolic links for pip3, python3, and virtualenv3,
  in addition to pip3.x, python3.x, and virtualenv3.x.

* **--use-x11** - This will instruct the compiler to use X11 instead of the macOS Aqua windowing system. I
  <ins>**highly advise**</ins> to use this option. _See more information in the [About X11](#about-x11) section._

* **--keep-working-dir** - The temporary working directory will be retained after script completion or exit.

* **--keep-test-logs** - The test log file will be preserved even if all tests pass.

The script will prompt you to choose whether you want to run the Python tests or not. This allows you to verify the
integrity of the compiled Python installation.

**If you followed the instructions, there should be no failures.** _(*)_

In case of encountering any test failures, the script will halt and prompt you for further action.

**NOTE:** In non-interactive mode, the script will always run the tests.

**NOTE 2:** During the test execution, you may see a pop-up window requesting permission for Python to connect to the
network. This is related to socket/ssl tests and is safe to allow.

_(*) Regrettably, this doesn't hold fully accurate for macOS if you do not use X11 (see the [About X11](#about-x11)
section). Should you come across failures in any of the following tests if you are not using X11: test_idle, test_tk,
test_tkinter, test_ttk, test_ttk_guionly; it's advised to disregard them. These tests involve the Tcl-Tk UI and are
affected by numerous unresolved bugs specifically concerning macOS' Aqua windowing system's Tcl-Tk compatibility._

## Requirements

The `installBaseDir` must be a directory with write access. Once you compile and install Python in this directory, it
cannot be moved. If you wish to relocate it, you must recompile Python in the desired new directory.

**You need to install several dependencies using Homebrew:**

```shell
brew install asciidoc autoconf bzip2 coreutils diffutils expat findutils gawk \
             gcc gdbm gnu-sed gnu-tar gnu-which gnunet grep jq libffi libtool \
             libx11 libxcrypt lzo mpdecimal openssl@1.1 openssl@3.0 p7zip \
             pkg-config unzip wget xz zlib
```

The above command **not** only installs libraries but also some **GNU** executables. These executables are not used by
default, but [search-libraries.sh](libraries/search-libraries.sh) will temporarily add them to the `PATH`.

These dependencies are helpful because the default macOS counterparts may be outdated in certain cases, and may not
work as expected.

I also **recommend** executing `brew update` and `brew upgrade` as well before you start the installation.

Some [additional dependencies](formulas/README.md) will be automatically installed by the installer script itself.

### About X11

[Tcl-Tk](https://www.tcl.tk/) has the capability to use the macOS Aqua windowing system. However, in recent macOS
versions, Apple has consistently introduced compatibility issues. When Tcl-Tk is used with Aqua, you may encounter
segmentation faults and various other errors. Within the [patches/tcl-tk](patches/tcl-tk) directory, I've selectively
cherry-picked several fixes from unreleased Tcl-Tk versions, although these may not resolve all issues. For instance,
on macOS Ventura, segmentation faults still occur quite frequently.

An alternative approach is to opt for X11 in place of the Aqua windowing system. While Tcl-Tk UIs created with Python
may appear slightly less polished, this choice ensures stability. If you find the appearance of UIs under X11
unsatisfactory, you have the option to select from various Tk themes to enhance their visual design.

To use X11 on macOS, you need install [XQuartz](https://formulae.brew.sh/cask/xquartz) via Homebrew. This facilitates
seamless X11 integration with macOS. When running the Python installer script, remember to use the `--use-x11` command
line argument _(as previously mentioned)_ to activate X11 support. This configuration has proven to eliminate
segmentation faults when executing Python Tcl-Tk related Python test cases. **If you install XQuartz, make sure to
reboot your macOS after.** 
