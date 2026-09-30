class TwinCommander < Formula
  desc "Two-panel terminal file manager written in Odin"
  homepage "https://github.com/PushUpek/twin-commander"
  head "https://github.com/PushUpek/twin-commander.git", branch: "main"

  depends_on "odin" => :build

  def install
    system "odin", "build", "./cmd/twin-commander", "-collection:tc=.", "-out:twin-commander"
    bin.install "twin-commander"
    pkgshare.install "config/themes"
  end
end
