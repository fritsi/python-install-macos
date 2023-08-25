## Description

This documentation provides scripts that assist in compiling Python from source for both Apple Intel and Apple Silicon platforms.

**Tested on Apple Intel macOS Big Sur and Apple M1 macOS Ventura.**

## Usage

**Usage:** `./install-python-macos.sh {pythonVersion} {installBaseDir}`

Running this script will download the specified version of the Python source code, compile it, and install it in the designated location.

**NOTE:** Currently, only macOS is supported!

**Supported Python versions:** `2.7.18`**,** `3.6.15`**,** `3.7.17`**,** `3.8.17`**,** `3.9.17`**,** `3.10.12`
**,** `3.11.4`.

The provided `installBaseDir` is not the final installation directory, but a subdirectory within it.
For example, for Python 3.8, it will be `{installBaseDir}/python-3.8`.

The script will prompt you to choose whether you want to run the Python tests or not.
This allows you to verify the integrity of the compiled Python installation.

**If you followed the instructions, there should be no failures.** _(*1)_

In case of encountering any test failures, the script will halt and prompt you for further action.

_(*1) Regrettably, this doesn't hold fully accurate for macOS on ARM systems. Should you come across failures in any of the
following tests: test_idle, test_tk, test_tkinter, test_ttk, test_ttk_guionly; it's advised to disregard them. These tests
involve the Tcl-Tk UI and are affected by numerous unresolved bug reports specifically concerning macOS on ARM._

**NOTE:** In non-interactive mode, the script will always run the tests.

**NOTE 2:** During the test execution, you may see a pop-up window requesting permission for Python to connect to the network.
This is related to socket/ssl tests and is safe to allow.

<ins>**Optional arguments:**</ins>

* **--non-interactive** - If provided, no confirmation prompts will be displayed.

* **--extra-links** - For Python 3, this option creates additional symbolic links for pip3.x, python3.x, and virtualenv3.x,
  in addition to pip3, python3, and virtualenv3.

* **--keep-working-dir** - The working directory will be retained after script completion or exit.

* **--keep-test-logs** - The test log file will be preserved even if all tests pass.

* **--dry-run** - Only the commands that would be executed will be printed. **NOTE:** Collection of GNU binaries will still be performed.

## Requirements

The `installBaseDir` must be a directory with write access.
Once you compile and install Python in this directory, it cannot be moved.
If you wish to relocate it, you must recompile Python in the desired new directory.

**You need to install several dependencies using Homebrew:**

```shell
brew install asciidoc autoconf bzip2 coreutils diffutils expat findutils gawk \
             gcc gdbm gnu-sed gnu-tar gnu-which gnunet grep jq libffi libtool \
             libx11 libxcrypt lzo mpdecimal openssl@1.1 openssl@3.0 p7zip \
             pkg-config unzip wget xz zlib
```

The above command **not** only installs libraries but also some **GNU** executables.
These executables are not used by default, but [search-libraries.sh](libraries/search-libraries.sh) will temporarily add them to the `PATH`.

These dependencies are helpful because the default macOS counterparts may be outdated in certain cases.

Once you have completed the above steps, you also **need to install [additional dependencies](formulas)**.
