class TwinCommander < Formula
  desc "Two-panel terminal file manager written in Odin"
  homepage "https://github.com/PushUpek/twin-commander"
  url "https://github.com/PushUpek/twin-commander.git",
      tag: "v0.2.0",
      revision: "e3643b6de0dc5883547c9e1e9f1b434aac9e150f"
  version "0.2.0"
  head "https://github.com/PushUpek/twin-commander.git", branch: "main"

  depends_on "odin" => :build

  def install
    system "odin", "build", "./cmd/twin-commander", "-collection:tc=.", "-out:twin-commander"
    bin.install "twin-commander"
    bin.install_symlink "twin-commander" => "tc"
    pkgshare.install "config/themes"
  end
end
