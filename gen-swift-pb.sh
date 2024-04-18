#!/usr/bin/env sh

# check whether the protoc is installed, if not installed then prompt user and exit
if ! command -v protoc &> /dev/null
then
    echo "protoc command could not be found, please install it first"
    exit
fi

mkdir -p pb

protoc --swift_out=./pb/ -I ./trezor-common/protob/ ./trezor-common/protob/*.proto
