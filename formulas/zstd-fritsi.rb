class ZstdFritsi < Formula
  desc "Zstandard is a real-time compression algorithm"
  homepage "https://facebook.github.io/zstd/"

  url "https://github.com/facebook/zstd/archive/v1.5.5.tar.gz"
  mirror "http://fresh-center.net/linux/misc/zstd-1.5.5.tar.gz"
  mirror "http://fresh-center.net/linux/misc/legacy/zstd-1.5.5.tar.gz"
  sha256 "98e9c3d949d1b924e28e01eccb7deed865eefebf25c2f21c702e5cd5b63b85e1"

  license "BSD-3-Clause"

  revision 2

  keg_only "This is a custom fork, so we do not want to symlink it into brew --prefix"

  depends_on "cmake" => :build
  depends_on "pkg-config" => :build

  depends_on "lz4"
  depends_on "xz"
  depends_on "zlib"

  def install
    %w[lz4 xz zlib].each do |name|
      add_lib_to_compiler_flags(Formula[name].opt_prefix)
    end

    args = [
      "-DCMAKE_BUILD_TYPE=Release",
      "-DCMAKE_CXX_STANDARD=11",
      "-DCMAKE_VERBOSE_MAKEFILE=ON",
      "-DCMAKE_FIND_FRAMEWORK=LAST",
      "-DBUILD_TESTING=OFF",
      "-Wno-dev",
      "-DCMAKE_INSTALL_PREFIX=#{prefix}",
      "-DCMAKE_INSTALL_LIBDIR=#{prefix}/lib",
      "-DCMAKE_INSTALL_BINDIR=#{prefix}/bin",
      "-DCMAKE_INSTALL_SBINDIR=#{prefix}/sbin",
      "-DCMAKE_INSTALL_DATAROOTDIR=#{prefix}/share",
      "-DCMAKE_INSTALL_SYSCONFDIR=#{prefix}/etc",
      "-DCMAKE_INSTALL_LOCALSTATEDIR=#{prefix}/var",
      "-DCMAKE_INSTALL_MANDIR=#{prefix}/share/man",
      "-DCMAKE_PREFIX_PATH=#{ENV["CMAKE_PREFIX_PATH"]}",
      "-DCMAKE_INCLUDE_PATH=#{ENV["CMAKE_INCLUDE_PATH"]}",
      "-DCMAKE_LIBRARY_PATH=#{ENV["CMAKE_LIBRARY_PATH"]}",
      "-DCMAKE_INSTALL_RPATH=#{ENV["CMAKE_INSTALL_RPATH"]}",
      "-DZSTD_BUILD_CONTRIB=ON",
      "-DZSTD_LEGACY_SUPPORT=ON",
      "-DZSTD_LZ4_SUPPORT=ON",
      "-DZSTD_LZMA_SUPPORT=ON",
      "-DZSTD_PROGRAMS_LINK_SHARED=ON",
      "-DZSTD_ZLIB_SUPPORT=ON"
    ]

    system "cmake", "-S", "build/cmake", "-B", "builddir", *args
    system "cmake", "--build", "builddir"
    system "cmake", "--install", "builddir"
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
