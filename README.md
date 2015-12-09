# arm-memroutine
Efficient C-Routines for old and new 32bit ARMs

This startet as simple routine on an Freescale imx28 running an RTOS. The routines in newlib have optimized assembly for modern ARMs,
but use simple C-Functions for older ones. Some simple test gave 2-3 times speedup, particularly most improvements with uncached access.

The real trouble came with supporting ALL 32bit ARM processors (down to arm2), both Thumb and ARM mode... and being able to test the various different
flavours of code. Recently I bought an RK3288 based board running Linux, allowing convenient testing and debugging.
The only remaining issue being the lack of reliable performance measurements - which should happen without a OS.

# TODO
- [ ] cleanup & document (will never be completed ?! )
- [ ] Research Interworking issues, ideally thumb1 code will never be used unless the cpu doesnt support ARM
- [ ] Run some performance test without OS. A full OS like Linux drowns any small to medium difference.
- [ ] more functions - memcpy, memchr.. ?
- [ ] get the stuff into newlib.

# files
acle-compat.h:
  Defines some standardized macros for the various ARM Architectures. (c) 2014 ARM Ltd

memsetpriv.h:
  Sets macros for the memset family of functions. some calls are across source files, so for example the mode (thumb/arm) needs to be consistent.
  Common functionality will be farmed out, when/if more functions like memcpy are implemented.
  
memset8.S:
  Main memset routine, the inner loop copies 64 bytes per iteration.
  Various entry points exist for _eabi_memset and _eabi_memclr variants, and seperate ones for memset16/memset32.
  A seperate implementation for Thumb1 exists, which is slower than than Thumb2 and Arm.
  
memset16.S, memset32.S:
  memset routine for 16/32bit values, one of these will have an alias for wmemset. Destination address needs to be correctly aligned 
  (otherwise this will cause an access fault or increased runtime depending on how the cpu deals with unaligned accesses)
  
memset_c.c:
  This reassembles the assembly code, was used as skeleton initially, can now be used to get an overview.
  
testmemset.c:
  Together with the Makefile, this will include variants of the routines for different cpu-architectures.
  Used for testing/debugging and perftests (very coarse in a non-RTOS).
  
# make targets
The included makefile is primary for building tests. The used compiler should be defined as CC_FOR_TARGET.
At the core it replaces the function names with suffixes for different flags/architecturs

archs.mk:
  calls the compiler, expecting a warning listing all the possible values for -march, then testing whether the architecture supports thumb or arm.
  Putting everything in Variables to be used by the Makefile.
  
memsettable.c:
  Table of function pointers to all variants of _memsetN for each architecture in archs.mk

testmemset:
  Creates the arm-linux test program including all variants of _memsetN
