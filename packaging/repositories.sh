#!/usr/bin/env bash
# Run on Linux with apt-utils, createrepo-c, rpm and gnupg installed.
set -euo pipefail
: "${REPOSITORY_SIGNING_KEY:?Set the ASCII-armored private signing key}"
: "${REPOSITORY_URL:?Set the public repository base URL}"
packages=${1:-dist}
output=${2:-site}
mkdir -p "$output"
output=$(cd "$output" && pwd)
packages=$(cd "$packages" && pwd)
export GNUPGHOME
GNUPGHOME=$(mktemp -d)
trap 'rm -rf "$GNUPGHOME"' EXIT
chmod 700 "$GNUPGHOME"
printf '%s' "$REPOSITORY_SIGNING_KEY" | gpg --batch --import
key=$(gpg --batch --with-colons --list-secret-keys | awk -F: '$1 == "fpr" {print $10; exit}')
test -n "$key"
sign() {
  gpg --batch --yes --pinentry-mode loopback --passphrase-fd 3 \
    --local-user "$key" "$@" 3<<<"${REPOSITORY_SIGNING_PASSPHRASE:-}"
}
gpg --batch --armor --export "$key" > "$output/signing-key.asc"
gpg --batch --export "$key" > "$output/signing-key.gpg"

# Every deployment contains the current stable packages, with matching indices.
mkdir -p "$output/apt/pool/main" "$output/apt/dists/stable/main/binary-amd64"
cp "$packages"/*.deb "$output/apt/pool/main/"
(
  cd "$output/apt"
  apt-ftparchive packages pool/main > dists/stable/main/binary-amd64/Packages
  gzip -n -9 -c dists/stable/main/binary-amd64/Packages > dists/stable/main/binary-amd64/Packages.gz
  apt-ftparchive -o APT::FTPArchive::Release::Origin=TwinCommander \
    -o APT::FTPArchive::Release::Label=TwinCommander \
    -o APT::FTPArchive::Release::Suite=stable \
    -o APT::FTPArchive::Release::Codename=stable \
    -o APT::FTPArchive::Release::Architectures=amd64 \
    -o APT::FTPArchive::Release::Components=main \
    release dists/stable > "$GNUPGHOME/Release"
  cp "$GNUPGHOME/Release" dists/stable/Release
  sign --clearsign --output dists/stable/InRelease dists/stable/Release
  sign --armor --detach-sign --output dists/stable/Release.gpg dists/stable/Release
  gpg --verify dists/stable/InRelease
)

mkdir -p "$output/rpm/packages"
cp "$packages"/*.rpm "$output/rpm/packages/"
# rpmsign uses this wrapper to support a protected key without logging its passphrase.
cat > "$GNUPGHOME/rpm-gpg" <<'EOF'
#!/usr/bin/env bash
exec gpg --pinentry-mode loopback --passphrase-fd 3 "$@" 3<<<"${REPOSITORY_SIGNING_PASSPHRASE:-}"
EOF
chmod 700 "$GNUPGHOME/rpm-gpg"
for package in "$output"/rpm/packages/*.rpm; do
  rpmsign --define "_gpg_name $key" --define "_gpg_path $GNUPGHOME" \
    --define "__gpg $GNUPGHOME/rpm-gpg" --addsign "$package"
done
createrepo_c "$output/rpm"
sign --armor --detach-sign --output "$output/rpm/repodata/repomd.xml.asc" "$output/rpm/repodata/repomd.xml"
gpg --verify "$output/rpm/repodata/repomd.xml.asc" "$output/rpm/repodata/repomd.xml"
cat > "$output/twin-commander.repo" <<EOF
[twin-commander]
name=Twin Commander
baseurl=${REPOSITORY_URL%/}/rpm
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=${REPOSITORY_URL%/}/signing-key.asc
EOF
cat > "$output/index.html" <<EOF
<!doctype html><html lang="en"><meta charset="utf-8"><title>Twin Commander packages</title>
<h1>Twin Commander packages</h1>
<p>Signed APT and RPM repositories for Linux x86-64.</p>
<p><a href="https://github.com/PushUpek/twin-commander#packages-and-releases">Installation instructions</a></p>
<p>Signing key fingerprint: <code>$key</code></p>
</html>
EOF
