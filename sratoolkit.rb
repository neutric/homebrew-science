class Sratoolkit < Formula
  desc "Data tools for INSDC Sequence Read Archive"
  homepage "https://github.com/ncbi/sra-tools"
  # doi "10.1093/nar/gkq1019"
  # tag "bioinformatics"

  url "https://github.com/ncbi/sra-tools/archive/2.8.2-1.tar.gz"
  version "2.8.2-1"
  sha256 "0f28313c648c0dfad885376e403369f3110a1f21ce47b26a215aec5d65d455b1"
  head "https://github.com/ncbi/sra-tools.git"

  bottle do
    cellar :any
    sha256 "274d6f0f8d25c79c768377aa13404583aaecb8e5a967d64df4242f0bc0018445" => :sierra
    sha256 "95e27a3f16b02e26dc85490cebc870c03c092ee1074288bcc6df1a12fdae4382" => :el_capitan
    sha256 "fb19e4c7c5d9739ff1a9af41309f75c97807c120cf8934a2323d4d58748f1236" => :yosemite
    sha256 "460a33b3a1297672a0dce6ed83b41a69ada7f9fcad6860fe39a719358c9dae60" => :x86_64_linux
  end

  depends_on "autoconf" => :build
  depends_on "libxml2"
  depends_on "libmagic" => :recommended
  depends_on "hdf5" => :recommended

  resource "ngs-sdk" do
    url "https://github.com/ncbi/ngs/archive/1.3.0.tar.gz"
    sha256 "803c650a6de5bb38231d9ced7587f3ab788b415cac04b0ef4152546b18713ef2"
  end

  resource "ncbi-vdb" do
    url "https://github.com/ncbi/ncbi-vdb/archive/2.8.2.tar.gz"
    sha256 "15c9a47a9ebaf01822c567817acd681c4a594b4ac92e8bcf08d4d580f62296a9"
  end

  def install
    ENV.deparallelize

    # Linux fix: libbz2.a(blocksort.o): relocation R_X86_64_32 against `.rodata.str1.1'
    # https://github.com/Homebrew/homebrew-science/issues/2338
    ENV["LDFLAGS"]="" if OS.linux?

    resource("ngs-sdk").stage do
      cd "ngs-sdk" do
        system "./configure", "--prefix=#{prefix}",
                              "--build=#{Pathname.pwd}/ngs-sdk-build"
        system "make"
        system "make", "test"
        system "make", "install"
      end
    end

    (buildpath/"ncbi-vdb").install resource("ncbi-vdb")
    cd "ncbi-vdb" do
      system "./configure", "--prefix=#{prefix}",
                            "--with-ngs-sdk-prefix=#{prefix}",
                            "--build=#{buildpath}/ncbi-vdb-build"
      system "make"
      system "make", "install"
    end

    inreplace "tools/copycat/Makefile", "-smagic-static", "-smagic"

    # Fix the error: undefined reference to `SZ_encoder_enabled'
    inreplace "tools/pacbio-load/Makefile", "-shdf5 ", "-shdf5 -ssz "

    system "./configure", "--prefix=#{prefix}",
                          "--with-ngs-sdk-prefix=#{prefix}",
                          "--with-ncbi-vdb-sources=#{buildpath}/ncbi-vdb",
                          "--with-ncbi-vdb-build=#{buildpath}/ncbi-vdb-build",
                          "--build=#{buildpath}/sra-tools-build"

    system "make", "VDB_SRCDIR=#{buildpath}/ncbi-vdb"
    system "make", "VDB_SRCDIR=#{buildpath}/ncbi-vdb", "install"

    rm "#{bin}/magic"
    rm_rf "#{bin}/ncbi"
    rm_rf "#{lib}64"
    rm_rf include.to_s

    pkgshare.install share/"examples"
  end

  test do
    # just download the first FASTQ read from an NCBI SRA run (needs internet connection)
    system bin/"fastq-dump", "-N", "1", "-X", "1", "SRR000001"
    assert_match "@SRR000001.1 EM7LVYS02FOYNU length=284", File.read("SRR000001.fastq")
  end
end
