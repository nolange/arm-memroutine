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

#if (__WCHAR_MAX__ >= 2147483647UL && __WCHAR_MAX__ <= 4294967295UL)
FUNCTION wmemset
#endif
FUNCTION _memset32
    movs   r3, r1

    cmp    r2, #(_MEMSET_SMALLBLOCKLEN / 4)
    mov    ip, r0
    blo    .Lsupershort32

    lsls   r1, r2, #2
    movs   r2, r3

    /* r0 - ptr, r1: size, r2: fill, ip: org  */
#if defined(_MEMSET_THUMB) && !defined(__thumb2__)
    ldr    r3, =_memset32entry
    bx     r3
#else
    b      _memset32entry
#endif

.Lsupershort32:
#if defined(_MEMSET_THUMB) && !defined(__thumb2__)
    lsrs   r1, r2, #1
    movs   r2, r3
	bcc    1f
	stmia  r0!, {r2}
1:
    cmp    r1, #0
    beq    2f
#else
	lsrs   r1, r2, #1
	mov    r2, r3
#if !defined(_MEMSET_THUMB) || __ARM_ARCH < 8
	it     cs
	strcs  r2, [r0], #4
#else
    it     cs
    strcs  r2, [r0]
    it     cs
    addcs  r0, #4
#endif
    beq    2f
#endif

1:
	subs   r1, #1
	STORE8PI r0, r2, r3
	bne    1b
2:
	mov    r0, ip
	RETURN
.size	_memset32, . - _memset32

