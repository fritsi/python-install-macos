class TclTkFritsiWithX11 < Formula
  desc "Tool Command Language"
  homepage "https://www.tcl-lang.org"

  url "https://downloads.sourceforge.net/project/tcl/Tcl/8.6.13/tcl8.6.13-src.tar.gz"
  mirror "https://fossies.org/linux/misc/tcl8.6.13-src.tar.gz"
  sha256 "43a1fae7412f61ff11de2cfd05d28cfc3a73762f354a417c62370a54e2caf066"

  license "TCL"

  revision 2

  keg_only "This is a custom fork, so we do not want to symlink it into brew --prefix"

  patch :p1 do
    url "https://raw.githubusercontent.com/fritsi/python-install-macos/master/patches/tcl-tk/tcl.patch"
    sha256 "67e4edf5625cef4209e30267edda323f50cee90f85716df50d40cea506c197c4"
  end

  depends_on "freetype" => :build
  depends_on "pkg-config" => :build

  depends_on "libx11"
  depends_on "libxau"
  depends_on "libxcb"
  depends_on "libxdmcp"
  depends_on "libxext"
  depends_on "openssl@1.1"
  depends_on "xorgproto"
  depends_on "zlib"

  resource "critcl" do
    url "https://github.com/andreas-kupries/critcl/archive/3.2.tar.gz"
    sha256 "20061944e28dda4ab2098b8f77682cab77973f8961f6fa60b95bcc09a546789e"
  end

  resource "tcllib" do
    url "https://downloads.sourceforge.net/project/tcllib/tcllib/1.21/tcllib-1.21.tar.xz"
    sha256 "10c7749e30fdd6092251930e8a1aa289b193a3b7f1abf17fee1d4fa89814762f"
  end

  resource "tcltls" do
    url "https://core.tcl-lang.org/tcltls/uv/tcltls-1.7.22.tar.gz"
    sha256 "e84e2b7a275ec82c4aaa9d1b1f9786dbe4358c815e917539ffe7f667ff4bc3b4"
  end

  resource "tk" do
    url "https://downloads.sourceforge.net/project/tcl/Tcl/8.6.13/tk8.6.13-src.tar.gz"
    mirror "https://fossies.org/linux/misc/tk8.6.13-src.tar.gz"
    sha256 "2e65fa069a23365440a3c56c556b8673b5e32a283800d8d9b257e3f584ce0675"

    patch :p1 do
      url "https://raw.githubusercontent.com/fritsi/python-install-macos/master/patches/tcl-tk/tk.patch"
      sha256 "b7ff3245d1dc7093d85351edf38f321021e47b1889d1fc550464bad35051cf45"
    end

    patch :p1 do
      url "https://raw.githubusercontent.com/fritsi/python-install-macos/master/patches/tcl-tk/tk-leak-fix.patch"
      sha256 "16d98dccba7168071462da1bc436aec5d7cc854196dc06fd33bc03a8f3302220"
    end
  end

  resource "itk4" do
    url "https://downloads.sourceforge.net/project/incrtcl/%5Bincr%20Tcl_Tk%5D-4-source/itk%204.1.0/itk4.1.0.tar.gz"
    sha256 "da646199222efdc4d8c99593863c8d287442ea5a8687f95460d6e9e72431c9c7"
  end

  def install
    %w[libx11 libxau libxcb libxdmcp libxext openssl@1.1 xorgproto zlib].each do |name|
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
      "--mandir=#{man}"
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
          "--with-x",
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
