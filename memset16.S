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

#if defined(__WCHAR_MAX__) && (__WCHAR_MAX__ >= 32767 && __WCHAR_MAX__ <= 65535)
FUNCTION wmemset
#endif
FUNCTION _memset16
	cmp    r2, #6
	mov    ip, r0
	blo    .Lsupershort16

/* Splat halfword over register */
#if defined(_MEMSET_THUMB) && !defined(__thumb2__)
	/* Splat halfword over register */
	lsls   r3, r1, #16
	lsls   r1, r2, #1
	lsrs   r2, r3, #16
	orrs   r2, r3

#elif 0 && __ARM_ARCH >= 6 /* disabled - no improvement */
    movs   r3, r1
    lsls   r1, r2, #1
    pkhbt  r2, r3, r3, LSL #16
#else
	lsls   r3, r1, #16
	lsls   r1, r2, #1
	orr    r2, r3, r3, LSR #16
#endif

#   bcs    1f
    /* len >= 4GB - just make it crash hard enough so its similar to what you would get with a simple loop */
#   asrs   r1, r2, #31

# 1:

#	ite    cs
#	subcs  r1, r0, #2  /* len >= 4GB - just make it crash hard enough so its similar to what you would get with a simple loop */
#	addcc  r1, r0, r1

#    subs r1, r0

1:
#if defined(_MEMSET_THUMB) && !defined(__thumb2__)
    ldr    r3, =_memset16entry
    bx     r3
#else
    b      _memset16entry
#endif

.Lsupershort16:
	subs   r2, #1
	blo    2f

1:
#if !defined(_MEMSET_THUMB) || __ARM_ARCH_ISA_THUMB >= 2
    subs   r2, #1
    STORE2BI r0, r1, r3
#else
    strh   r1, [r0]
    adds   r0, #2
    subs   r2, #1
#endif
	bhs    1b
2:
    mov    r0, ip
	RETURN
.size	_memset16, . - _memset16
