class LibzipFritsiWithOpenssl3 < Formula
  desc "C library for reading, creating, and modifying zip archives"
  homepage "https://libzip.org/"
  version "1.11.1"

  url "https://libzip.org/download/libzip-1.11.1.tar.xz"
  sha256 "721e0e4e851073b508c243fd75eda04e4c5006158a900441de10ce274cc3b633"

  license "BSD-3-Clause"

  keg_only "This is a custom fork, so we do not want to symlink it into brew --prefix"

  depends_on "cmake" => :build
  depends_on "pkg-config" => :build

  depends_on "bzip2"
  depends_on "lz4"
  depends_on "openssl@3.0"
  depends_on "xz"
  depends_on "zlib"
  depends_on "zstd-fritsi"

  def install
    %w[bzip2 lz4 openssl@3.0 xz zlib zstd-fritsi].each do |name|
      add_lib_to_compiler_flags(Formula[name].opt_prefix)
    end

    args = [
      "-DBUILD_REGRESS=OFF",
      "-DBUILD_EXAMPLES=OFF",
      "-DBUILD_DOC=ON",
      "-DENABLE_GNUTLS=OFF",
      "-DENABLE_MBEDTLS=OFF",
      "-DENABLE_OPENSSL=ON",
      "-DCMAKE_INCLUDE_PATH=#{ENV["CMAKE_INCLUDE_PATH"]}",
      "-DCMAKE_LIBRARY_PATH=#{ENV["CMAKE_LIBRARY_PATH"]}",
      "-DCMAKE_INSTALL_RPATH=#{ENV["CMAKE_INSTALL_RPATH"]}"
    ]

    system "cmake", ".", *std_cmake_args, *args
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
