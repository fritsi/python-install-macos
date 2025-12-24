class ReadlineFritsi < Formula
  desc "Library for command-line editing"
  homepage "https://tiswww.case.edu/php/chet/readline/rltop.html"
  version "8.3.3"

  url "https://ftpmirror.gnu.org/gnu/readline/readline-8.3.tar.gz"
  mirror "https://ftp.gnu.org/gnu/readline/readline-8.3.tar.gz"
  sha256 "fe5383204467828cd495ee8d1d3c037a7eba1389c22bc6a041f627976f9061cc"

  license "GPL-3.0-or-later"

  %w[
    001 21f0a03106dbe697337cd25c70eb0edbaa2bdb6d595b45f83285cdd35bac84de
    002 e27364396ba9f6debf7cbaaf1a669e2b2854241ae07f7eca74ca8a8ba0c97472
    003 72dee13601ce38f6746eb15239999a7c56f8e1ff5eb1ec8153a1f213e4acdb29
  ].each_slice(2) do |p, checksum|
    patch :p0 do
      url "https://ftpmirror.gnu.org/gnu/readline/readline-8.3-patches/readline83-#{p}"
      mirror "https://ftp.gnu.org/gnu/readline/readline-8.3-patches/readline83-#{p}"
      sha256 checksum
    end
  end

  keg_only "This is a custom fork, so we do not want to symlink it into brew --prefix"

  depends_on "pkgconf" => :build

  depends_on "ncurses-fritsi"

  def install
    add_lib_to_compiler_flags(Formula["ncurses-fritsi"].opt_prefix)

    ENV.prepend(["LDFLAGS", "LDXXFLAGS"], "-Wl,-headerpad_max_install_names", " ")

    configure_args = [
      "--prefix=#{prefix}",
      "--enable-multibyte",
      "--with-curses",
      "bash_cv_termcap_lib=libncursesw"
    ]

    system "./configure", *configure_args

    install_args = [
      "LIBS=-lncursesw",
      "SHLIB_LIBS=-L#{Formula["ncurses-fritsi"].opt_lib} -Wl,-rpath,#{Formula["ncurses-fritsi"].opt_lib} -lncursesw"
    ]

    system "make", *install_args, "install"
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
