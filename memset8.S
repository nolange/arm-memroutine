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

#include "acle-compat.h"
#include "memsetpriv.h"

#if !defined(_MEMSET_THUMB) || defined(__thumb2__) /* || defined(__ARM_ARCH_ISA_ARM) */

#if defined(__WCHAR_MAX__) && __WCHAR_MAX__ <= 255
FUNCTION wmemset
#endif
FUNCTION _memset8
    /* fixup registers to look like the many __eabi calls */
    lsls   r3, r1, #24
    movs   r1, r2

    cmp    r1, #3

    bhi    .Lmemset32sharedPre

    it     ls /* so we dont mess up the flags in thumb */
    lsrls  r2, r3, #24

.Lsupershort8eabi:
	/* we can only end up here if len <=3 */

 	it     eq /* if len == 3 */
	strbeq r2, [r0, #2]

	cmp    r1, #1
 	it     hs /* if len >= 1 */
	strbhs r2, [r0, #0]

	it     hi /* if len > 1 */
	strbhi r2, [r0, #1]

	RETURN


FUNCTION __aeabi_memclr
    movs   r2, #0

FUNCTION __aeabi_memset
FUNCTION __aeabi_memset4
FUNCTION __aeabi_memset8
    lsls   r3, r2, #24
	cmp    r1, #3

	bls    .Lsupershort8eabi


/* r0 - ptr, r1: size, r3: Fill (in highbyte) */
.Lmemset32sharedPre:
	orr    r2, r3, r3, lsr #8
	orr    r2, r2, r2, lsr #16  /* r2 = fill */
/*  Optimized 32bit memset
 *
 *  Writes a 32bit value n times to the given address. Can deal with unaligned addresses.
 *  This routine is called from within all other memset routines
 *
 * The properties and rationale of this implementation are:
 * - uste store multiple ins, since some CPUS can generate burst writes to DRam with stm.
 *   	eg. ARM926EJ-S can generate 4 or 8 word bursts, result in 2-3 times the bandwidth of regular memset
 * - optimized block loops
 *   	the slower the cpu compared to the ram (and cache) the more it gains from optimized code
 * - writes are always (fully) aligned to the write-size
 * - amount of write instructions should be as small as reasonably possible
 *   	archs without Ooe or using uncached accesses can stall on memory accesses
 * - doesnt need to spill registers to the stack for small lengths (= doesnt need a stack at all)
 */
FUNCTION _memset32shared
/* private entry point */
/* TODO: ARM Mode will be used for thumb1 CPUs which support it */
.Lmemset32shared:
    /* atleast 4 bytes to copy */
    mov    ip, r0

	/* r0 - ptr, r1: endptr, r2: fill, ip: org  */
	/* align to 4 byte */
#if 0
    /* This is code to correctly rotate the fillvalue
     * for wmemset while aligning destination address.
     * The perf hit is not worth it */
#if defined(__ARMEL__)
	lsrs   r3, r0, #1
	itt    cs
	strbcs r2, [r0], #1
	rorcs  r2, #8

FUNCTION _memset16entry
	lsrs   r3, r0, #2
	itt    cs
	strhcs r2, [r0], #2
	rorcs  r2, #16

#elif defined(__ARMEB__)
	lsrs   r3, r0, #1
	itt    cs
	rorcs  r2, #24
	strbcs r2, [r0], #1

FUNCTION _memset16entry
	lsrs   r3, r0, #2
	itt    cs
	rorcs  r2, #16
	strhcs r2, [r0], #2
#else
#error Undefined endian
#endif
#else

	lsrs   r3, r0, #1
#if __ARM_ARCH < 8
	it     cs
	strbcs r2, [r0], #1
#else
    it     cs
    strbcs r2, [r0]
    it     cs
    addcs  r0, #1
#endif

FUNCTION _memset16entry
.Lmemset16entry:
	lsrs   r3, r0, #2
	STORE2BI r0, r2, r3, cs
#endif

    /* correct the written bytes by substracting the count from size */
    subs   r3, r0, ip
    subs   r1, r3

    b      .Lmemset32entry

FUNCTION __aeabi_memclr4
FUNCTION __aeabi_memclr8
    movs   r2, #0

FUNCTION _memset32entry
.Lmemset32entry:
	/* r0 - ptr, r1: size, r2: fill, ip: org  */

	/* align to 8 byte if rem big enough */
	lsrs   r3, r1, #2 /* rem >= 4 bytes -> ne */
#if !defined(_MEMSET_THUMB) || __ARM_ARCH < 8
    mov    r3, r2
	it     ne
	tstne  r0, #4 /* addr needs alignment -> ne (only tst and cmp set flags in it block) */
	itt    ne
	strne  r2, [r0], #4
	subne  r1, #4
#else
    beq 1f
    lsrs   r3, r0, #(2 + 1) /* shift the 2nd bit into carry */
    bcc 1f
    stmia  r0!, {r2}
    subs   r1, #4
1:
    movs   r3, r2
#endif

#if !(defined(_MEMSET_SIMPLELOOP) && (_MEMSET_SIMPLELOOP != 0))
	/* r0 - ptr(align 4), r1: rem, r2: fill, r3: fill, ip: org  */

	/* take the short routine, unless the long is faster
	 * the value needs to be atleast 128 for correct operation
	 */
	cmp    r1, #(_MEMSET_SMALLBLOCKLEN) /* todo: research better value! */

	/* r0: ptr(align 4 or 8), r1: rem, r2: fill, r3: fill, ip: org */
	blo    .Lskiplong

	/* if big enough store registers on stack and use 64byte loop */
	push   {r4 - r9}

	/* set 8 registers to fill value inbetween dependend instructions */

	/* align to 32 bytes, 64 bytes would be easily doable but wouldnt help at all */

	adds   r1, r0 /* store endptr */
	movs   r4, r2

	lsrs   r7, r0, #(3 + 1) /* shift the 3rd bit into carry */
	mov    r9, r2
	it     cs
	STORE8PI r0, r2, r3, cs
	movs   r5, r2

	lsrs   r7, r0, #(4 + 1) /* shift the 4t bit into carry */
	mov    r6, r2
	it     cs
	stmiacs r0!, {r2 - r5}

	subs   r1, r0 /* recalculate remaining */

	subs   r1, #64
	mov    r8, r2
	lsrs   r7, r1, #(5 + 1) /* jump to second write if at least 32 byte would remain after loop
	* , the count gets masked away to < 16 bytes so dont bother decrementing */
	mov    r7, r2
	bcs    2f

	/* r0 - ptr(align 32), r1: rem-64, r2 - r9: fill, ip: org */

	/* 64 byte set loop
	 * To enable dual-issue, stm must be in pipeline 0 (Cortex A8, possibly others)
	 * alignment to 8 byte should help ifetches too */
#ifndef _MEMSET_THUMB
.align 3
#endif
1:
	stmia  r0!, {r2 - r9}
	subs   r1, #64
2:
	stmia  r0!, {r2 - r9}
	bhs    1b

	lsrs   r7, r1, #(4 + 1) /* still a 16 byte-block remaining? */
	it     cs
	stmiacs r0!, {r2 - r5}

	and    r1, #0xF /* fixup remaining  */

	pop    {r4 - r9}

#elif defined( _MEMSET_FPU) /* defined(_MEMSET_SIMPLELOOP) && (_MEMSET_SIMPLELOOP != 0) */
    /* r0 - ptr(align 4), r1: rem, r2: fill, r3: fill, ip: org  */

	subs   r1, #32
	blo    2f /* skip if less than 32 byte */

    /* 32byte copy loop using fpu registers */
#ifdef __ARM_NEON__
	veor   q0, q0
	veor   q1, q1
#else
	vmov   d0, r2, r2
	vmov.f64   d1, d0
	vmov.f64   d2, d0
	vmov.f64   d3, d0
#endif
1:
    subs   r1, #32
    vstm   r0!, {q0, q1}
    bhs    1b

2:
    adds   r1, #32

#else /* defined(_MEMSET_SIMPLELOOP) && (_MEMSET_SIMPLELOOP != 0) */
    /* r0 - ptr(align 4), r1: rem, r2: fill, r3: fill, ip: org  */
    subs   r1, #32
    blo    2f /* skip if less than 32 byte */

    /* 32byte copy loop using r2, r3 */
#ifndef _MEMSET_THUMB
.align 3
#endif
1:
#if __ARM_ARCH >= 6
	strd   r2, [r0], #32
	subs   r1, #32
	strd   r2, [r0, #(0x08 - 32)]
	strd   r2, [r0, #(0x10 - 32)]
	strd   r2, [r0, #(0x18 - 32)]
#else
	stmia  r0!, {r2, r3}
	subs   r1, #32
	stmia  r0!, {r2, r3}
	stmia  r0!, {r2, r3}
	stmia  r0!, {r2, r3}
#endif
    bhs    1b

    2:
    adds   r1, #32
#endif /* defined(_MEMSET_SIMPLELOOP) && (_MEMSET_SIMPLELOOP != 0) */

.Lskiplong:

	/* we are either aligned to 8 byte,
	 * or to 4 byte with less than 4 bytes remaining
	 * or no bytes are remaining */
	subs   r1, #8
	blo    2f /* skip if less than 8 byte */

	/* r0 - ptr(align 8), r1: rem-8, r2: fill, r3: fill, ip: org */

1:   /* 8 byte set loop */
	subs   r1, #8
	STORE8PI r0, r2, r3
	bhs    1b
2:

	/* r0 - ptr(align 4), r1: rem - 8, r2: fill, r3: fill, ip: org
	 * test the bits in rem while use shifts since those are smaller opcodes in thumb */

	/* write remaining bytes in optimal aligned manner */
	lsls   r1, #(32 - 2)
#if !defined(_MEMSET_THUMB) || __ARM_ARCH < 8
	it     cs
	strcs  r2, [r0], #4
#else
    it     cs
    strcs  r2, [r0]
    it     cs
    addcs  r0, #4
#endif

/* write last < 4 bytes */
#if 0
#if defined(__ARMEL__)
	lsls   r1, #1
	itt    cs
	strhcs r2, [r0], #2
	lsrcs  r2, #16

	lsls   r1, #1
	it     cs
	strbcs r2, [r0]
#elif defined(__ARMEB__)
	lsls   r1, #1
	itt    cs
	rorcs  r2, #16
	strhcs r2, [r0], #2

	lsls   r1, #1
	itt    cs
	lsrcs  r2, #24
	strbcs r2, [r0]
#else
#error Undefined endian
#endif
#else
	lsls   r1, #1
	STORE2BI r0, r2, r3, cs

	lsls   r1, #1
	it     cs
	strbcs r2, [r0]
#endif

	mov    r0, ip
	RETURN
.size	_memset32shared, . - _memset32shared
#else /* !defined(__thumb__) || defined(__thumb2__) */

/* Thumb 1 */
#if defined(__WCHAR_MAX__) && __WCHAR_MAX__ <= 255
FUNCTION wmemset
#endif
FUNCTION _memset8
    /* fixup registers to look like the many __eabi calls */
    lsls   r3, r1, #24
    movs   r1, r2

    cmp    r1, #3

    bhi    .Lmemset32sharedPre

    lsrs  r2, r3, #24
    cmp    r1, #3

.Lsupershort8eabi:
    /* we can only end up here if len <=3 */

    bne    1f
    strb   r2, [r0, #2] /* if len == 3 */
1:
    cmp    r1, #1
    blo    1f
    strb   r2, [r0, #0] /* if len >= 1 */
1:
    bls    1f
    strb   r2, [r0, #1] /* if len > 1 */
1:
    RETURN


FUNCTION __aeabi_memclr
    movs   r2, #0

FUNCTION __aeabi_memset
FUNCTION __aeabi_memset4
FUNCTION __aeabi_memset8
    lsls   r3, r2, #24
    cmp    r1, #3

    bls    .Lsupershort8eabi


/* r0 - ptr, r1: size, r3: Fill (in highbyte) */
.Lmemset32sharedPre:
    lsrs   r2, r3, #8
    orrs   r3, r2
    lsrs   r2, r3, #16
    orrs   r2, r3
/*  Optimized 32bit memset
 *
 *  Writes a 32bit value n times to the given address. Can deal with unaligned addresses.
 *  This routine is called from within all other memset routines
 *
 * The properties and rationale of this implementation are:
 * - uste store multiple ins, since some CPUS can generate burst writes to DRam with stm.
 *      eg. ARM926EJ-S can generate 4 or 8 word bursts, result in 2-3 times the bandwidth of regular memset
 * - optimized block loops
 *      the slower the cpu compared to the ram (and cache) the more it gains from optimized code
 * - writes are always (fully) aligned to the write-size
 * - amount of write instructions should be as small as reasonably possible
 *      archs without Ooe or using uncached accesses can stall on memory accesses
 * - doesnt need to spill registers to the stack for small lengths (= doesnt need a stack at all)
 */
FUNCTION _memset32shared
/* private entry point */
/* TODO: ARM Mode will be used for thumb1 CPUs which support it */
.Lmemset32shared:
    /* atleast 4 bytes to copy */
    mov    ip, r0

    /* r0 - ptr, r1: endptr, r2: fill, ip: org  */
    /* align to 4 byte */
#if 0
    /* This is code to correctly rotate the fillvalue
     * for wmemset while aligning destination address.
     * The perf hit is not worth it */
#if defined(__ARMEL__)
    lsrs   r3, r0, #1
    itt    cs
    strbcs r2, [r0], #1
    rorcs  r2, #8

FUNCTION _memset16entry
    lsrs   r3, r0, #2
    itt    cs
    strhcs r2, [r0], #2
    rorcs  r2, #16

#elif defined(__ARMEB__)
    lsrs   r3, r0, #1
    itt    cs
    rorcs  r2, #24
    strbcs r2, [r0], #1

FUNCTION _memset16entry
    lsrs   r3, r0, #2
    itt    cs
    rorcs  r2, #16
    strhcs r2, [r0], #2
#else
#error Undefined endian
#endif
#else

    lsrs   r3, r0, #1
    bcc    1f
    strb   r2, [r0]
    adds   r0, #1
1:

FUNCTION _memset16entry
.Lmemset16entry:
    lsrs   r3, r0, #2
    bcc    1f
    strh   r2, [r0]
    adds   r0, #2
1:
#endif

    /* correct the written bytes by substracting the count from size */
    mov    r3, ip
    subs   r3, r0, r3
    subs   r1, r3

    b      .Lmemset32entry

FUNCTION __aeabi_memclr4
FUNCTION __aeabi_memclr8
    movs   r2, #0

FUNCTION _memset32entry
.Lmemset32entry:
    /* r0 - ptr, r1: size, r2: fill, ip: org  */

    /* align to 8 byte if rem big enough */
    lsrs   r3, r1, #2 /* rem >= 4 bytes -> ne */

    beq 1f
    lsrs   r3, r0, #(2 + 1) /* shift the 2nd bit into carry */
    bcc 1f
    stmia  r0!, {r2}
    subs   r1, #4
1:
    movs   r3, r2

#if !(defined(_MEMSET_SIMPLELOOP) && (_MEMSET_SIMPLELOOP != 0))
    /* r0 - ptr(align 4), r1: rem, r2: fill, r3: fill, ip: org  */

    /* take the short routine, unless the long is faster
     * the value needs to be atleast 128 for correct operation
     */
    cmp    r1, #(_MEMSET_SMALLBLOCKLEN) /* todo: research better value! */

    /* r0: ptr(align 4 or 8), r1: rem, r2: fill, r3: fill, ip: org */
    blo    .Lskiplong

    /* if big enough store registers on stack and use 64byte loop */
    push   {r4 - r5, r6, r7}

    /* set 8 registers to fill value inbetween dependend instructions */

    /* align to 32 bytes, 64 bytes would be easily doable but wouldnt help at all */

    adds   r1, r0 /* store endptr */
    movs   r4, r2

    lsrs   r7, r0, #(3 + 1) /* shift the 3rd bit into carry */
    bcc    1f
    STORE8PI r0, r2, r3
1:
    movs   r5, r2

    lsrs   r7, r0, #(4 + 1) /* shift the 4t bit into carry */
    bcc    1f
    stmia  r0!, {r2 - r5}
1:

    subs   r1, r0 /* recalculate remaining */

    subs   r1, #64
    lsrs   r7, r1, #(5 + 1) /* jump to second write if at least 32 byte would remain after loop
    * , the count gets masked away to < 16 bytes so dont bother decrementing */
    bcs    2f

    /* r0 - ptr(align 32), r1: rem-64, r2 - r5: fill, ip: org */

    /* 64 byte set loop
     * To enable dual-issue, stm must be in pipeline 0 (Cortex A8, possibly others)
     * alignment to 8 byte should help ifetches too */
1:
    stmia  r0!, {r2 - r5}
    stmia  r0!, {r2 - r5}
    subs   r1, #64
2:
    stmia  r0!, {r2 - r5}
    stmia  r0!, {r2 - r5}
    bhs    1b

    lsrs   r7, r1, #(4 + 1) /* still a 16 byte-block remaining? */
    bcc    1f
    stmia  r0!, {r2 - r5}
1:
    movs   r5, #15
    ands   r1, r5 /* fixup remaining  */

    pop    {r4 - r5, r6, r7}


#endif /* defined(_MEMSET_SIMPLELOOP) && (_MEMSET_SIMPLELOOP != 0) */

.Lskiplong:

    /* we are either aligned to 8 byte,
     * or to 4 byte with less than 4 bytes remaining
     * or no bytes are remaining */
    subs   r1, #8
    blo    2f /* skip if less than 8 byte */

    /* r0 - ptr(align 8), r1: rem-8, r2: fill, r3: fill, ip: org */

1:   /* 8 byte set loop */
    subs   r1, #8
    STORE8PI r0, r2, r3
    bhs    1b
2:

    /* r0 - ptr(align 4), r1: rem - 8, r2: fill, r3: fill, ip: org
     * test the bits in rem while use shifts since those are smaller opcodes in thumb */

    /* write remaining bytes in optimal aligned manner */
    lsls   r1, #(32 - 2)
    bcc    1f
    stmia  r0!, {r2}
1:

/* write last < 4 bytes */
#if 0
#if defined(__ARMEL__)
    lsls   r1, #1
    itt    cs
    strhcs r2, [r0], #2
    lsrcs  r2, #16

    lsls   r1, #1
    it     cs
    strbcs r2, [r0]
#elif defined(__ARMEB__)
    lsls   r1, #1
    itt    cs
    rorcs  r2, #16
    strhcs r2, [r0], #2

    lsls   r1, #1
    itt    cs
    lsrcs  r2, #24
    strbcs r2, [r0]
#else
#error Undefined endian
#endif
#else
    lsls   r1, #1
    bcc    1f
    strh   r2, [r0]
    adds   r0, #2
1:

    lsls   r1, #1
    bcc    1f
    strb   r2, [r0]
1:
#endif

    mov    r0, ip
    RETURN
.size   _memset32shared, . - _memset32shared

#endif /* !defined(__thumb__) || defined(__thumb2__) */
