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

#define _MEMSET_SMALLBLOCKLEN 32
// #define _MEMSET_SIMPLELOOP
#define _ISA_ARM_6

static __attribute__((always_inline)) inline unsigned *WriteUnsigned2(unsigned *ptr, unsigned out0,
        unsigned out1)
{
    /* Arm < 5E hat kein 64bit store und würde einzelbefehle generieren */
#if defined(__ARM_ARCH_2__) || defined(__ARM_ARCH_3__) || defined(__ARM_ARCH_4__) || defined(__ARM_ARCH_4T__) || defined(__ARM_ARCH_4T__) || defined(__ARM_ARCH_5__) || defined(__ARM_ARCH_5T__)
    register unsigned var0 __asm__ ("r2") = out0;
    register unsigned var1 __asm__ ("r3") = out1;

    __asm__( "stmia   %0!, {%3, %4}"
            : "+l" (ptr), "=m" (ptr[0]), "=m" (ptr[1])
            : "l" (var0), "l" (var1)
            : );
    return ptr;
#else
#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
    *(unsigned long long *) (ptr) = out0 | ((unsigned long long) (out1) << 32);
#elif __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
    *(unsigned long long *)(ptr) = ((unsigned long long)(out0) << 32) | out1;
#else
#error No endian defined
#endif
    return ptr + 2;
#endif
}

static __attribute__((always_inline)) inline unsigned *WriteUnsigned4(unsigned *ptr, unsigned out0,
        unsigned out1, unsigned out2, unsigned out3)
{
#if 1 // && defined(__thumb__) && !defined(__thumb2__)
    ptr = WriteUnsigned2(ptr, out0, out1);
    return WriteUnsigned2(ptr, out2, out3);
#else
    register unsigned var0 __asm__ ("r2") = out0;
    register unsigned var1 __asm__ ("r3") = out1;
    register unsigned var2 __asm__ ("r4") = out2;
    register unsigned var3 __asm__ ("r5") = out3;

    __asm__( "stmia   %0!, {%5, %6, %7, %8}"
            : "+l" (ptr), "=m" (ptr[0]), "=m" (ptr[1]), "=m" (ptr[2]), "=m" (ptr[3])
            : "l" (var0), "l" (var1), "l" (var2), "l" (var3)
            : );
    return ptr;
#endif
}

char *memset_c(char * restrict ptr, unsigned char fillC, unsigned len)
{
    if (len <= 3)
    {
        if (len >= 1)
            ptr[0] = fillC;
        if (len > 1)
            ptr[1] = fillC;
        if (len == 3)
            ptr[2] = fillC;
        return ptr;
    }
    unsigned fill = (unsigned) fillC;
    char *end = ptr + len;
    {
        unsigned shift = fill << 24;

        shift = shift | (shift >> 8);
        fill = shift | (shift >> 16);
    }

    /* Align 4 Byte */
    if ((unsigned) ptr & 1)
        *ptr++ = fill;
    if ((unsigned) ptr & 2)
    {
        *(unsigned short *) ptr = fill;
        ptr += 2;
    }

    unsigned remain = end - ptr;
    unsigned * restrict wordptr = (unsigned * restrict) ptr;

    if (remain >= 4 && ((unsigned) wordptr & 4))
    {
        *wordptr++ = fill;
        remain -= 4;
    }

    if (remain >= _MEMSET_SMALLBLOCKLEN)
    {
        if ((unsigned) wordptr & 8)
            wordptr = WriteUnsigned2(wordptr, fill, fill);
        if ((unsigned) wordptr & 16)
            wordptr = WriteUnsigned4(wordptr, fill, fill, fill, fill);

        remain = end - (char *) wordptr;

        remain -= 32;
        while ((int) remain >= 0)
        {
            wordptr = WriteUnsigned4(wordptr, fill, fill, fill, fill);
            wordptr = WriteUnsigned4(wordptr, fill, fill, fill, fill);
            remain -= 32;
        }

        if ((unsigned) remain & 16)
            wordptr = WriteUnsigned4(wordptr, fill, fill, fill, fill);
        remain &= 0xFU;
    }

    remain -= 8;
    while ((int) remain >= 0)
    {
        wordptr = WriteUnsigned2(wordptr, fill, fill);
        remain -= 8;
    }

    if (remain & 4)
        *wordptr++ = fill;
    ptr = (char * restrict) wordptr;
    if (remain & 2)
    {
        *(unsigned short *) ptr = fill;
        ptr += 2;
    }
    if (remain & 1)
        *ptr++ = fill;

    return 0;
}
