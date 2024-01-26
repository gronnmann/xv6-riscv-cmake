# xv6-discv-cmake
Makefile file from https://github.com/mit-pdos/xv6-riscv rewritten to work with CMake.

I started making this, as the original file really didn't work well with CLion.

Progress per 27.01.2023:
Kernel part works. Haven't had time to integrate the user parts yet.

To use, copy the CMakeLists.txt and extract_symbols_bypass.sh files into your xv6 installations.

Requirements:  
gcc-riscv64-linux-gnu  
binutils-riscv64-linux-gnu