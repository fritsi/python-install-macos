## Description

This folder contains additional Python dependencies which are modified versions of corresponding Homebrew formulas.

### libffi33

This is an older version of libffi that is required for Python versions below 3.8, as newer libffi versions are incompatible with them.

### ncurses, readline, gettext

To avoid linking the outdated system `ncurses` library to Python, we forked these formulas from Homebrew.

We made `readline` and `gettext` utilize `ncurses` from Homebrew, thereby indirectly linking Homebrew's `ncurses` to Python.

### zstd

This formula was forked to ensure that additional dependencies are also linked to Homebrew.

### libzip, tcl-tk, sqlite

These formulas had to be forked because they are built with OpenSSL 1.1 by default.
However, starting from Python 3.8, we can use OpenSSL 3 during the build process.

Consequently, we provide both OpenSSL 1.1 and OpenSSL 3 versions here.
Depending on the Python version you are compiling, you need to install the corresponding version.

## How to install these formulas

You can easily install these formulas by running the following command:

```shell
brew install --formula --build-from-source {formula_file}
```

## What to install

The following dependencies are **required** and the must be installed in the following order:

* [ncurses-fritsi-mod](ncurses-fritsi-mod.rb),
* [readline-fritsi-mod](readline-fritsi-mod.rb),
* [gettext-fritsi-mod](gettext-fritsi-mod.rb),
* [zstd-fritsi-mod](zstd-fritsi-mod.rb).

If you are compiling **Python 3.8 or above**, you also need to install

* [libzip-fritsi-mod-with-openssl3](libzip-fritsi-mod-with-openssl3.rb),
* [tcl-tk-fritsi-mod-with-openssl3](tcl-tk-fritsi-mod-with-openssl3.rb),
* [sqlite-fritsi-mod-with-openssl3](sqlite-fritsi-mod-with-openssl3.rb).

Again, make sure to follow this exact order.

If you are compiling **Python 3.7 or below**, you will need

* [libzip-fritsi-mod](libzip-fritsi-mod.rb),
* [tcl-tk-fritsi-mod](tcl-tk-fritsi-mod.rb),
* [sqlite-fritsi-mod](sqlite-fritsi-mod.rb),
* fFurthermore, you must also install [libffi33](libffi33.rb).

**Failure to manually install these dependencies will result in a failed Python installation.**
