class TclTkFritsi < Formula
  desc "Tool Command Language"
  homepage "https://www.tcl-lang.org"
  version "8.6.16"

  url "https://downloads.sourceforge.net/project/tcl/Tcl/8.6.16/tcl8.6.16-src.tar.gz"
  mirror "https://fossies.org/linux/misc/tcl8.6.16-src.tar.gz"
  sha256 "91cb8fa61771c63c262efb553059b7c7ad6757afa5857af6265e4b0bdc2a14a5"

  license "TCL"

  keg_only "This is a custom fork, so we do not want to symlink it into brew --prefix"

  depends_on "freetype" => :build
  depends_on "pkg-config" => :build

  depends_on "libx11"
  depends_on "libxau"
  depends_on "libxcb"
  depends_on "libxdmcp"
  depends_on "libxext"
  depends_on "openssl@1.1"
  depends_on "zlib"

  resource "critcl" do
    url "https://github.com/andreas-kupries/critcl/archive/3.3.1.tar.gz"
    sha256 "d970a06ae1cdee7854ca1bc571e8b5fe7189788dc5a806bce67e24bbadbe7ae2"
  end

  resource "tcllib" do
    url "https://downloads.sourceforge.net/project/tcllib/tcllib/2.0/tcllib-2.0.tar.xz"
    sha256 "642c2c679c9017ab6fded03324e4ce9b5f4292473b62520e82aacebb63c0ce20"
  end

  resource "tcltls" do
    url "https://core.tcl-lang.org/tcltls/uv/tcltls-1.7.22.tar.gz"
    sha256 "e84e2b7a275ec82c4aaa9d1b1f9786dbe4358c815e917539ffe7f667ff4bc3b4"
  end

  resource "tk" do
    url "https://downloads.sourceforge.net/project/tcl/Tcl/8.6.16/tk8.6.16-src.tar.gz"
    mirror "https://fossies.org/linux/misc/tk8.6.16-src.tar.gz"
    sha256 "be9f94d3575d4b3099d84bc3c10de8994df2d7aa405208173c709cc404a7e5fe"
  end

  resource "itk4" do
    url "https://downloads.sourceforge.net/project/incrtcl/%5Bincr%20Tcl_Tk%5D-4-source/itk%204.1.0/itk4.1.0.tar.gz"
    sha256 "da646199222efdc4d8c99593863c8d287442ea5a8687f95460d6e9e72431c9c7"
  end

  def install
    # Remove bundled zlib
    rm_r("compat/zlib")

    %w[libx11 libxau libxcb libxdmcp libxext openssl@1.1 zlib].each do |name|
      add_lib_to_compiler_flags(Formula[name].opt_prefix)
    end

    tcl_tk_bin_dir = "#{prefix}/bin"
    tcl_tk_lib_dir = "#{prefix}/lib"
    tcl_tk_data_dir = "#{prefix}/share"

    ENV["TCL_PACKAGE_PATH"] = tcl_tk_lib_dir

    ENV["CC"] = "/usr/bin/gcc"
    ENV["CXX"] = "/usr/bin/g++"
    ENV["LD"] = "/usr/bin/g++"

    common_args = [
      "--prefix=#{prefix}",
      "--bindir=#{prefix}/bin",
      "--sbindir=#{prefix}/sbin",
      "--sysconfdir=#{prefix}/etc",
      "--localstatedir=#{prefix}/var",
      "--mandir=#{man}",
      "--enable-man-suffix"
    ]

    cd "unix" do
      args = [
        "--enable-64bit",
        "--enable-rpath",
        "--enable-shared",
        "--enable-threads",
        "--with-encoding=utf-8",
        "--with-tzdata"
      ]

      system "./configure", *common_args, "--datadir=#{tcl_tk_data_dir}", *args
      system "make"
      system "make", "install"
      system "make", "install-private-headers"
    end

    bin.install_symlink "tclsh#{version.to_f}" => "tclsh"

    ENV.prepend_path "PATH", tcl_tk_bin_dir

    system "which", "tclsh"

    add_lib_to_compiler_flags(prefix)

    resource("tk").stage do
      cd "unix" do
        args = [
          "--enable-64bit",
          "--enable-rpath",
          "--enable-shared",
          "--enable-threads",
          "--enable-aqua=yes",
          "--without-x",
          "--with-tcl=#{tcl_tk_lib_dir}"
        ]

        system "./configure", *common_args, "--datadir=#{tcl_tk_data_dir}", *args
        system "make"
        system "make", "install"
        system "make", "install-private-headers"
      end
    end

    bin.install_symlink "wish#{version.to_f}" => "wish"

    system "which", "wish"

    resource("critcl").stage do
      system "#{tcl_tk_bin_dir}/tclsh", "build.tcl", "install", "--prefix", prefix, "--bin-dir", tcl_tk_bin_dir
    end

    resource("tcllib").stage do
      system "./configure", *common_args, "--datadir=#{tcl_tk_data_dir}", "--with-tclsh=#{tcl_tk_bin_dir}/tclsh"
      system "make", "install"
      system "make", "critcl"
      # And now after 'make critcl', we need another make install
      system "make", "install"
    end

    resource("tcltls").stage do
      args = [
        "--enable-rpath",
        "--disable-sslv2",
        "--disable-sslv3",
        "--disable-tlsv1.0",
        "--disable-tlsv1.1",
        "--with-ssl=openssl",
        "--with-openssl-dir=#{Formula["openssl@1.1"].opt_prefix}",
        "--with-openssl-pkgconfig=#{Formula["openssl@1.1"].opt_lib}/pkgconfig",
        "--with-tcl=#{tcl_tk_lib_dir}"
      ]

      system "./configure", *common_args, "--datarootdir=#{tcl_tk_data_dir}", *args
      system "make"
      system "make", "install"
    end

    resource("itk4").stage do
      itcl_dir = Pathname.glob(lib / "itcl*").last

      args = [
        "--enable-64bit",
        "--enable-rpath",
        "--enable-shared",
        "--with-tcl=#{tcl_tk_lib_dir}",
        "--with-tk=#{tcl_tk_lib_dir}",
        "--with-itcl=#{itcl_dir}"
      ]

      system "./configure", *common_args, "--datarootdir=#{tcl_tk_data_dir}", *args
      system "make"
      system "make", "install"
    end
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
