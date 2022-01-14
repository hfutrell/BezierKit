#!/bin/bash

if [[ $TRAVIS_OS_NAME = 'osx' ]]; then
  # install macOS prerequistes
  :
elif [[ $TRAVIS_OS_NAME = 'linux' ]]; then
  if [[ $TRAVIS_JOB_NAME = 'WebAssembly' ]]; then
    docker pull ghcr.io/swiftwasm/carton:0.12.1
  else
    wget https://swift.org/builds/swift-5.3-release/ubuntu1804/${SWIFT_VERSION}/${SWIFT_VERSION}-ubuntu18.04.tar.gz
    tar xzf ${SWIFT_VERSION}-ubuntu18.04.tar.gz
  fi
fi
