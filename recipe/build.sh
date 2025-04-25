#!/bin/bash

set -ex

# strip std settings from conda
CXXFLAGS="${CXXFLAGS/-std=c++14/}"
CXXFLAGS="${CXXFLAGS/-std=c++11/}"
export CXXFLAGS

if [ "$(uname)" == "Linux" ]; then
   export LDFLAGS="${LDFLAGS} -Wl,-rpath-link,${PREFIX}/lib"

   # need this for draco finding
   export PKG_CONFIG_PATH="$PKG_CONFIG_PATH;${PREFIX}/lib64/pkgconfig"
fi

if [ "$(uname)" = "Darwin" ]; then
    EXT='.dylib'
else
    EXT='.so'
fi

if [ "$CONDA_BUILD_CROSS_COMPILATION" == "1" ]; then
  mkdir native; cd native;

  # Unset them as we're ok with builds that are either slow or non-portable
  unset CFLAGS
  unset CXXFLAGS

  CC=$CC_FOR_BUILD CXX=$CXX_FOR_BUILD LDFLAGS=${LDFLAGS//$PREFIX/$BUILD_PREFIX} cmake -G "Unix Makefiles" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES="x86_64" \
    ..

  export DIMBUILDER=`pwd`/bin/dimbuilder
  make dimbuilder
  cd ..
else
  export DIMBUILDER=dimbuilder

fi

if [ "$(uname)" = "Darwin" ]; then
    cc_comp=clang
    cxx_comp=clang++
else
    cc_comp=x86_64-conda-linux-gnu-gcc
    cxx_comp=x86_64-conda-linux-gnu-c++
fi

rm -rf build && mkdir build && cd build

ldflags="-Wl,-rpath,${PREFIX}/lib -L${PREFIX}/lib -lgeotiff -lcurl -lssl -lxml2 -lcrypto -lzstd -lz"

# Use BUILD_PLUGIN_TRAJECTORY:BOOL=OFF so we don't have to use CERES

# Enforce a compiler we know to work
cmake ${CMAKE_ARGS}                                      \
  -DCMAKE_C_COMPILER=${PREFIX}/bin/$cc_comp              \
  -DCMAKE_CXX_COMPILER=${PREFIX}/bin/$cxx_comp           \
  -DBUILD_SHARED_LIBS=ON                                 \
  -DCMAKE_BUILD_TYPE=Release                             \
  -DCMAKE_INSTALL_PREFIX=$PREFIX                         \
  -DCMAKE_PREFIX_PATH=$PREFIX                            \
  -DDIMBUILDER_EXECUTABLE=$DIMBUILDER                    \
  -DBUILD_PLUGIN_I3S=OFF                                 \
  -DBUILD_PLUGIN_TRAJECTORY=OFF                          \
  -DBUILD_PLUGIN_E57=OFF                                 \
  -DBUILD_PLUGIN_PGPOINTCLOUD=ON                         \
  -DBUILD_PLUGIN_ICEBRIDGE=OFF                           \
  -DBUILD_PLUGIN_NITF=OFF                                \
  -DBUILD_PLUGIN_TILEDB=ON                               \
  -DBUILD_PLUGIN_HDF=ON                                  \
  -DBUILD_PLUGIN_DRACO=OFF                               \
  -DENABLE_CTEST=OFF                                     \
  -DWITH_TESTS=OFF                                       \
  -DWITH_ZLIB=ON                                         \
  -DWITH_ZSTD=ON                                         \
  -DWITH_LASZIP=ON                                       \
  -DWITH_LAZPERF=ON                                      \
  -DCMAKE_VERBOSE_MAKEFILE=ON                            \
  -DCMAKE_CXX17_STANDARD_COMPILE_OPTION="-std=c++17"     \
  -DCMAKE_VERBOSE_MAKEFILE=ON                            \
  -DWITH_TESTS=OFF                                       \
  -DCMAKE_EXE_LINKER_FLAGS="$ldflags"                    \
  -DDIMBUILDER_EXECUTABLE=dimbuilder                     \
  -DBUILD_PLUGIN_DRACO:BOOL=OFF                          \
  -DOPENSSL_ROOT_DIR=${PREFIX}                           \
  -DLIBXML2_INCLUDE_DIR=${PREFIX}/include/libxml2        \
  -DLIBXML2_LIBRARIES=${PREFIX}/lib/libxml2${EXT}        \
  -DLIBXML2_XMLLINT_EXECUTABLE=${PREFIX}/bin/xmllint     \
  -DGDAL_LIBRARY=${PREFIX}/lib/libgdal${EXT}             \
  -DGDAL_CONFIG=${PREFIX}/bin/gdal-config                \
  -DZLIB_INCLUDE_DIR:PATH=${PREFIX}/include              \
  -DZLIB_LIBRARY:FILEPATH=${PREFIX}/lib/libz${EXT}       \
  -DCURL_INCLUDE_DIR=${PREFIX}/include                   \
  -DPostgreSQL_LIBRARY_RELEASE=${PREFIX}/lib/libpq${EXT} \
  -DCURL_LIBRARY_RELEASE=${PREFIX}/lib/libcurl${EXT}     \
  -DPROJ_INCLUDE_DIR:PATH=${PREFIX}/include              \
  -DPROJ_LIBRARY:FILEPATH=${PREFIX}/lib/libproj${EXT}    \
  ..

make -j $CPU_COUNT ${VERBOSE_CM}
make install

# This will not be needed once we fix upstream.
chmod 755 $PREFIX/bin/pdal-config

ACTIVATE_DIR=$PREFIX/etc/conda/activate.d
DEACTIVATE_DIR=$PREFIX/etc/conda/deactivate.d
mkdir -p $ACTIVATE_DIR
mkdir -p $DEACTIVATE_DIR

cp $RECIPE_DIR/scripts/activate.sh $ACTIVATE_DIR/pdal-activate.sh
cp $RECIPE_DIR/scripts/deactivate.sh $DEACTIVATE_DIR/pdal-deactivate.sh

# Bugfix for libpdalcpp${EXT} not being a symlink. This is fragile
# logic.
dir=$(pwd) 
cd $PREFIX/lib
/bin/rm -f libpdalcpp${EXT}
if [ "$(uname)" = "Darwin" ]; then
  ln -s $(ls libpdalcpp.[0-9][0-9].*${EXT} | head -n 1) libpdalcpp${EXT}
else
  ln -s $(ls libpdalcpp${EXT}.[0-9][0-9].* | head -n 1) libpdalcpp${EXT}
fi
cd $dir

