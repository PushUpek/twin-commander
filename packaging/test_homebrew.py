"""Validate stable formula updates, reruns and rejected inputs."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class HomebrewUpdateTests(unittest.TestCase):
    def test_release_update_and_rerun(self):
        with tempfile.TemporaryDirectory() as directory:
            formula = Path(directory) / "twin-commander.rb"
            formula.write_text((ROOT / "Formula/twin-commander.rb").read_text())
            command = [sys.executable, str(ROOT / "packaging/update-homebrew.py"),
                       "v999.0.0", "a" * 40, "--formula", str(formula)]
            subprocess.run(command, check=True)
            updated = formula.read_text()
            self.assertIn('version "999.0.0"', updated)
            self.assertIn('tag: "v999.0.0"', updated)
            self.assertIn('revision: "' + "a" * 40 + '"', updated)
            self.assertIn('head "https://github.com/PushUpek/twin-commander.git", branch: "main"', updated)
            subprocess.run(command, check=True)
            self.assertEqual(formula.read_text(), updated)
            for tag, commit in [("v0.0.0", "b" * 40), ("v1.2.3-rc1", "a" * 40),
                                ('v1.2.3"', "a" * 40), ("v999.0.1", "short")]:
                with self.subTest(tag=tag, commit=commit):
                    rejected = subprocess.run(command[:2] + [tag, commit] + command[4:],
                                              capture_output=True)
                    self.assertNotEqual(rejected.returncode, 0)
                    self.assertEqual(formula.read_text(), updated)


if __name__ == "__main__":
    unittest.main()
