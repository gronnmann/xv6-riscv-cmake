cmake_minimum_required(VERSION 3.12)
project(xv6 C ASM)

# Setup GCC

message(STATUS "Using GCC: ${CMAKE_C_COMPILER}")
message(STATUS "Source dir: " ${CMAKE_SOURCE_DIR})

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wall -Werror -O -fno-omit-frame-pointer -ggdb -gdwarf-2")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -MD -mcmodel=medany -ffreestanding -fno-common -nostdlib -mno-relax")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -I.")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -z max-page-size=4096")

execute_process(COMMAND ${CMAKE_C_COMPILER} -fno-stack-protector -E -x c /dev/null OUTPUT_VARIABLE stack_protector_output ERROR_QUIET)
if (stack_protector_output)
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fno-stack-protector")
endif()


# Set correct TOOLPREFIX
if (NOT DEFINED TOOLPREFIX)
    execute_process(
            COMMAND bash -c "if riscv64-unknown-elf-objdump -i 2>&1 | grep 'elf64-big' >/dev/null 2>&1; \
                         then echo 'riscv64-unknown-elf-'; \
                         elif riscv64-linux-gnu-objdump -i 2>&1 | grep 'elf64-big' >/dev/null 2>&1; \
                         then echo 'riscv64-linux-gnu-'; \
                         elif riscv64-unknown-linux-gnu-objdump -i 2>&1 | grep 'elf64-big' >/dev/null 2>&1; \
                         then echo 'riscv64-unknown-linux-gnu-'; \
                         else echo '*** Error: Couldn''t find a riscv64 version of GCC/binutils.'; \
                              echo '*** To turn off this error, run ''cmake -DTOOLPREFIX=...''.'; \
                              exit 1; fi"
            OUTPUT_VARIABLE TOOLPREFIX
            OUTPUT_STRIP_TRAILING_WHITESPACE
    )
endif()
message(STATUS "TOOLPREFIX: ${TOOLPREFIX}")

set(OBJCOPY "${TOOLPREFIX}objcopy")
set(OBJDUMP "${TOOLPREFIX}objdump")
set(LD "${TOOLPREFIX}ld")
set(LDFLAGS "-z max-page-size=4096")


message(STATUS "objcopy: ${OBJCOPY}")
message(STATUS "objdump: ${OBJDUMP}")
message(STATUS "ld: ${LD}") # TODO are we even using this


# Define userspace and kernel files

set(KERNEL_SOURCE_FILES
        kernel/entry.S
        kernel/start.c
        kernel/console.c
        kernel/printf.c
        kernel/uart.c
        kernel/kalloc.c
        kernel/spinlock.c
        kernel/string.c
        kernel/main.c
        kernel/vm.c
        kernel/proc.c
        kernel/swtch.S
        kernel/trampoline.S
        kernel/trap.c
        kernel/syscall.c
        kernel/sysproc.c
        kernel/bio.c
        kernel/fs.c
        kernel/log.c
        kernel/sleeplock.c
        kernel/file.c
        kernel/pipe.c
        kernel/exec.c
        kernel/sysfile.c
        kernel/kernelvec.S
        kernel/plic.c
        kernel/virtio_disk.c
)

SET(USER_EXECUTABLES
    U/_cat
	U/_echo
	U/_forktest
	U/_grep
	U/_init
	U/_kill
	U/_ln
	U/_ls
	U/_mkdir
	U/_rm
	U/_sh
	U/_stressfs
	U/_usertests
	U/_grind
	U/_wc
	U/_zombie)
# Add kernel executable
message(STATUS "Building kernel...")

# TODO - do something with the -z max-page-size for the linker?
add_executable(kernel ${KERNEL_SOURCE_FILES} kernel/kernel.ld)
set_target_properties(kernel PROPERTIES LINK_FLAGS "-e _entry")
# Place all the .o files there for the objdump

set_target_properties(kernel PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}
)

# TODO - CMAke seems to escape all the weird characters in the sed command.
# make it run on cmake instead of the .sh file.

add_custom_command(
        TARGET kernel
        POST_BUILD
        COMMAND ${OBJDUMP} -S ${CMAKE_BINARY_DIR}/kernel > ${CMAKE_BINARY_DIR}/kernel.asm
#        COMMAND ${OBJDUMP} -t ./kernel | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > kernel.sym
        COMMAND ${OBJDUMP} -t ${CMAKE_BINARY_DIR}/kernel | ${CMAKE_SOURCE_DIR}/extract_symbols_bypass.sh > ${CMAKE_BINARY_DIR}/kernel.sym
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
)

# User initcode

add_library(initcode OBJECT user/initcode.S) # TODO - objcopy and objdump?
#add_executable(initcode user/initcode.S)
##set_target_properties(initcode PROPERTIES LINK_FLAGS "-e _start")
target_compile_options(initcode PRIVATE -march=rv64g -nostdinc)
target_include_directories(initcode PRIVATE ${CMAKE_SOURCE_DIR} ${CMAKE_SOURCE_DIR}/kernel)

set_target_properties(initcode PROPERTIES
        LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}
)

#add_custom_command(
#        TARGET initcode
#        POST_BUILD
#        COMMAND ${OBJDUMP} -S ${CMAKE_BINARY_DIR}/initcode > ${CMAKE_BINARY_DIR}/initcode.asm
#        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
#)

add_custom_command(
        OUTPUT user/usys.S
		COMMAND mkdir user
        COMMAND perl ${CMAKE_SOURCE_DIR}/user/usys.pl > user/usys.S
        DEPENDS user/usys.pl
		WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
)
add_custom_target(usys_perl_to_c)

add_library(usys OBJECT user/usys.S)
target_include_directories(usys PRIVATE ${CMAKE_SOURCE_DIR})

add_dependencies(usys usys_perl_to_c)

#add_custom_target(usys DEPENDS user/usys.S)

#add_library(ulib user/ulib.c user/usys.o user/printf.c user/umalloc.c)