#!/bin/bash

gc_kernel=none
toolchain=host

rm -f *.o
rm -f *.riscv

# Input flags
while getopts k:t: flag
do
	case "${flag}" in
		k) gc_kernel=${OPTARG};;
		t) toolchain=${OPTARG};;
	esac
done

# Validate toolchain option
if [ "$toolchain" != "host" ] && [ "$toolchain" != "riscv" ]; then
    echo "Error: Invalid toolchain option. Use 'host' or 'riscv'"
    echo "Usage: $0 [-k gc_kernel] [-t toolchain]"
    echo "  -k: GC kernel option (default: none)"
    echo "  -t: Toolchain selection - 'host' or 'riscv' (default: host)"
    exit 1
fi

input_type=simmedium

# Set up PARSEC environment
export PARSECDIR="$(dirname $PWD)"
export PATH_PKGS=$PWD
export PARSEC_TOOLCHAIN=$toolchain

echo "Building with $toolchain toolchain..."

cd $PATH_PKGS

BENCHMARKS=(dedup)

cmd="${PARSECDIR}/bin/parsecmgmt -a clean -p all"
eval ${cmd}
cmd="${PARSECDIR}/bin/parsecmgmt -a fulluninstall -p all"
eval ${cmd}


for benchmark in ${BENCHMARKS[@]}; do

    cmd="${PARSECDIR}/bin/parsecmgmt -a build -p ${benchmark}"
    eval ${cmd}

    cmd="${PARSECDIR}/bin/parsecmgmt -a run -p ${benchmark} -i ${input_type}"
    eval ${cmd}

done

echo ""
echo "All Done!"