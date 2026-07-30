# Homebrew formula for repixel.
#
# This file does NOT belong in this repository once you publish it — copy it
# into your tap repo as Formula/repixel.rb. It lives here so it's versioned
# alongside the script it installs. See README.md in this directory.
#
# Fill in the sha256 (and bump the url's tag) before using.

class Repixel < Formula
  desc "Recolor and upscale pixel art and animations without blurring"
  homepage "https://github.com/dithernaut/repixel"
  url "https://github.com/dithernaut/repixel/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "575f7c73d5e52099bcb8140ed5ce6073a5a60e7a468a71e55bb9615cd57f77d6"
  license "MIT"

  depends_on "ffmpeg"
  depends_on "imagemagick"
  depends_on "webp"

  def install
    bin.install "repixel"
    # The script looks for themes.conf in ../share/repixel relative to itself,
    # which is exactly pkgshare — so this is all the wiring it needs.
    pkgshare.install "themes.conf"
  end

  def caveats
    <<~EOS
      The bundled themes live in:
        #{pkgshare}/themes.conf

      That file is replaced on upgrade. To keep your own themes, copy it to:
        ~/.config/repixel/themes.conf

      repixel prefers that copy when it exists.
    EOS
  end

  test do
    # A 2px image with exactly two shades, recolored to two known colors.
    system formula_opt_bin("imagemagick")/"magick",
           "-size", "2x1", "gradient:black-white", "-depth", "8", testpath/"in.png"

    system bin/"repixel", testpath/"in.png",
           "-p", "112233,445566", "-x", "1", "--formats", "png",
           "-o", testpath/"out"

    assert_path_exists testpath/"out/in/custom/in_custom_1x.png"
  end
end
