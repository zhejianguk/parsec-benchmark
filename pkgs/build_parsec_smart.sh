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

BENCHMARKS=(blackscholes bodytrack dedup ferret fluidanimate freqmine streamcluster swaptions)

# Check if SSL libraries are already built for RISC-V
if [ "$toolchain" = "riscv" ]; then
    if [ -f "libs/ssl/inst/riscv64-linux.gcc/lib/libcrypto.a" ] && [ -f "libs/ssl/inst/riscv64-linux.gcc/lib/libssl.a" ]; then
        echo "RISC-V SSL libraries already exist, checking format..."
        
        # Extract a test object to verify it's RISC-V format
        cd libs/ssl/inst/riscv64-linux.gcc/lib
        ar x libcrypto.a cryptlib.o 2>/dev/null
        if file cryptlib.o 2>/dev/null | grep -q "UCB RISC-V"; then
            echo "✅ SSL libraries are already correctly built for RISC-V, skipping SSL rebuild"
            SSL_SKIP=true
            rm -f cryptlib.o
        else
            echo "❌ SSL libraries are wrong format, will rebuild"
            SSL_SKIP=false
            rm -f cryptlib.o
        fi
        cd $PATH_PKGS
    else
        echo "SSL libraries not found, will build"
        SSL_SKIP=false
    fi
else
    SSL_SKIP=false
fi

# Clean everything except SSL if we're skipping SSL rebuild
if [ "$SSL_SKIP" = "true" ]; then
    echo "Cleaning non-SSL packages..."
    # Only clean dedup, not SSL
    cmd="${PARSECDIR}/bin/parsecmgmt -a clean -p dedup"
    eval ${cmd}
    cmd="${PARSECDIR}/bin/parsecmgmt -a fulluninstall -p dedup"
    eval ${cmd}
else
    echo "Cleaning all packages..."
    cmd="${PARSECDIR}/bin/parsecmgmt -a clean -p all"
    eval ${cmd}
    cmd="${PARSECDIR}/bin/parsecmgmt -a fulluninstall -p all"
    eval ${cmd}
fi

for benchmark in ${BENCHMARKS[@]}; do
    echo "Building $benchmark..."
    
    # For RISC-V builds, handle SSL build errors gracefully
    if [ "$toolchain" = "riscv" ]; then
        # Try to build, but continue even if SSL apps/engines fail
        cmd="${PARSECDIR}/bin/parsecmgmt -a build -p ${benchmark}"
        eval ${cmd}
        
        # Check if the actual benchmark binary was created successfully
        BENCHMARK_BINARY="kernels/${benchmark}/obj/riscv64-linux.gcc/${benchmark}"
        INSTALL_DIR="kernels/${benchmark}/inst/riscv64-linux.gcc/bin"
        INSTALL_BINARY="${INSTALL_DIR}/${benchmark}"
        
        if [ -f "$BENCHMARK_BINARY" ]; then
            echo "✅ $benchmark binary successfully built"
            
            # Verify it's RISC-V format
            if file "$BENCHMARK_BINARY" | grep -q "UCB RISC-V"; then
                echo "✅ $benchmark is correctly built for RISC-V"
                
                # Create installation directory and copy binary
                echo "Installing $benchmark binary..."
                mkdir -p "$INSTALL_DIR"
                cp "$BENCHMARK_BINARY" "$INSTALL_BINARY"
                
                if [ -f "$INSTALL_BINARY" ]; then
                    echo "✅ $benchmark binary installed successfully"
                else
                    echo "❌ Failed to install $benchmark binary"
                fi
            else
                echo "❌ Warning: $benchmark is not RISC-V format"
            fi
        else
            echo "❌ $benchmark binary not found, build may have failed"
        fi
    else
        # For host builds, normal error handling
        cmd="${PARSECDIR}/bin/parsecmgmt -a build -p ${benchmark}"
        eval ${cmd}
    fi

    echo "Running $benchmark..."
    cmd="${PARSECDIR}/bin/parsecmgmt -a run -p ${benchmark} -i ${input_type}"
    eval ${cmd}

done

echo ""
echo "All Done!" 