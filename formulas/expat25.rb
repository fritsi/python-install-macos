class Expat25 < Formula
  desc "XML 1.0 parser"
  homepage "https://libexpat.github.io/"
  version "2.5.0"

  url "https://github.com/libexpat/libexpat/releases/download/R_2_5_0/expat-2.5.0.tar.xz"
  sha256 "ef2420f0232c087801abf705e89ae65f6257df6b7931d37846a193ef2e8cdcbe"

  license "MIT"

  keg_only "This is a custom fork, so we do not want to symlink it into brew --prefix"

  depends_on "pkg-config" => :build

  def install
    cd "expat" if build.head?
    system "autoreconf", "-fiv" if build.head?
    args = ["--mandir=#{man}"]
    args << "--with-docbook" if build.head?
    system "./configure", *std_configure_args, *args
    system "make", "install"
  end
end
