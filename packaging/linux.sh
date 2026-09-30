#!/usr/bin/env bash
set -euo pipefail

: "${VERSION:?VERSION is required}"
version=${VERSION#v}
if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "VERSION must be a v-prefixed semantic version (for example v1.2.3)" >&2
  exit 1
fi

mkdir -p dist
chmod +x stage/bin/twin-commander

# Debian package
deb_root=$(mktemp -d)
trap 'rm -rf "$deb_root"' EXIT
install -Dm755 stage/bin/twin-commander "$deb_root/usr/bin/twin-commander"
mkdir -p "$deb_root/usr/share/twin-commander"
cp -R stage/share/twin-commander/themes "$deb_root/usr/share/twin-commander/"
mkdir -p "$deb_root/DEBIAN"
cat > "$deb_root/DEBIAN/control" <<EOF
Package: twin-commander
Version: $version
Section: utils
Priority: optional
Architecture: amd64
Maintainer: PushUpek <https://github.com/PushUpek>
Description: Two-panel terminal file manager written in Odin
EOF
dpkg-deb --build --root-owner-group "$deb_root" "dist/twin-commander_${version}_amd64.deb"

# RPM package
rpm_root=$(mktemp -d)
trap 'rm -rf "$deb_root" "$rpm_root"' EXIT
mkdir -p "$rpm_root"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
tar -C stage -czf "$rpm_root/SOURCES/twin-commander.tar.gz" bin share
cat > "$rpm_root/SPECS/twin-commander.spec" <<EOF
Name: twin-commander
Version: $version
Release: 1
Summary: Two-panel terminal file manager written in Odin
License: Unspecified
URL: https://github.com/PushUpek/twin-commander
Source0: twin-commander.tar.gz
BuildArch: x86_64

%description
Two-panel terminal file manager written in Odin.

%prep
%setup -q -c -T
tar -xzf %{SOURCE0}

%install
install -Dm755 bin/twin-commander %{buildroot}/usr/bin/twin-commander
mkdir -p %{buildroot}/usr/share/twin-commander
cp -R share/twin-commander/themes %{buildroot}/usr/share/twin-commander/

%files
/usr/bin/twin-commander
/usr/share/twin-commander/themes
EOF
rpmbuild --define "_topdir $rpm_root" -bb "$rpm_root/SPECS/twin-commander.spec"
cp "$rpm_root"/RPMS/x86_64/*.rpm dist/

# AppImage. It starts the application in a terminal from desktop launchers.
appimage_root=$(mktemp -d)
appdir="$appimage_root/TwinCommander.AppDir"
trap 'rm -rf "$deb_root" "$rpm_root" "$appimage_root"' EXIT
mkdir -p "$appdir/usr/bin" "$appdir/usr/share/twin-commander"
cp stage/bin/twin-commander "$appdir/usr/bin/"
cp -R stage/share/twin-commander/themes "$appdir/usr/share/twin-commander/"
cp packaging/twin-commander.desktop packaging/twin-commander.svg "$appdir/"
cat > "$appdir/AppRun" <<'EOF'
#!/bin/sh
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec "$here/usr/bin/twin-commander" "$@"
EOF
chmod +x "$appdir/AppRun"
curl --fail --location --retry 3 \
  https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage \
  --output "$appimage_root/appimagetool.AppImage"
chmod +x "$appimage_root/appimagetool.AppImage"
(
  cd "$appimage_root"
  ./appimagetool.AppImage --appimage-extract >/dev/null
)
ARCH=x86_64 "$appimage_root/squashfs-root/AppRun" "$appdir" "$PWD/dist/twin-commander-${version}-x86_64.AppImage"
