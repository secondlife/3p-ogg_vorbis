#!/usr/bin/env bash

cd "$(dirname "$0")"

# turn on verbose debugging output for parabuild logs.
exec 4>&1; export BASH_XTRACEFD=4; set -x
# make errors fatal
set -e
# complain about unset env variables
set -u

if [ -z "$AUTOBUILD" ] ; then 
    exit 1
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    autobuild="$(cygpath -u $AUTOBUILD)"
else
    autobuild="$AUTOBUILD"
fi

OGG_SOURCE_DIR="libogg"
OGG_VERSION="$(sed -n "s/^ VERSION='\(.*\)'/\1/p" "$OGG_SOURCE_DIR/configure")"

VORBIS_SOURCE_DIR="libvorbis"
VORBIS_VERSION="$(sed -n "s/^PACKAGE_VERSION='\(.*\)'/\1/p" "$VORBIS_SOURCE_DIR/configure")"

top="$(pwd)"
stage="$(pwd)/stage"

# load autobuild provided shell functions and variables
source_environment_tempfile="$stage/source_environment.sh"
"$autobuild" source_environment > "$source_environment_tempfile"
. "$source_environment_tempfile"

build=${AUTOBUILD_BUILD_ID:=0}
echo "${OGG_VERSION}-${VORBIS_VERSION}.${build}" > "${stage}/VERSION.txt"

case "$AUTOBUILD_PLATFORM" in
    windows*)
        function copy_result {
            # $1 is the build directory in which to find the result
            # $2 is the basename of the .lib file we expect to find there
            cp "win32/$1/$2.lib" "$stage/lib/release/"
            cp "win32/$1/$2.pdb" "$stage/lib/release/$2.pdb"
        }

        pushd "$OGG_SOURCE_DIR"

        build_sln "win32/ogg.sln" "Release|$AUTOBUILD_WIN_VSPLATFORM" "ogg_static"

        mkdir -p "$stage/lib/release"
        copy_result Static_Release ogg_static

        mkdir -p "$stage/include"
        cp -a "include/ogg/" "$stage/include/"

        popd
        pushd "$VORBIS_SOURCE_DIR"

        build_sln "win32/vorbis.sln" "Release|$AUTOBUILD_WIN_VSPLATFORM" "vorbis_static"
        build_sln "win32/vorbis.sln" "Release|$AUTOBUILD_WIN_VSPLATFORM" "vorbisenc_static"
        build_sln "win32/vorbis.sln" "Release|$AUTOBUILD_WIN_VSPLATFORM" "vorbisfile_static"

        copy_result Vorbis_Static_Release     vorbis_static
        copy_result VorbisEnc_Static_Release  vorbisenc_static
        copy_result VorbisFile_Static_Release vorbisfile_static
        cp -a "include/vorbis/" "$stage/include/"
        popd
    ;;
    darwin*)
        pushd "$OGG_SOURCE_DIR"
        opts="-arch $AUTOBUILD_CONFIGURE_ARCH $LL_BUILD_RELEASE"
        export CFLAGS="$opts" 
        export CPPFLAGS="$opts" 
        export LDFLAGS="$opts"
        ./configure --prefix="$stage"
        make
        make install
        popd
        
        pushd "$VORBIS_SOURCE_DIR"
        ./configure --prefix="$stage"
        make
        make install
        popd
        
        mv "$stage/lib" "$stage/release"
        mkdir -p "$stage/lib"
        mv "$stage/release" "$stage/lib"
     ;;
    linux*)
        pushd "$OGG_SOURCE_DIR"
        opts="-m$AUTOBUILD_ADDRSIZE $LL_BUILD_RELEASE"
        CFLAGS="$opts" CXXFLAGS="$opts" ./configure --prefix="$stage"
        make
        make install
        popd
        
        pushd "$VORBIS_SOURCE_DIR"
        export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:"$stage/lib"
        CFLAGS="$opts" CXXFLAGS="$opts" ./configure --prefix="$stage"
        make
        make install
        popd
        
        mv "$stage/lib" "$stage/release"
        mkdir -p "$stage/lib"
        mv "$stage/release" "$stage/lib"
    ;;
esac
mkdir -p "$stage/LICENSES"
pushd "$OGG_SOURCE_DIR"
    cp COPYING "$stage/LICENSES/ogg-vorbis.txt"
popd
