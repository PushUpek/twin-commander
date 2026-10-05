#!/usr/bin/env bash
# Exercise actual APT metadata consumption and RPM signature verification.
set -euo pipefail
site=$(cd "${1:?Repository directory is required}" && pwd)
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT
mkdir -p "$test_root/lists/partial" "$test_root/cache/archives/partial" "$test_root/rpmdb"
touch "$test_root/status"
printf 'deb [signed-by=%s/signing-key.gpg] file:%s/apt stable main\n' "$site" "$site" > "$test_root/sources.list"
apt_options=(
  -o "Dir::Etc::sourcelist=$test_root/sources.list"
  -o "Dir::Etc::sourceparts=-"
  -o "Dir::State::lists=$test_root/lists"
  -o "Dir::State::status=$test_root/status"
  -o "Dir::Cache=$test_root/cache"
  -o APT::Sandbox::User="$(id -un)"
  -o APT::Architecture=amd64
  -o APT::Get::List-Cleanup=0
)
apt-get "${apt_options[@]}" update --error-on=any
apt-cache "${apt_options[@]}" show twin-commander | tee "$test_root/package-info"
test -s "$test_root/package-info"
(
  cd "$test_root"
  apt-get "${apt_options[@]}" download twin-commander
  dpkg-deb --info ./*.deb
)
rpm --dbpath "$test_root/rpmdb" --import "$site/signing-key.asc"
for package in "$site"/rpm/packages/*.rpm; do
  rpm --dbpath "$test_root/rpmdb" --checksig "$package"
  signature=$(rpm -qp --queryformat '%{RSAHEADER:pgpsig}' "$package")
  [[ $signature != '(none)' ]]
done
