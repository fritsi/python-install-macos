class SqliteFritsiWithX11WithOpenssl3 < Formula
  desc "Command-line interface for SQLite"
  homepage "https://sqlite.org/index.html"
  version "3.46.0"

  url "https://www.sqlite.org/2024/sqlite-autoconf-3460000.tar.gz"
  sha256 "6f8e6a7b335273748816f9b3b62bbdc372a889de8782d7f048c653a447417a7d"

  license "blessing"

  keg_only "This is a custom fork, so we do not want to symlink it into brew --prefix"

  depends_on "pkg-config" => :build

  depends_on "ncurses-fritsi"
  depends_on "readline-fritsi"
  depends_on "tcl-tk-fritsi-with-x11-with-openssl3"
  depends_on "zlib"

  def install
    %w[ncurses-fritsi readline-fritsi tcl-tk-fritsi-with-x11-with-openssl3 zlib].each do |name|
      add_lib_to_compiler_flags(Formula[name].opt_prefix)
    end

    # Transitive dependencies
    %w[bzip2 libx11 libxau libxcb libxdmcp libxext openssl@3.0].each do |name|
      add_lib_to_compiler_flags(Formula[name].opt_prefix)
    end

    ENV.append "CPPFLAGS", %w[
        -DSQLITE_ENABLE_API_ARMOR=1
        -DSQLITE_ENABLE_COLUMN_METADATA=1
        -DSQLITE_ENABLE_DBSTAT_VTAB=1
        -DSQLITE_ENABLE_FTS3=1
        -DSQLITE_ENABLE_FTS3_PARENTHESIS=1
        -DSQLITE_ENABLE_FTS5=1
        -DSQLITE_ENABLE_JSON1=1
        -DSQLITE_ENABLE_MEMORY_MANAGEMENT=1
        -DSQLITE_ENABLE_RTREE=1
        -DSQLITE_ENABLE_STAT4=1
        -DSQLITE_MAX_VARIABLE_NUMBER=250000
        -DSQLITE_USE_URI=1
    ].join(" ")

    args = [
      "--prefix=#{prefix}",
      "--disable-dependency-tracking",
      "--disable-editline",
      "--enable-dynamic-extensions",
      "--enable-fts3",
      "--enable-fts4",
      "--enable-fts5",
      "--enable-geopoly",
      "--enable-json",
      "--enable-load-extension",
      "--enable-math",
      "--enable-memsys3",
      "--enable-memsys5",
      "--enable-readline",
      "--enable-rtree",
      "--enable-session",
      "--enable-tcl",
      "--enable-threadsafe",
      "--with-tcl=#{Formula["tcl-tk-fritsi-with-x11-with-openssl3"].opt_lib}",
      "--with-readline-inc=-I#{Formula["readline-fritsi"].opt_include}",
      "--with-readline-lib=-L#{Formula["readline-fritsi"].opt_lib} -lreadline"
    ]

    system "./configure", *args
    system "make", "install"

    # Avoid rebuilds of dependants that hardcode this path
    inreplace lib / "pkgconfig/sqlite3.pc", prefix, opt_prefix
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
