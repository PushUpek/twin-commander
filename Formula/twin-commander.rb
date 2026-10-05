class TwinCommander < Formula
  desc "Two-panel terminal file manager written in Odin"
  homepage "https://github.com/PushUpek/twin-commander"
  url "https://github.com/PushUpek/twin-commander.git",
      tag: "v0.2.1",
      revision: "bcc46b95a230c0a2cce79d80f409d297cf3e5c5f"
  version "0.2.1"
  head "https://github.com/PushUpek/twin-commander.git", branch: "main"

  depends_on "odin" => :build

  def install
    system "odin", "build", "./cmd/twin-commander", "-collection:tc=.", "-out:twin-commander"
    bin.install "twin-commander"
    bin.install_symlink "twin-commander" => "tc"
    pkgshare.install "config/themes"
  end
end
