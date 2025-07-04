class Libffi33 < Formula
  desc "Portable Foreign Function Interface library"
  homepage "https://sourceware.org/libffi/"
  version "3.3"

  url "https://github.com/libffi/libffi/releases/download/v3.3/libffi-3.3.tar.gz"
  mirror "https://sourceware.org/pub/libffi/libffi-3.3.tar.gz"
  mirror "https://deb.debian.org/debian/pool/main/libf/libffi/libffi_3.3.orig.tar.gz"

  sha256 "72fba7922703ddfa7a028d513ac15a85c8d54c8d67f55fa5a4802885dc652056"

  license "MIT"

  keg_only "This is a custom fork, so we do not want to symlink it into brew --prefix"

  depends_on "pkg-config" => :build

  on_macos do
    if Hardware::CPU.arm?
      # Improved aarch64-apple-darwin support. See https://github.com/libffi/libffi/pull/565
      # + https://github.com/libffi/libffi/issues/852
      patch do
        url "https://raw.githubusercontent.com/fritsi/python-install-macos/refs/heads/master/patches/libffi33.patch"
        sha256 "4dca7ec070198209603ae7e2ba9b1501423c0109785b7943aad9bd57a2783977"
      end
    end
  end

  def install
    system "./configure", *std_configure_args
    system "make", "install"
  end

  test do
    (testpath / "closure.c").write <<~EOS
      #include <stdio.h>
      #include <ffi.h>

      /* Acts like puts with the file given at time of enclosure. */
      void puts_binding(ffi_cif *cif, unsigned int *ret, void* args[],
                        FILE *stream)
      {
        *ret = fputs(*(char **)args[0], stream);
      }

      int main()
      {
        ffi_cif cif;
        ffi_type *args[1];
        ffi_closure *closure;

        int (*bound_puts)(char *);
        int rc;

        /* Allocate closure and bound_puts */
        closure = ffi_closure_alloc(sizeof(ffi_closure), &bound_puts);

        if (closure)
          {
            /* Initialize the argument info vectors */
            args[0] = &ffi_type_pointer;

            /* Initialize the cif */
            if (ffi_prep_cif(&cif, FFI_DEFAULT_ABI, 1,
                             &ffi_type_uint, args) == FFI_OK)
              {
                /* Initialize the closure, setting stream to stdout */
                if (ffi_prep_closure_loc(closure, &cif, puts_binding,
                                         stdout, bound_puts) == FFI_OK)
                  {
                    rc = bound_puts("Hello World!");
                    /* rc now holds the result of the call to fputs */
                  }
              }
          }

        /* Deallocate both closure, and bound_puts */
        ffi_closure_free(closure);

        return 0;
      }
    EOS

    flags = ["-L#{lib}", "-lffi", "-I#{include}"]
    system ENV.cc, "-o", "closure", "closure.c", *(flags + ENV.cflags.to_s.split)
    system "./closure"
  end
end
