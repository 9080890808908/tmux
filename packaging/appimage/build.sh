#!/bin/bash
set -euo pipefail
LIBEVENT=2.1.12-stable
NCURSES=6.5
UTF8PROC=2.10.0
ARCH=$(uname -m)
ROOT=$(pwd)
DEPS=$ROOT/build/deps
APPDIR=$ROOT/build/AppDir
JOBS=$(nproc)
mkdir -p "$DEPS" "$APPDIR/usr/bin" "$APPDIR/usr/share/terminfo"
cd "$ROOT/build"
curl -fsSL "https://github.com/libevent/libevent/releases/download/release-$LIBEVENT/libevent-$LIBEVENT.tar.gz" | tar xz
curl -fsSL "https://ftp.gnu.org/gnu/ncurses/ncurses-$NCURSES.tar.gz" | tar xz
curl -fsSL "https://github.com/JuliaStrings/utf8proc/archive/refs/tags/v$UTF8PROC.tar.gz" | tar xz
(cd libevent-$LIBEVENT && ./configure --prefix="$DEPS" --disable-shared --enable-static --disable-openssl --disable-samples --with-pic && make -j"$JOBS" && make install)
(cd ncurses-$NCURSES && ./configure --prefix="$DEPS" --without-shared --with-normal --without-debug --without-cxx --without-cxx-binding --without-ada --without-manpages --without-tests --enable-widec --with-terminfo-dirs=/etc/terminfo:/lib/terminfo:/usr/share/terminfo --with-default-terminfo-dir=/usr/share/terminfo --disable-stripping && make -j"$JOBS" && make install.libs install.includes && make install.data DESTDIR="$ROOT/build/nc-stage")
(cd utf8proc-$UTF8PROC && make -j"$JOBS" libutf8proc.a && install -D libutf8proc.a "$DEPS/lib/libutf8proc.a" && install -D utf8proc.h "$DEPS/include/utf8proc.h" && mkdir -p "$DEPS/lib/pkgconfig" && printf "prefix=%s\nName: libutf8proc\nDescription: utf8proc\nVersion: %s\nLibs: -L\${prefix}/lib -lutf8proc\nCflags: -I\${prefix}/include\n" "$DEPS" "$UTF8PROC" > "$DEPS/lib/pkgconfig/libutf8proc.pc")
cp -r "$ROOT/build/nc-stage/usr/share/terminfo/." "$APPDIR/usr/share/terminfo/"
cd "$ROOT"
sh autogen.sh
mkdir -p build/tmux && cd build/tmux
export PKG_CONFIG_PATH="$DEPS/lib/pkgconfig"
export CPPFLAGS="-I$DEPS/include -I$DEPS/include/ncursesw"
export LDFLAGS="-L$DEPS/lib"
export LIBEVENT_CFLAGS="-I$DEPS/include" LIBEVENT_LIBS="-L$DEPS/lib -levent"
export LIBNCURSES_CFLAGS="-I$DEPS/include/ncursesw" LIBNCURSES_LIBS="-L$DEPS/lib -lncursesw"
"$ROOT/configure" --enable-utf8proc --prefix=/usr || { grep -n -B2 -A12 "utf8proc_charwidth" config.log | tail -60; exit 1; }
make -j"$JOBS"
install -m755 tmux "$APPDIR/usr/bin/tmux"
strip "$APPDIR/usr/bin/tmux"
cd "$ROOT"
install -m755 packaging/appimage/AppRun "$APPDIR/AppRun"
install -m644 packaging/appimage/tmux.desktop "$APPDIR/tmux.desktop"
install -m644 logo/tmux-logo-medium.png "$APPDIR/tmux.png"
curl -fsSL -o build/appimagetool "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-$ARCH.AppImage"
chmod +x build/appimagetool
VERSION=$TMUX_VERSION
ARCH=$ARCH build/appimagetool --appimage-extract-and-run "$APPDIR" "tmux-$VERSION-$ARCH.AppImage"
