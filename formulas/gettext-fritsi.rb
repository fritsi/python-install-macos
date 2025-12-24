class GettextFritsi < Formula
  desc "GNU internationalization (i18n) and localization (l10n) library"
  homepage "https://www.gnu.org/software/gettext/"
  version "0.26"

  url "https://ftpmirror.gnu.org/gnu/gettext/gettext-0.26.tar.gz"
  mirror "https://ftp.gnu.org/gnu/gettext/gettext-0.26.tar.gz"
  mirror "http://ftp.gnu.org/gnu/gettext/gettext-0.26.tar.gz"
  sha256 "39acf4b0371e9b110b60005562aace5b3631fed9b1bb9ecccfc7f56e58bb1d7f"

  license "GPL-3.0-or-later"

  keg_only "This is a custom fork, so we do not want to symlink it into brew --prefix"

  depends_on "pkgconf" => :build

  depends_on "libunistring"
  depends_on "libxml2"
  depends_on "ncurses-fritsi"

  def install
    # macOS iconv implementation is slightly broken since Sonoma
    # upstream bug report, https://savannah.gnu.org/bugs/index.php?66541
    ENV["am_cv_func_iconv_works"] = "yes" if MacOS.version >= :sequoia

    %w[libunistring libxml2 ncurses-fritsi].each do |name|
      add_lib_to_compiler_flags(Formula[name].opt_prefix)
    end

    ENV.prepend(["LDFLAGS", "LDXXFLAGS"], "-Wl,-headerpad_max_install_names", " ")

    # Workaround for newer Clang
    if DevelopmentTools.clang_build_version >= 1500
        ENV.append(["CFLAGS", "CXXFLAGS", "CPPFLAGS"], "-Wno-incompatible-function-pointer-types", " ")
    end

    args = [
      "--disable-silent-rules",
      "--disable-dependency-tracking",
      "--disable-csharp",
      "--disable-java",
      "--enable-c++",
      "--enable-curses",
      "--enable-rpath",
      "--enable-shared",
      "--with-emacs",
      "--with-included-glib",
      "--with-included-libcroco",
      "--with-included-libunistring",
      "--with-included-libxml",
      "--with-libncurses-prefix=#{Formula["ncurses-fritsi"].opt_prefix}",
      "--with-libtermcap-prefix=#{Formula["ncurses-fritsi"].opt_prefix}",
      "--with-libunistring-prefix=#{Formula["libunistring"].opt_prefix}",
      "--with-libxml2-prefix=#{Formula["libxml2"].opt_prefix}",
      "--without-cvs",
      "--without-git",
      "--without-libcurses-prefix",
      "--without-libxcurses-prefix",
      "--without-xz"
    ]

    system "./configure", *std_configure_args, *args
    system "make"
    ENV.deparallelize
    system "make", "install"
  end

  def add_lib_to_compiler_flags(lib_prefix)
    bin_dir = "#{lib_prefix}/bin"
    include_dir = "#{lib_prefix}/include"
    lib_dir = "#{lib_prefix}/lib"
    pkg_config_dir = "#{lib_dir}/pkgconfig"

    ENV.prepend(["CMAKE_PREFIX_PATH"], lib_prefix, ";")

    # Handling the bin dir
    if File.directory? bin_dir
      ENV.prepend(["PATH"], bin_dir, ":")
    end

    # Handling the include dir
    if File.directory? include_dir
      ENV.prepend(["CFLAGS", "CXXFLAGS", "CPPFLAGS"], "-I#{include_dir}", " ")
      ENV.prepend(["CPATH", "CMAKE_INCLUDE_PATH"], include_dir, ":")
    end

    # Handling the lib dir
    if File.directory? lib_dir
      ENV.prepend(["LDFLAGS", "LDXXFLAGS"], "-L#{lib_dir} -Wl,-rpath,#{lib_dir}", " ")
      ENV.prepend(["LIBRARY_PATH"], lib_dir, ":")
      ENV.prepend(["CMAKE_LIBRARY_PATH", "CMAKE_INSTALL_RPATH"], lib_dir, ";")
    end

    # Handling the package config dir
    if File.directory? pkg_config_dir
      ENV.prepend(["PKG_CONFIG_PATH"], pkg_config_dir, ":")
    end
  end
end
