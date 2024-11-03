#!/bin/bash

[[ ${target_platform} == "linux-64" ]] && targetsDir="targets/x86_64-linux"
[[ ${target_platform} == "linux-ppc64le" ]] && targetsDir="targets/ppc64le-linux"
[[ ${target_platform} == "linux-aarch64" ]] && targetsDir="targets/sbsa-linux"

errors=""

for item in `find $PREFIX/compute-sanitizer/ -type f`; do
    [[ "${item}" =~ "patchelf" ]] && continue
    [[ "${item}" =~ "/docs/" ]] && continue
    [[ "${item}" =~ "/include/" ]] && continue

    filename=$(basename "${item}")
    echo "Artifact to test: ${filename}"

    pkg_info=$(conda package -w "${item}")
    echo "\$PKG_NAME: ${PKG_NAME}"
    echo "\$pkg_info: ${pkg_info}"

    if [[ ! "$pkg_info" == *"$PKG_NAME"* ]]; then
        echo "Not a match, skipping ${item}"
        continue
    fi

    echo "Match found, testing ${item}"

    rpath=$(patchelf --print-rpath "${item}")
    echo "${item} rpath: ${rpath}"

    if [[ ${filename} =~ \.so($|\.) ]]; then
	if [[ $rpath != "\$ORIGIN" ]]; then # DSO lib
            errors+="${item}\n"
	fi
    elif [[ ${filename} == "compute-sanitizer" || ${filename} == "TreeLauncherSubreaper" || ${filename} == "TreeLauncherTargetLdPreloadHelper" ]]; then
	if [[ $rpath != "\$ORIGIN/../lib:\$ORIGIN/../${targetsDir}/lib" ]]; then
            errors+="${item}\n"
	fi
    else # unexpected/unaccounted file
        errors+="${item}\n"
    fi

    if [[ $(objdump -x ${item} | grep "PATH") == *"RUNPATH"* ]]; then
        errors+="${item}\n"
    fi
done

if [[ $errors ]]; then
    echo "The following binaries were found with an unexpected RPATH:"
    echo -e "${errors}"
    exit 1
fi
