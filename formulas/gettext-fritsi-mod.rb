class GettextFritsiMod < Formula
  desc "GNU internationalization (i18n) and localization (l10n) library"
  homepage "https://www.gnu.org/software/gettext/"

  url "https://ftp.gnu.org/gnu/gettext/gettext-0.21.1.tar.gz"
  mirror "https://ftpmirror.gnu.org/gettext/gettext-0.21.1.tar.gz"
  mirror "http://ftp.gnu.org/gnu/gettext/gettext-0.21.1.tar.gz"
  sha256 "e8c3650e1d8cee875c4f355642382c1df83058bd5a11ee8555c0cf276d646d45"

  license "GPL-3.0-or-later"

  keg_only "This is a custom fork, so we do not want to symlink it into brew --prefix"

  depends_on "pkg-config" => :build

  depends_on "libxml2"
  depends_on "ncurses-fritsi-mod"

  def install
    %w[libxml2 ncurses-fritsi-mod].each do |name|
      add_lib_to_compiler_flags(Formula[name].opt_prefix)
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
      "--with-libncurses-prefix=#{Formula["ncurses-fritsi-mod"].opt_prefix}",
      "--with-libtermcap-prefix=#{Formula["ncurses-fritsi-mod"].opt_prefix}",
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
