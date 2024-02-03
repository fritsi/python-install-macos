class ReadlineFritsi < Formula
  desc "Library for command-line editing"
  homepage "https://tiswww.case.edu/php/chet/readline/rltop.html"
  version "8.2.7"

  url "https://ftp.gnu.org/gnu/readline/readline-8.2.tar.gz"
  mirror "https://ftpmirror.gnu.org/readline/readline-8.2.tar.gz"
  sha256 "3feb7171f16a84ee82ca18a36d7b9be109a52c04f492a053331d7d1095007c35"

  license "GPL-3.0-or-later"

  revision 2

  %w[
    001 bbf97f1ec40a929edab5aa81998c1e2ef435436c597754916e6a5868f273aff7
    002 e06503822c62f7bc0d9f387d4c78c09e0ce56e53872011363c74786c7cd4c053
    003 24f587ba46b46ed2b1868ccaf9947504feba154bb8faabd4adaea63ef7e6acb0
    004 79572eeaeb82afdc6869d7ad4cba9d4f519b1218070e17fa90bbecd49bd525ac
    005 622ba387dae5c185afb4b9b20634804e5f6c1c6e5e87ebee7c35a8f065114c99
    006 c7b45ff8c0d24d81482e6e0677e81563d13c74241f7b86c4de00d239bc81f5a1
    007 5911a5b980d7900aabdbee483f86dab7056851e6400efb002776a0a4a1bab6f6
  ].each_slice(2) do |p, checksum|
    patch :p0 do
      url "https://ftp.gnu.org/gnu/readline/readline-8.2-patches/readline82-#{p}"
      mirror "https://ftpmirror.gnu.org/readline/readline-8.2-patches/readline82-#{p}"
      sha256 checksum
    end
  end

  keg_only "This is a custom fork, so we do not want to symlink it into brew --prefix"

  depends_on "pkg-config" => :build

  depends_on "ncurses-fritsi"

  def install
    add_lib_to_compiler_flags(Formula["ncurses-fritsi"].opt_prefix)

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
