#!/usr/bin/env bash
# Packs the Flutter Linux bundle into a self-contained AppImage.
# libmpv and its dependencies (ffmpeg ...) are bundled, the desktop
# basics (glibc, GTK, X11/Wayland, audio servers, GPU drivers) come from
# the host system.
#   tool/make_appimage.sh <version>   (after: flutter build linux --release)
set -euo pipefail
VER="${1:-dev}"
BUNDLE=build/linux/x64/release/bundle
APPDIR=AppDir
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/lib" \
  "$APPDIR/usr/share/applications" "$APPDIR/usr/share/icons/hicolor/256x256/apps"
cp -a "$BUNDLE/." "$APPDIR/usr/bin/"

convert assets/icon/icon.png -resize 256x256 \
  "$APPDIR/usr/share/icons/hicolor/256x256/apps/slaxxfm.png"
cp "$APPDIR/usr/share/icons/hicolor/256x256/apps/slaxxfm.png" "$APPDIR/slaxxfm.png"

cat > "$APPDIR/usr/share/applications/slaxxfm.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=SlaxxFM
Comment=Free internet music radio, sorted by country
Exec=slaxxfm
Icon=slaxxfm
Categories=AudioVideo;Audio;Player;
Terminal=false
X-AppImage-Version=$VER
DESKTOP
cp "$APPDIR/usr/share/applications/slaxxfm.desktop" "$APPDIR/slaxxfm.desktop"

cat > "$APPDIR/AppRun" <<'APPRUN'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
export LD_LIBRARY_PATH="$HERE/usr/lib:$HERE/usr/bin/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$HERE/usr/bin/slaxxfm" "$@"
APPRUN
chmod +x "$APPDIR/AppRun"

# tools
[ -x linuxdeploy ] || { wget -q -O linuxdeploy \
  https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage; chmod +x linuxdeploy; }
[ -x appimagetool ] || { wget -q -O appimagetool \
  https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage; chmod +x appimagetool; }
export APPIMAGE_EXTRACT_AND_RUN=1

# libmpv + its dependencies
LIBMPV=$(ldconfig -p | grep -E 'libmpv\.so\.[0-9]+ ' | head -n1 | awk '{print $NF}')
echo "bundling $LIBMPV"
EXCLUDES=()
for p in 'libgtk-3*' 'libgdk-3*' 'libgdk_pixbuf*' 'libglib-2*' 'libgio-2*' \
         'libgobject-2*' 'libgmodule-2*' 'libpango*' 'libcairo*' 'libatk*' \
         'libharfbuzz*' 'libfontconfig*' 'libfreetype*' 'libX*' 'libxcb*' \
         'libwayland*' 'libepoxy*' 'libGL*' 'libEGL*' 'libgbm*' 'libdrm*' \
         'libva*' 'libvdpau*' 'libvulkan*' 'libasound*' 'libpulse*' \
         'libjack*' 'libpipewire*' 'libsystemd*' 'libudev*' 'libdbus*'; do
  EXCLUDES+=(--exclude-library "$p")
done
./linuxdeploy --appdir "$APPDIR" --library "$LIBMPV" "${EXCLUDES[@]}"
# media_kit looks for "libmpv.so" first
( cd "$APPDIR/usr/lib" && ln -sf "$(basename "$LIBMPV")" libmpv.so )
echo "bundled libraries: $(ls "$APPDIR/usr/lib" | wc -l)"

ARCH=x86_64 ./appimagetool --no-appstream "$APPDIR" "SlaxxFM-linux-x86_64.AppImage"
ls -la SlaxxFM-linux-x86_64.AppImage
