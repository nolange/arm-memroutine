/* The MIT License (MIT)
 *
 * Copyright (c) 2013-2015 Norbert Lange
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 *  of this software and associated documentation files (the "Software"), to deal
 *  in the Software without restriction, including without limitation the rights
 *  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *  copies of the Software, and to permit persons to whom the Software is
 *  furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 *  all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 *  THE SOFTWARE.
 */

#ifndef __MEMSETPRIV_H
#define __MEMSETPRIV_H

#include "acle-compat.h"

/*  This file defines macros for the memset routines and allows some adjustment
 *
 * _MEMSET_THUMB         : if set the memset function will be a thumb function.
 *                         Planned to only being defined if the cpu does not
                           support arm mode
 *
 * _MEMSET_SMALLBLOCKLEN : this is the minimum of bytes necessary to trigger
 *                         writing 64byte memory blocks in a loop.
 *                         If the lenght argument is at least _MEMSET_SMALLBLOCKLEN
 *                         then 6 registers need to be pushed on the stack and
 *                         stores will be done using stmia instructions.
 *                         Must be >= 64 for correct operation.
 *
 * _MEMSET_SIMPLELOOP    : if defined, a simpler loop to set 64byte blocks will be used.
 *                         Instead of using store multiple the strd instruction (arm6+)
 *                         will be used.
 *                         this might be as fast or faster than the complex loop on newer cpus
 *                         but no measurements were done (lack of hardware)
 */

/* __THUMB_INTERWORK__ */

/* #if defined(__thumb__) && !defined(__ARM_ARCH_ISA_ARM)
 * Not sure if this means interworking problems */
#if defined(__thumb__)
#define _MEMSET_THUMB 1
#endif

#define _MEMSET_SMALLBLOCKLEN  96

#if __ARM_ARCH >= 7
#define _MEMSET_SIMPLELOOP 1
#endif

/* TODO: test mit 32? */
#if !defined(_MEMSET_SIMPLELOOP) && (_MEMSET_SMALLBLOCKLEN) < 95
#error Must use atleast 95 bytes for correct operation
#endif

#if 0 && defined(__VFP_FP__) && !defined(__SOFTFP__)
/* strangely this might fail with gcc5 if mfpu is not specified, macros are identical wether this option is given or not
 * clang3.6 behaves more reasonable */
#define _MEMSET_FPU
#define _MEMSET_SIMPLELOOP 1
#endif

#if defined(__ASSEMBLER__)

	/* Now some macros for common instruction sequences.  */
.macro  RETURN     cond=
#if __ARM_ARCH_ISA_THUMB >= 1
    bx\cond lr
#else
    mov\cond pc, lr
#endif
.endm

    .text
    .syntax unified

/* Select the correct minimal required isa */
#ifndef _MEMSET_THUMB
	.arm
#if   __ARM_ARCH >= 6
/* for pkhbt */
	.arch armv6
#elif defined(__ARM_ARCH_5TE__) || defined(__ARM_ARCH_5E__)
/*  armv5e would fit, but its not supported by gcc anymore? */
	.arch armv5te
#elif __ARM_ARCH >= 4
#if __ARM_ARCH_ISA_THUMB >= 1
	.arch armv4t
#else
	.arch armv4
#endif
#else
	.arch armv2
// #error Need Arm Arch 4 or better
#endif

#else /* defined _MEMSET_THUMB */
	.thumb
#if __ARM_ARCH_ISA_THUMB >= 2
#if __ARM_ARCH >= 8
	.arch armv8-a
#else
	.arch armv6t2
#endif
#else
	.arch armv4t
#endif

#endif /* defined _MEMSET_THUMB */

.macro  FUNCTION name
		.global \name
		.type   \name, %function
#ifdef _MEMSET_THUMB
		.thumb_func
#endif
\name:
.endm


/* define a macro if strd should be used for double register writes
 *
 * strd is available in *some* armv5te cpus (ARMv5TExP is the exception)
 * and in armv6 cpus and higher -> dont use it in anything before armv6.
 *
 * write 2 registers and postincrement
 * when useable the strd instruction will be generated,
 * otherwise stmia will be generated.
 */
.macro  STORE8PI dst reg1 reg2 cond=
#if defined(_MEMSET_THUMB) && __ARM_ARCH_ISA_THUMB == 1
.ifnb \cond
/* make it fail, cond likely mess up the code */
    error
	bnot\cond 1f
	stmia \dst!, {\reg1, \reg2}
	adds \dst, #8
1:
.else
	stmia \dst!, {\reg1, \reg2}
.endif
#elif __ARM_ARCH >= 6
	strd\cond \reg1, [\dst], #8
#else
	stmia\cond \dst!, {\reg1, \reg2}
#endif
.endm

/* define a macro for strh, since this is not available for older CPUS
 */
.macro  STORE2BI ptr val tmp cond=
#if __ARM_ARCH >= 4
.ifnb \cond
#if !defined(_MEMSET_THUMB)
    strh\cond \val, [\ptr], #2
#elif __ARM_ARCH >= 8
    /* 32bit instruction deprecated for armv8 */
    it    \cond
    strh\cond \val, [\ptr]
    it    \cond
    add\cond \ptr, #2
#elif __ARM_ARCH_ISA_THUMB >= 2
    it    \cond
    strh\cond \val, [\ptr], #2
#else
    /* make it fail, cond likely mess up the code */
    error
    bnot\cond 132f
    strh \val, [\ptr]
    adds \ptr, #2
132:
#endif
.else
#if !defined(_MEMSET_THUMB) || __ARM_ARCH_ISA_THUMB >= 2
    strh \val, [\ptr], #2
#else
    error /* changes condition code - BAD! */
    strh \val, [\ptr]
    adds \ptr, #2
#endif
.endif
#else
#if defined(__ARM_BIG_ENDIAN)
    lsl   \tmp, \val, #8
#else
    lsr   \tmp, \val, #8
#endif
	strb\cond \val, [\ptr], #2
	strb\cond \tmp, [\ptr, #-1]
#endif
.endm

#endif // ifdef __ASSEMBLER__

#endif // ifndef __MEMSETPRIV_H
