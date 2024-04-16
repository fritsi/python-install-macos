class NcursesFritsi < Formula
  desc "Text-based UI library"
  homepage "https://invisible-island.net/ncurses/announce.html"
  version "6.4"

  url "https://ftp.gnu.org/gnu/ncurses/ncurses-6.4.tar.gz"
  mirror "https://invisible-mirror.net/archives/ncurses/ncurses-6.4.tar.gz"
  mirror "ftp://ftp.invisible-island.net/ncurses/ncurses-6.4.tar.gz"
  mirror "https://ftpmirror.gnu.org/ncurses/ncurses-6.4.tar.gz"
  sha256 "6931283d9ac87c5073f30b6290c4c75f21632bb4fc3603ac8100812bed248159"

  license "MIT"

  keg_only "This is a custom fork, so we do not want to symlink it into brew --prefix"

  depends_on "pkg-config" => :build

  def install
    (lib / "pkgconfig").mkpath

    args = [
      "--prefix=#{prefix}",
      "--enable-const",
      "--enable-echo",
      "--enable-ext-colors",
      "--enable-ext-mouse",
      "--enable-ext-putwin",
      "--enable-pc-files",
      "--enable-rpath",
      "--enable-sigwinch",
      "--enable-sp-funcs",
      "--enable-symlinks",
      "--enable-tcap-names",
      "--enable-term-driver",
      "--enable-termcap",
      "--enable-wgetch-events",
      "--enable-widec",
      "--with-cxx-shared",
      "--with-gpm",
      "--with-pkg-config-libdir=#{lib}/pkgconfig",
      "--with-shared",
      "--with-versioned-syms",
      "--with-xterm-kbs=del",
      "--with-default-terminfo-dir=#{share}/terminfo",
      "--with-terminfo-dirs=#{share}/terminfo",
      "--disable-pkg-ldflags",
      "--disable-relink",
      "--disable-stripping",
      "--disable-wattr-macros",
      "--without-ada",
      "--without-debug",
      "--without-profile"
    ]

    system "./configure", *args
    system "make", "install"

    make_libncurses_symlinks
  end

  def make_libncurses_symlinks
    major = version.major.to_s

    %w[form menu panel ncurses ncurses++].each do |name|
      lib.install_symlink shared_library("lib#{name}w", major) => shared_library("lib#{name}")
      lib.install_symlink shared_library("lib#{name}w", major) => shared_library("lib#{name}", major)

      lib.install_symlink "lib#{name}w.a" => "lib#{name}.a"

      (lib / "pkgconfig").install_symlink "#{name}w.pc" => "#{name}.pc"
    end

    lib.install_symlink "libncurses.a" => "libcurses.a"

    lib.install_symlink shared_library("libncurses") => shared_library("libcurses")

    # Creating extra symlinks for libtermcap
    lib.install_symlink shared_library("libncursesw", major) => shared_library("libtermcap")
    lib.install_symlink shared_library("libncursesw", major) => shared_library("libtermcap", major)

    # Creating extra symlinks for libtinfo
    lib.install_symlink shared_library("libncursesw", major) => shared_library("libtinfo")
    lib.install_symlink shared_library("libncursesw", major) => shared_library("libtinfo", major)

    %w[form menu panel curses ncurses term termcap].each do |name|
      include.install_symlink "ncursesw/#{name}.h" => "#{name}.h"
    end

    include.install_symlink "ncursesw" => "ncurses"

    bin.install_symlink "ncursesw#{major}-config" => "ncurses#{major}-config"
  end
end
