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
. ${THISD}/../scripts/util.sh
separator "${BASH_SOURCE}"
if [ -z "${HEPPY_USER_PYTHON_VERSION}" ]; then
	warning "trying to load heppy_python"
	heppy_python_module_name=$(module avail -t | grep heppy_python | head -n 1 | grep heppy_python)
	if [ ! -z ${heppy_python_module_name} ]; then
		warning "... found ${heppy_python_module_name}"
		module load ${heppy_python_module_name}
	else
		warning "... no suitable module found"
	fi
fi
[ -z "${HEPPY_USER_PYTHON_VERSION}" ] && error "missing: HEPPY_USER_PYTHON_VERSION" && exit 1
warning "using heppy python version: ${HEPPY_USER_PYTHON_VERSION}"
version=$(get_opt "version" $@)
[ -z ${version} ] && version=6.18.00
note "... version ${version}"
fname=fastjet-${version}
fname=root_v${version}.source
dirsrc=${THISD}/build/root-${version}
dirinst=${THISD}/packages/root-${version}-${HEPPY_USER_PYTHON_VERSION}
dirbuild=${dirsrc}-build-${HEPPY_USER_PYTHON_VERSION}

function grace_return()
{
	cd ${cdir}
}
prefix=$(get_opt "prefix" $@)
[ ! -z ${prefix} ] && dirinst=${prefix}
clean=$(get_opt "clean" $@)
if [ "x${clean}" == "xyes" ]; then
	warning "cleaning..."
	echo_info "removing ${dirsrc}"
	rm -rf ${dirsrc}
	echo_info "removing ${dirinst}"
	rm -rf ${dirinst}
	grace_return && exit 0
fi
uninstall=$(get_opt "uninstall" $@)
if [ "x${uninstall}" == "xyes" ]; then
	echo_info "uninstall..."
	rm -rf ${dirinst}
	grace_return && exit 0
fi
installed=$(get_opt "installed" $@)
if [ "x${installed}" == "xyes" ]; then
	[ -d ${dirinst} ] && echo_info "${dirinst} exists"
	[ ! -d ${dirinst} ] && error "${dirinst} does NOT exists"
	grace_return && exit 0
fi

[ ! -d ${THISD}/build ] && mkdir -v ${THISD}/build
[ ! -d ${THISD}/packages ] && mkdir -v ${THISD}/packages

source_build=$(get_opt "source" $@)
if [ "x${source_build}" == "xyes" ]; then
	if [ ! -e ${THISD}/build/${fname}.tar.gz ]; then
		cd ${THISD}/build
		wget https://root.cern/download/${fname}.tar.gz
	fi

	if [ ! -d ${dirsrc} ]; then
		cd ${THISD}/build
		tar zxvf ${fname}.tar.gz
	fi
else
	git clone http://github.com/root-project/root.git ${dirsrc}
	cd ${dirsrc}
	#git tag -l
	rv="${version//./-}"
	if [ "x$rv" == "xhead" ]; then
		echo_info "git checkout of ${rv}..."
		git checkout -b ${rv}
	else
		echo_info "git checkout of v${rv}..."
		git checkout -b v${rv}
	fi
fi

redo=$(get_opt "rebuild" $@)
if [ ! -d ${dirinst} ] || [ "x${redo}" == "xyes" ]; then
	mkdir -p ${dirbuild}
	if [ -d ${dirsrc} ]; then
		mkdir -p ${dirbuild}
		cd ${dirbuild}
		_gff=$(which gfortran)
		_gcc=$(which gcc)
		_gpp=$(which g++)
		config_opts="-DPYTHON_EXECUTABLE=${HEPPY_PYTHON_EXECUTABLE} -DPYTHON_INCLUDE_DIR=${HEPPY_PYTHON_INCLUDE_DIR} -DPYTHON_LIBRARY=${HEPPY_PYTHON_LIBDIR}"
		config_opts="-Dbuiltin_xrootd=ON -Dmathmore=ON -Dxml=ON -Dvmc=ON"
		# compiler_opts="-DCMAKE_C_COMPILER=${_gcc} -DCMAKE_CXX_COMPILER=${_gpp} -DCMAKE_Fortran_COMPILER=${_gff}"
		# if Catalina:
		_is_mac=$(uname -s)
		if [ "x${_is_mac}" == "xDarwin" ]; then
			# this from root 6.19
			compiler_opts="${compiler_opts} -Dmacos_native=ON"
			# this for 6.18 - workaround
			_sysversion_major=$(sw_vers -productVersion | cut -d. -f 1)
			_sysversion_minor=$(sw_vers -productVersion | cut -d. -f 2)
			_sysversion="${_sysversion_major}.${_sysversion_minor}"
			_catalina="10.15"
			if [ "x${_sysversion}" == "x${_catalina}" ]; then
				_sdk_path=$(xcrun --show-sdk-path)
				compiler_opts="${compiler_opts} -DCMAKE_OSX_SYSROOT=${_sdk_path}"
			fi
		fi
		echo_info "extra options: ${config_opts} ${compiler_opts}"

		# if [ "x$version" == "xhead" ]; then
		# 	cmake -DCMAKE_BUILD_TYPE\=Release ${dirsrc}
		# else
		# 	cmake -DCMAKE_BUILD_TYPE\=Release ${compiler_opts} ${config_opts} ${dirsrc}
		# fi
		# cmake -DCMAKE_BUILD_TYPE\=Release ${config_opts} ${dirsrc}
		cmake -DCMAKE_BUILD_TYPE\=Release ${compiler_opts} ${config_opts} ${dirsrc}

		configure_only=$(get_opt "configure-only" $@)
		[ "x${configure_only}" == "xyes" ] && grace_return && exit 0
		cmake --build . -- -j $(n_cores) && cmake -DCMAKE_INSTALL_PREFIX=${dirinst} -P cmake_install.cmake

		cd ${cdir}
	fi
fi

python_path="${dirinst}/lib/ROOT.py"
python_path64="${dirinst}/lib64/ROOT.py"
if [ -f ${python_path64} ] || [ -f ${python_path} ]; then
	${THISD}/../scripts/make_module.sh --dir=${dirinst} --name=ROOT --version=${version}
else
	error "ROOT.py not found - no module generation"
	[ ! -f ${python_path} ] && error "missing ${python_path}"
	[ ! -f ${python_path64} ] && error "missing ${python_path64}"
	exit 0
fi


cd ${cdir}
