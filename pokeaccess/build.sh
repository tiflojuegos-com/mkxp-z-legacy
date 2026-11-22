#!/usr/bin/env bash
# Builds the 32-bit mkxp-z 1.3.0 engine used by PokeAccess (static exe, Ruby 1.8.7, MiniFFI, easypoke)
# and a self-contained fluidsynth.dll. mkxp-z is this checkout; every other dependency comes from its
# source tarball in $DL, with its patch from pokeaccess/patches. Run from an MSYS2 MINGW32 shell:
#   pokeaccess/build.sh deps      installs the MSYS2 packages and the archived 32-bit libraries (once)
#   pokeaccess/fetch.sh           downloads and verifies the dependency tarballs into $DL
#   pokeaccess/build.sh           builds every step not yet done; results land in $WORK/out
# WORK (default pokeaccess/work) holds src/, bld/, pfx/ and out/; DL defaults to pokeaccess/dl.
# Neither WORK nor the checkout may contain spaces. mkxp-z is configured in <checkout>/build.
# Each step logs to $WORK/bld/<step>.log and leaves $WORK/bld/.done-<step>; delete that file to redo a step.
set -eo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/.." && pwd)
WORK=${WORK:-$HERE/work} DL=${DL:-$HERE/dl}
mkdir -p "$WORK" "$DL"
WORK=$(cd "$WORK" && pwd) DL=$(cd "$DL" && pwd)
W=$(cygpath -m "$WORK")
SRC=$WORK/src BLD=$WORK/bld PAT=$HERE/patches OUT=$WORK/out
PFX=$W/pfx
JOBS=${JOBS:-$(nproc)}
SYSROOT=$(cygpath -m /mingw32)
CLANG_BIN=$(cygpath -m /mingw64/bin)
TARGET="--target=i686-w64-mingw32 --sysroot=$SYSROOT"
export PKG_CONFIG_PATH=$PFX/lib/pkgconfig
export PATH="$WORK/pfx/bin:$PATH"
export LANG=C LC_ALL=C
[ -n "$USERPROFILE" ] || export USERPROFILE=$(cygpath -w "$HOME")
export WANT_AUTOCONF=2.69 WANT_AUTOMAKE=latest
AT="--build=i686-w64-mingw32 --host=i686-w64-mingw32 --prefix=$PFX"
CM="-G Ninja -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$PFX -DCMAKE_PREFIX_PATH=$PFX -DBUILD_SHARED_LIBS=OFF"
MS="--prefix=$PFX --buildtype=release -Ddefault_library=static"

# The 32-bit libraries MSYS2's mingw32 repo no longer carries, at the versions the engine was built with, taken from
# its package archive with their signatures. SDL2 asks for the dropped Vulkan loader, which its static library does
# not link.
MSYS2_ARCHIVE=https://repo.msys2.org/mingw/mingw32
ARCHIVED="SDL2-2.32.10-1 libogg-1.3.6-1 libvorbis-1.3.7-3 flac-1.5.0-2 opus-1.6.1-1 mpg123-1.33.7-1 lame-3.100-3 libsndfile-1.2.2-1"

deps() {
  local p f pkgs=$DL/msys2 files=""
  pacman -S --needed --noconfirm \
    mingw-w64-i686-{gcc,binutils,meson,ninja,pkgconf,cmake,zlib,libiconv,gmp} \
    mingw-w64-x86_64-clang make autoconf automake libtool bison patch diffutils vim
  mkdir -p "$pkgs"
  for p in $ARCHIVED; do
    f=mingw-w64-i686-$p-any.pkg.tar.zst
    [ -s "$pkgs/$f" ] || curl -fL --retry 5 -o "$pkgs/$f" "$MSYS2_ARCHIVE/$f"
    [ -s "$pkgs/$f.sig" ] || curl -fL --retry 5 -o "$pkgs/$f.sig" "$MSYS2_ARCHIVE/$f.sig"
    files="$files $pkgs/$f"
  done
  pacman -U --needed --noconfirm --assume-installed mingw-w64-i686-vulkan $files
}

unpack() {
  local name=$1 tarball=$2 tmp=$SRC/.x p
  [ -f "$SRC/$name/.unpacked" ] && return 0
  rm -rf "$SRC/$name" "$tmp"; mkdir -p "$tmp"
  tar -xf "$DL/$tarball" -C "$tmp" 2>/dev/null || tar -xf "$DL/$tarball" -C "$tmp"
  mv "$tmp"/* "$SRC/$name"; rmdir "$tmp"
  for p in "$PAT/$name".patch "$PAT/$name"-*.patch; do
    if [ -f "$p" ]; then patch -d "$SRC/$name" -p1 --no-backup-if-mismatch < "$p"; fi
  done
  touch "$SRC/$name/.unpacked"
}

cmake_build() {
  local name=$1; shift
  cmake -S "$SRC/$name" -B "$BLD/$name" $CM "$@"
  cmake --build "$BLD/$name" -j "$JOBS"
  cmake --install "$BLD/$name"
}

b_freetype() {
  unpack freetype freetype-2.13.3.tar.xz
  cmake_build freetype -DFT_DISABLE_HARFBUZZ=ON -DFT_DISABLE_BROTLI=ON -DFT_DISABLE_BZIP2=ON -DFT_DISABLE_PNG=ON -DFT_REQUIRE_ZLIB=ON
}

b_sdl2_ttf() {
  unpack SDL2_ttf SDL2_ttf-2.24.0.tar.gz
  cmake_build SDL2_ttf -DSDL2TTF_HARFBUZZ=OFF -DSDL2TTF_VENDORED=OFF -DSDL2TTF_SAMPLES=OFF
}

b_sdl2_image() {
  unpack SDL2_image SDL2_image-2.8.8.tar.gz
  cmake_build SDL2_image -DSDL2IMAGE_BACKEND_STB=ON -DSDL2IMAGE_BACKEND_WIC=OFF -DSDL2IMAGE_AVIF=OFF -DSDL2IMAGE_JXL=OFF \
    -DSDL2IMAGE_TIF=OFF -DSDL2IMAGE_WEBP=OFF -DSDL2IMAGE_SAMPLES=OFF -DSDL2IMAGE_TESTS=OFF -DSDL2IMAGE_VENDORED=OFF
}

b_physfs() {
  unpack physfs physfs-3.2.0.tar.gz
  cmake_build physfs -DPHYSFS_BUILD_SHARED=OFF -DPHYSFS_BUILD_STATIC=ON -DPHYSFS_BUILD_TEST=OFF -DPHYSFS_BUILD_DOCS=OFF
}

b_openal() {
  unpack openal-soft openal-soft-1.23.1.tar.gz
  cmake_build openal-soft "-DCMAKE_CXX_FLAGS=-include cstdint" -DLIBTYPE=STATIC -DALSOFT_UTILS=OFF -DALSOFT_EXAMPLES=OFF -DALSOFT_TESTS=OFF \
    -DALSOFT_NO_CONFIG_UTIL=ON -DALSOFT_BACKEND_SDL2=OFF -DALSOFT_INSTALL_EXAMPLES=OFF -DALSOFT_INSTALL_UTILS=OFF
}

b_pixman() {
  local o="" x
  unpack pixman pixman-0.44.2.tar.gz
  for x in tests demos gtk libpng openmp; do
    if grep -qE "[\"']$x[\"']" "$SRC/pixman/meson.options"; then o="$o -D$x=disabled"; fi
  done
  meson setup "$BLD/pixman" "$SRC/pixman" $MS $o
  ninja -C "$BLD/pixman" install
}

b_sigcxx() {
  unpack libsigc++ libsigc++-2.12.1.tar.xz
  meson setup "$BLD/libsigc++" "$SRC/libsigc++" $MS -Dmaintainer-mode=false -Dbuild-documentation=false \
    -Dvalidation=false -Dbuild-examples=false -Dbuild-tests=false -Dbenchmark=false
  ninja -C "$BLD/libsigc++" install
}

b_sdl_sound() {
  unpack SDL_sound SDL_sound-04798ba5.tar.gz
  (cd "$SRC/SDL_sound" && ./bootstrap)
  mkdir -p "$BLD/SDL_sound" && cd "$BLD/SDL_sound"
  "$SRC/SDL_sound/configure" $AT --disable-shared --enable-static --disable-flac --disable-speex --disable-mikmod \
    --disable-modplug --disable-physfs --disable-midi --disable-shn CFLAGS="-O2 -std=gnu17 -fpermissive -w"
  make -j"$JOBS"
  make install
}

b_objfw() {
  unpack objfw objfw-7ff624a0.tar.gz
  cd "$SRC/objfw"
  [ -f configure ] || ./autogen.sh
  ./configure $AT --disable-shared --enable-static OBJC="$CLANG_BIN/clang.exe $TARGET" OBJCFLAGS="-O2" AR=ar RANLIB=ranlib
  make -j"$JOBS"
  make install
}

b_ruby() {
  unpack ruby ruby-mkxpz-24a41c0e.tar.gz
  (cd "$SRC/ruby" && autoconf)
  mkdir -p "$BLD/ruby" && cd "$BLD/ruby"
  "$SRC/ruby/configure" $AT --disable-install-doc --disable-largefile --without-ext \
    CFLAGS="-O2 -std=gnu89 -fpermissive -fcommon -w"
  make
  make install
  cp -f libruby18.a "$PFX/lib/"
  rm -f "$PFX/lib/libruby18.dll.a"
  sed -i 's/ -Wl,-Bstatic -lgcc -lpthread -Wl,-Bdynamic//' "$PFX/lib/pkgconfig/ruby-1.8.pc"
}

b_mkxpz() {
  local c="'$CLANG_BIN/clang.exe', '--target=i686-w64-mingw32', '--sysroot=$SYSROOT'"
  local cxx="'$CLANG_BIN/clang++.exe', '--target=i686-w64-mingw32', '--sysroot=$SYSROOT'"
  mkdir -p "$REPO/boost-unordered"
  if [ -z "$(ls -A "$REPO/boost-unordered")" ]; then
    tar -xf "$DL/boost-unordered-87337739.tar.gz" -C "$REPO/boost-unordered" --strip-components=1
  fi
  mkdir -p "$BLD"
  printf "[binaries]\nc = [%s]\ncpp = [%s]\nobjc = [%s]\nobjcpp = [%s]\nar = 'ar'\nstrip = 'strip'\nwindres = 'windres'\npkg-config = 'pkgconf'\n" \
    "$c" "$cxx" "$c" "$cxx" > "$BLD/native.ini"
  [ -d "$REPO/build" ] || meson setup "$REPO/build" "$REPO" --native-file "$BLD/native.ini" --buildtype=release \
    -Dmri_version=1.8 -Duse_miniffi=true -Deasypoke=true -Dstatic_executable=true
  ninja -C "$REPO/build"
  mkdir -p "$OUT"
  strip -o "$OUT/mkxp-z.exe" "$REPO/build/mkxp-z.exe"
}

b_fluidsynth() {
  local off="" x extra
  unpack fluidsynth fluidsynth-2.6.1.tar.gz
  for x in portaudio readline openmp dsound wasapi waveout winmidi sdl3 network ipv6 dbus jack pulseaudio pipewire \
           ladspa systemd aufile native-dls signalsmith alsa oss midishare opensles oboe coreaudio coremidi framework dart kai; do
    off="$off -Denable-$x=OFF"
  done
  extra="$(pkg-config --static --libs sndfile) -lwinmm -lole32"
  cmake -S "$SRC/fluidsynth" -B "$BLD/fluidsynth" -G Ninja -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$W/fluid" \
    -DBUILD_SHARED_LIBS=ON -Denable-libsndfile=ON $off -DCMAKE_FIND_LIBRARY_SUFFIXES=.a -DCMAKE_DISABLE_FIND_PACKAGE_SndFile=ON \
    -D_sndfile_library="$(cygpath -m /mingw32/lib/libsndfile.a)" \
    -DCMAKE_SHARED_LINKER_FLAGS="-static -static-libgcc -static-libstdc++" \
    -DCMAKE_C_STANDARD_LIBRARIES="$extra" -DCMAKE_CXX_STANDARD_LIBRARIES="$extra"
  cmake --build "$BLD/fluidsynth" -j "$JOBS" --target libfluidsynth
  mkdir -p "$OUT/extras"
  strip -o "$OUT/extras/fluidsynth.dll" "$(ls "$BLD"/fluidsynth/src/libfluidsynth*.dll | head -1)"
  cp "$DL/GeneralUser-GS.sf2" "$OUT/extras/"
}

step() {
  local n=$1 rc
  [ -f "$BLD/.done-$n" ] && return 0
  mkdir -p "$BLD"; echo "== $n"
  set +e
  ( set -e; "b_$n" ) > "$BLD/$n.log" 2>&1
  rc=$?
  set -e
  if [ $rc -ne 0 ]; then echo "FAILED: $n (last lines of $BLD/$n.log)"; tail -30 "$BLD/$n.log"; exit 1; fi
  touch "$BLD/.done-$n"
}

if [ "$1" = deps ]; then deps; exit 0; fi
STEPS=${*:-freetype sdl2_ttf sdl2_image physfs openal pixman sigcxx sdl_sound objfw ruby mkxpz fluidsynth}
for s in $STEPS; do step "$s"; done
echo "done: $OUT"
