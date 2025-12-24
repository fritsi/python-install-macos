## Description

Within this directory, there are additional Python dependencies. These dependencies are adapted variants of their
respective Homebrew formulas.

It's important to note that not all the formulas found in this directory will be installed. The specific ones we will
install are contingent on the Python version(s) you intend to install and whether you wish to use X11 or not.
Regarding X11, please refer to the [About X11](../README.md#about-x11) section in the main documentation.

Moreover, it's worth mentioning that **there's no need for manual installation** of these dependencies; the Python
installer script will handle the installation of the required ones.

### expat25

This is an older version of `expat` that is required for Python versions **below 3.8**, as newer `expat` (2.6.+)
versions are incompatible with them.

### libffi33

This is an older version of `libffi` that is required for Python versions **below 3.8**, as newer `libffi` versions
are incompatible with them.

### ncurses, readline, gettext

To prevent Python from being linked with the outdated system `ncurses` library, I've created custom forks of these
formulas.

Within my customized `ncurses` variant, I've made slight adjustments to the configuration parameters compared to the
original Homebrew variant. It's worth noting that `readline` and `gettext` are essential dependencies of Python, and
they also rely on `ncurses`, and that they would link with the macOS system `ncurses` by default. To address this,
I've also created custom versions of the `readline` and `gettext` formulas, ensuring they use my customized `ncurses`
variant. This ensures that all three components, namely `ncurses`, `readline`, and `gettext`, are linked to Homebrew
in the Python installation rather than the macOS system libraries.

### zstd

This formula was forked to ensure that dependencies, such as `zlib`, are linked to the Homebrew variant rather than
the macOS-native *(possibly outdated)* one.

### libzip

When I initially forked the `libzip` Homebrew formula, the official Homebrew version of it used OpenSSL 1.1. However,
Python versions `3.8` and newer are compatible with OpenSSL 3. Therefore, it became imperative to compile Python
versions `3.8` and above with OpenSSL 3. To ensure that we don't end up with a situation where both OpenSSL 1.1 and
OpenSSL 3 are linked to Python, I forked the `libzip` formula.

As of now, the official `libzip` Homebrew formula is linked with OpenSSL 3. However, the `openssl@3` formula installs
OpenSSL 3.1, which caused some test failures due to incompatibilities. Consequently, it is still necessary to fork
the `libzip` Homebrew formula, allowing us to use the `openssl@3.0` package instead of `openssl@3`. I have created
two variants of the `libzip` formula for this purpose: `libzip-fritsi.rb`, which includes OpenSSL 1.1, and
`libzip-fritsi-with-openssl3.rb`, which includes OpenSSL 3.0.

This distinction is essential because we continue to support the installation of Python `2.7`, `3.6`, and `3.7`, which
require OpenSSL 1.1. Depending on the Python version you intend to install, the Python installer script will
automatically select and install the appropriate variant of the custom `libzip` formula.

Another reason for forking the `libzip` formula was to ensure that we link some dependency libraries, such as `bzip2`
and `zlib`, from their Homebrew variants instead of relying on the ones that come with the macOS installation. This
customization ensures compatibility and consistency with the specific versions required for Python and its associated
dependencies.

### tcl-tk, sqlite

The motivations for forking the `tcl-tk` and `sqlite` Homebrew formulas closely mirror those behind forking the
`libzip` formula. My primary goal was to ensure that essential dependencies like `zlib`, `ncurses`, and `readline`
are linked from Homebrew rather than relying on the macOS-provided versions. Additionally, I encountered similar
challenges related to OpenSSL as we did with `libzip`.

Subsequently, I introduced X11 support to the Python installer script. Given that `tcl-tk` can be compiled with or
without X11 support, we now have not just two, but four distinct variants of both `tcl-tk` and `sqlite`. While the
`sqlite` package does not inherently use X11, I enabled the Tcl interface during compilation, differing from the
official Homebrew variant of `sqlite`. Consequently, the `sqlite` library now depends on `tcl-tk`. Hence, due to the
combination of OpenSSL and X11 being either enabled or disabled, we must compile four different variants of both
`tcl-tk` and `sqlite`.

It's important to note that not all four variants will be installed. The specific variants that get installed depend
on the Python version(s) you choose to install and whether you opt for X11 support or not. For more details regarding
X11 support, please refer to the [About X11](../README.md#about-x11) section in the main documentation.

## How to install these formulas

You can easily install these formulas by running a similar command:

```shell
brew install --formula --build-from-source {formulaFile}
```

### Preparations

Before installing any of these formulas, you must create a local tap, as Homebrew no longer supports installing formulas
from arbitrary locations. Run the following commands from the root directory of this repository:

```shell
rm -rf "$(brew --prefix)/Library/Taps/fritsi"
mkdir -p "$(brew --prefix)/Library/Taps/fritsi/homebrew-taps/Formula"
chmod -R 755 "$(brew --prefix)/Library/Taps/fritsi"
cp formulas/*.rb "$(brew --prefix)/Library/Taps/fritsi/homebrew-taps/Formula"/
```

## What to install

As previously mentioned, **manually installing these dependencies is not necessary** since the Python installer script
handles this task automatically. However, if you have a specific need to install these dependencies manually, you
can do so by executing the following commands from the root directory of this repository, in the **exact order**
specified.

The following dependencies are **always** required regardless of the Python version you intend to install and whether
you enable X11 support:

```shell
brew install --formula --build-from-source "$(brew --prefix)/Library/Taps/fritsi/homebrew-taps/Formula/ncurses-fritsi.rb"
brew install --formula --build-from-source "$(brew --prefix)/Library/Taps/fritsi/homebrew-taps/Formula/readline-fritsi.rb"
brew install --formula --build-from-source "$(brew --prefix)/Library/Taps/fritsi/homebrew-taps/Formula/zstd-fritsi.rb"
```

If you plan to compile **Python 3.8 or newer** <ins>with</ins> X11 support, you will also need the following packages:

```shell
brew install --formula --build-from-source "$(brew --prefix)/Library/Taps/fritsi/homebrew-taps/Formula/gettext-fritsi.rb"
brew install --formula --build-from-source "$(brew --prefix)/Library/Taps/fritsi/homebrew-taps/Formula/libzip-fritsi-with-openssl3.rb"
brew install --formula --build-from-source "$(brew --prefix)/Library/Taps/fritsi/homebrew-taps/Formula/tcl-tk-fritsi-with-x11-with-openssl3.rb"
brew install --formula --build-from-source "$(brew --prefix)/Library/Taps/fritsi/homebrew-taps/Formula/sqlite-fritsi-with-x11-with-openssl3.rb"
```

On the other hand, if you intend to compile **Python 3.8 or newer** <ins>without</ins> X11 support, the following
dependencies are required:

```shell
brew install --formula --build-from-source "$(brew --prefix)/Library/Taps/fritsi/homebrew-taps/Formula/gettext-fritsi.rb"
brew install --formula --build-from-source "$(brew --prefix)/Library/Taps/fritsi/homebrew-taps/Formula/libzip-fritsi-with-openssl3.rb"
brew install --formula --build-from-source "$(brew --prefix)/Library/Taps/fritsi/homebrew-taps/Formula/tcl-tk-fritsi-with-openssl3.rb"
brew install --formula --build-from-source "$(brew --prefix)/Library/Taps/fritsi/homebrew-taps/Formula/sqlite-fritsi-with-openssl3.rb"
```

For those compiling **Python 3.7 or earlier** <ins>with</ins> X11 support, ensure the installation of the following
packages:

```shell
brew install --formula --build-from-source "$(brew --prefix)/Library/Taps/fritsi/homebrew-taps/Formula/gettext-fritsi-021.rb"
brew install --formula --build-from-source "$(brew --prefix)/Library/Taps/fritsi/homebrew-taps/Formula/libzip-fritsi.rb"
brew install --formula --build-from-source "$(brew --prefix)/Library/Taps/fritsi/homebrew-taps/Formula/tcl-tk-fritsi-with-x11.rb"
brew install --formula --build-from-source "$(brew --prefix)/Library/Taps/fritsi/homebrew-taps/Formula/sqlite-fritsi-with-x11.rb"
brew install --formula --build-from-source "$(brew --prefix)/Library/Taps/fritsi/homebrew-taps/Formula/libffi33.rb"
brew install --formula --build-from-source "$(brew --prefix)/Library/Taps/fritsi/homebrew-taps/Formula/expat25.rb"
```

Finally, if you are compiling **Python 3.7 or earlier** <ins>without</ins> X11 support, the following dependencies
are necessary:

```shell
brew install --formula --build-from-source "$(brew --prefix)/Library/Taps/fritsi/homebrew-taps/Formula/gettext-fritsi-021.rb"
brew install --formula --build-from-source "$(brew --prefix)/Library/Taps/fritsi/homebrew-taps/Formula/libzip-fritsi.rb"
brew install --formula --build-from-source "$(brew --prefix)/Library/Taps/fritsi/homebrew-taps/Formula/tcl-tk-fritsi.rb"
brew install --formula --build-from-source "$(brew --prefix)/Library/Taps/fritsi/homebrew-taps/Formula/sqlite-fritsi.rb"
brew install --formula --build-from-source "$(brew --prefix)/Library/Taps/fritsi/homebrew-taps/Formula/libffi33.rb"
brew install --formula --build-from-source "$(brew --prefix)/Library/Taps/fritsi/homebrew-taps/Formula/expat25.rb"
```

**Failure when installing these dependencies will result in a failed Python installation.**
