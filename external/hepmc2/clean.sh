#!/bin/bash

cdir=$(pwd)

function thisdir()
{
	SOURCE="${BASH_SOURCE[0]}"
	while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
	  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
	  SOURCE="$(readlink "$SOURCE")"
	  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
	done
	DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
	echo ${DIR}
}
THISD=$(thisdir)
cd ${THISD}

. ${THISD}/../../scripts/util.sh

separator "cleanup hepmc2 ${PWD}"

rm -rf ./hepmc2-current ./build ./build_hepmc2 ./CMakeFiles ./CMakeCache.txt ./Makefile ./cmake_install.cmake

