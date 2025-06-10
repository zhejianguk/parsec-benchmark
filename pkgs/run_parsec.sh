#!/bin/bash

gc_kernel=none
toolchain=host

# Input flags
while getopts k:t: flag
do
	case "${flag}" in
		k) gc_kernel=${OPTARG};;
		t) toolchain=${OPTARG};;
	esac
done

input_type=simmedium

# Set architecture based on toolchain
if [ "$toolchain" = "riscv" ]; then
    arch=riscv64-linux
else
    arch=amd64-linux  # Default for host
fi


BENCHMARKS=(blackscholes bodytrack dedup ferret fluidanimate freqmine streamcluster swaptions)
base_dir=$PWD

if [ $gc_kernel != "none" ]; then 
    ./initialisation_${gc_kernel}.riscv
fi

for benchmark in ${BENCHMARKS[@]}; do
    sub_dir=apps
    if [ $benchmark == "dedup" ]; then 
        sub_dir=kernels
    fi

    if [ $benchmark == "streamcluster" ]; then 
        sub_dir=kernels
    fi

    bin_dir=${base_dir}/${sub_dir}/${benchmark}/inst/${arch}.gcc/bin
    run_dir=${base_dir}/${sub_dir}/${benchmark}/run/
    input_dir=${base_dir}/${sub_dir}/${benchmark}/inputs/
    command_dir=${base_dir}/commands/${input_type}

    # Extract input files for this benchmark and input type
    if [ -d "${input_dir}" ] && [ -f "${input_dir}/input_${input_type}.tar" ]; then
        cd ${run_dir}
        tar -xf ${input_dir}/input_${input_type}.tar 2>/dev/null || echo "Warning: Could not extract input files for ${benchmark}"
    fi

    IFS=$'\n' read -d '' -r -a commands < ${command_dir}/${benchmark}.cmd
    count=0
    for input in "${commands[@]}"; do
        echo "[======= Benchmark: ${benchmark} =======]"
        if [[ ${input:0:1} != '#' ]]; then # allow us to comment out lines in the cmd files
            cd ${run_dir}
            cp ${bin_dir}/${benchmark} $run_dir
            cmd="time ./${benchmark} ${input}"
            echo "workload=[${cmd}]"
            eval ${cmd}
            rm ./${benchmark}
            ((count++))
        fi
    done
    echo ""
done

echo ""
echo "All Done!"