#!/bin/bash

# Copyright 2020 Rene Rivera, Sam Darwin
# Distributed under the Boost Software License, Version 1.0.
# (See accompanying file LICENSE.txt or copy at http://boost.org/LICENSE_1_0.txt)

set -e
export TRAVIS_BUILD_DIR=$(pwd)
export DRONE_BUILD_DIR=$(pwd)
export TRAVIS_BRANCH=$DRONE_BRANCH
export VCS_COMMIT_ID=$DRONE_COMMIT
export GIT_COMMIT=$DRONE_COMMIT
export REPO_NAME=$DRONE_REPO
export PATH=~/.local/bin:/usr/local/bin:$PATH

if [ "$DRONE_JOB_BUILDTYPE" == "boost" ]; then

echo '==================================> INSTALL'

GIT_FETCH_JOBS=8
BOOST_BRANCH=develop
if [ "$TRAVIS_BRANCH" = "master" ]; then BOOST_BRANCH=master; fi
cd ..
git clone -b $BOOST_BRANCH --depth 1 https://github.com/boostorg/boost.git boost-root
cd boost-root
git submodule init tools/boostdep
git submodule init tools/build
git submodule init tools/boost_install
git submodule init libs/headers
git submodule init libs/config
git submodule update --jobs $GIT_FETCH_JOBS
cp -r $TRAVIS_BUILD_DIR/* libs/log
if [ -n "$EXTRA_TESTS" ]; then DEPINST_ARG_INCLUDE_EXAMPLES="--include example"; fi
python tools/boostdep/depinst/depinst.py $DEPINST_ARG_INCLUDE_EXAMPLES --git_args "--jobs $GIT_FETCH_JOBS" log
./bootstrap.sh
./b2 headers

echo '==================================> SCRIPT'

echo "using $TOOLSET : : $COMPILER ;" > ~/user-config.jam
BUILD_JOBS=`(nproc || sysctl -n hw.ncpu) 2> /dev/null`
if [ -z "$EXTRA_TESTS" ]; then export BOOST_LOG_TEST_WITHOUT_SELF_CONTAINED_HEADER_TESTS=1; export BOOST_LOG_TEST_WITHOUT_EXAMPLES=1; fi
./b2 -j $BUILD_JOBS libs/log/test toolset=$TOOLSET cxxstd=$CXXSTD ${UBSAN:+cxxflags=-fsanitize=undefined cxxflags=-fno-sanitize-recover=undefined linkflags=-fsanitize=undefined define=UBSAN=1 debug-symbols=on visibility=global} ${CXXFLAGS:+cxxflags="$CXXFLAGS"} ${LINKFLAGS:+linkflags="$LINKFLAGS"}

fi
