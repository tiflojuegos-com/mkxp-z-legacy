#!/usr/bin/env bash
# Downloads every dependency source of the engine build into $DL (default pokeaccess/dl) and checks it against SHA256SUMS.
# mkxp-z itself is this checkout. The MSYS2 source packages are not built: they are the sources of the LGPL
# libraries that build.sh links into fluidsynth.dll from MSYS2 binary packages.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
DL=${DL:-$HERE/dl}
mkdir -p "$DL"

get() {
  local name=$1 url=$2
  [ -s "$DL/$name" ] || curl -fL --retry 5 --retry-delay 3 -o "$DL/$name.part" "$url" && { [ -s "$DL/$name" ] || mv "$DL/$name.part" "$DL/$name"; }
}

get boost-unordered-87337739.tar.gz https://gitlab.com/zzoro/mkxp-z-boost-unordered/-/archive/873377396eb173eebba30b753cb26d18abc2861d/mkxp-z-boost-unordered-873377396eb173eebba30b753cb26d18abc2861d.tar.gz
get objfw-7ff624a0.tar.gz         https://codeload.github.com/ObjFW/ObjFW/tar.gz/7ff624a09675925f08222499249ef25f325bee41
get ruby-mkxpz-24a41c0e.tar.gz    https://codeload.github.com/mkxp-z/ruby/tar.gz/24a41c0ebe451c574b0ab6e9fefbf684979cefa3
get SDL_sound-04798ba5.tar.gz     https://codeload.github.com/Ancurio/SDL_sound/tar.gz/04798ba55dccd18b094c0f6a2630c2fe7b15aa86
get SDL2_image-2.8.8.tar.gz       https://github.com/libsdl-org/SDL_image/releases/download/release-2.8.8/SDL2_image-2.8.8.tar.gz
get SDL2_ttf-2.24.0.tar.gz        https://github.com/libsdl-org/SDL_ttf/releases/download/release-2.24.0/SDL2_ttf-2.24.0.tar.gz
get freetype-2.13.3.tar.xz        https://download.savannah.gnu.org/releases/freetype/freetype-2.13.3.tar.xz
get pixman-0.44.2.tar.gz          https://cairographics.org/releases/pixman-0.44.2.tar.gz
get physfs-3.2.0.tar.gz           https://github.com/icculus/physfs/archive/refs/tags/release-3.2.0.tar.gz
get libsigc++-2.12.1.tar.xz       https://download.gnome.org/sources/libsigc++/2.12/libsigc++-2.12.1.tar.xz
get openal-soft-1.23.1.tar.gz     https://github.com/kcat/openal-soft/archive/refs/tags/1.23.1.tar.gz
get fluidsynth-2.6.1.tar.gz       https://github.com/FluidSynth/fluidsynth/archive/refs/tags/v2.6.1.tar.gz
get GeneralUser-GS.sf2            https://github.com/mrbumpy409/GeneralUser-GS/raw/97049183643d5fc5a9322a69c5b09efb667c6c3a/GeneralUser-GS.sf2
get GeneralUser-GS-LICENSE.txt    https://github.com/mrbumpy409/GeneralUser-GS/raw/97049183643d5fc5a9322a69c5b09efb667c6c3a/documentation/LICENSE.txt
for p in lame-3.100-3 libsndfile-1.2.2-1 libvorbis-1.3.7-3 mpg123-1.33.7-1; do
  get mingw-w64-$p.src.tar.zst https://repo.msys2.org/mingw/sources/mingw-w64-$p.src.tar.zst
done

cd "$DL"
if [ -f "$HERE/SHA256SUMS" ]; then sha256sum -c --quiet "$HERE/SHA256SUMS"; else sha256sum $(ls | grep -v '\.part$') > "$HERE/SHA256SUMS"; fi
