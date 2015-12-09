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

#include <stddef.h>
#include <string.h>
#include <time.h>
// extern "C" void *Aboard_Memset(void *, int, size_t);
#include <stdio.h>
#include <stdbool.h>
#include <sys/mman.h>
#define __USE_GNU
#include <sched.h>
#include <wchar.h>
#include <stdint.h>
#define Aboard_Memset memset

struct CTablePtr {const void *_p; unsigned _size; unsigned _esize;};
extern struct CTablePtr g_Functable;

typedef void *(*memset_t)(void *, int, size_t);
struct CFuncEntry {const char *_name; memset_t _f_memset8 ; memset_t _f_memset16 ; memset_t _f_memset32 ; };

struct timespec pdifftime(struct timespec before, struct timespec after)
{
    struct timespec ts = {
        after.tv_sec - before.tv_sec - (after.tv_nsec < before.tv_nsec ? 1 : 0),
        after.tv_nsec < before.tv_nsec ? 1000000000 + after.tv_nsec - before.tv_nsec : after.tv_nsec - before.tv_nsec
    };
    return ts;
}

void setaffinity()
{
    cpu_set_t mask;
    CPU_ZERO( &mask );
    CPU_SET( sched_getcpu(), &mask );
    sched_setaffinity(0, sizeof(cpu_set_t), &mask);
}



//void *__aeabi_memset4_tarmv7_a(void *dest, size_t n, int fill);
//
//void *memseteabi(void *dest, int fill, size_t n)
//{
//    __aeabi_memset4_tarmv7_a(dest, n, fill);
//    return dest;
//}

static bool testmemset8(memset_t pf, void *wholeBlock, size_t wholeLen, void *ptr, size_t len, int fill, struct timespec *time)
{
    typedef uint8_t unit_t;
    unit_t *wholeP = (unit_t *)wholeBlock;
    size_t index = 0;
    size_t offsetP = (size_t)((char *)ptr - (char *)wholeBlock);
    size_t offsetE = offsetP + len;

    for (index = 0; index < wholeLen / sizeof(unit_t); ++index)
    {
        wholeP[index] = ~fill;
    }

    struct timespec before;
    clock_gettime(CLOCK_MONOTONIC, &before);
    void *retVal = pf(ptr, fill, len / sizeof(unit_t) );
    struct timespec after;
    clock_gettime(CLOCK_MONOTONIC, &after);
    time->tv_nsec = after.tv_nsec < before.tv_nsec ? 1000000000 + after.tv_nsec - before.tv_nsec : after.tv_nsec - before.tv_nsec;
    time->tv_sec = after.tv_sec - before.tv_sec - (after.tv_nsec < before.tv_nsec ? 1 : 0);

    if (ptr != retVal && retVal != 0)
        return false;
    for (index = 0; index < offsetP / sizeof(unit_t); ++index)
    {
        if (wholeP[index] != (unit_t)~fill)
            return false;
    }
    for (index = offsetP / sizeof(unit_t); index < offsetE / sizeof(unit_t); ++index)
    {
        if (wholeP[index] != (unit_t)fill)
            return false;
    }
    for (index = offsetE / sizeof(unit_t); index < wholeLen / sizeof(unit_t); ++index)
    {
        if (wholeP[index] != (unit_t)~fill)
            return false;
    }
    return true;
}

static bool testmemset16(memset_t pf, void *wholeBlock, size_t wholeLen, void *ptr, size_t len, int fill, struct timespec *time)
{
    typedef uint16_t unit_t;
    unit_t *wholeP = (unit_t *)wholeBlock;
    size_t index = 0;
    size_t offsetP = (size_t)((char *)ptr - (char *)wholeBlock);
    size_t offsetE = offsetP + len;

    for (index = 0; index < wholeLen / sizeof(unit_t); ++index)
    {
        wholeP[index] = ~fill;
    }

    struct timespec before;
    clock_gettime(CLOCK_MONOTONIC, &before);
    void *retVal = pf(ptr, fill, len / sizeof(unit_t) );
    struct timespec after;
    clock_gettime(CLOCK_MONOTONIC, &after);
    time->tv_nsec = after.tv_nsec < before.tv_nsec ? 1000000000 + after.tv_nsec - before.tv_nsec : after.tv_nsec - before.tv_nsec;
    time->tv_sec = after.tv_sec - before.tv_sec - (after.tv_nsec < before.tv_nsec ? 1 : 0);

    if (ptr != retVal && retVal != 0)
        return false;
    for (index = 0; index < offsetP / sizeof(unit_t); ++index)
    {
        if (wholeP[index] != (unit_t)~fill)
            return false;
    }
    for (index = offsetP / sizeof(unit_t); index < offsetE / sizeof(unit_t); ++index)
    {
        if (wholeP[index] != (unit_t)fill)
            return false;
    }
    for (index = offsetE / sizeof(unit_t); index < wholeLen / sizeof(unit_t); ++index)
    {
        if (wholeP[index] != (unit_t)~fill)
            return false;
    }
    return true;
}

static bool testmemset32(memset_t pf, void *wholeBlock, size_t wholeLen, void *ptr, size_t len, int fill, struct timespec *time)
{
    typedef uint32_t unit_t;
    unit_t *wholeP = (unit_t *)wholeBlock;
    size_t index = 0;
    size_t offsetP = (size_t)((char *)ptr - (char *)wholeBlock);
    size_t offsetE = offsetP + len;

    for (index = 0; index < wholeLen / sizeof(unit_t); ++index)
    {
        wholeP[index] = ~fill;
    }

    struct timespec before;
    clock_gettime(CLOCK_MONOTONIC, &before);
    void *retVal = pf(ptr, fill, len / sizeof(unit_t) );
    struct timespec after;
    clock_gettime(CLOCK_MONOTONIC, &after);
    time->tv_nsec = after.tv_nsec < before.tv_nsec ? 1000000000 + after.tv_nsec - before.tv_nsec : after.tv_nsec - before.tv_nsec;
    time->tv_sec = after.tv_sec - before.tv_sec - (after.tv_nsec < before.tv_nsec ? 1 : 0);

    if (ptr != retVal && retVal != 0)
        return false;
    for (index = 0; index < offsetP / sizeof(unit_t); ++index)
    {
        if (wholeP[index] != (unit_t)~fill)
            return false;
    }
    for (index = offsetP / sizeof(unit_t); index < offsetE / sizeof(unit_t); ++index)
    {
        if (wholeP[index] != (unit_t)fill)
            return false;
    }
    for (index = offsetE / sizeof(unit_t); index < wholeLen / sizeof(unit_t); ++index)
    {
        if (wholeP[index] != (unit_t)~fill)
            return false;
    }
    return true;
}

static bool testmemset(memset_t pf, unsigned gran, void *wholeBlock, size_t wholeLen, void *ptr, size_t len, int fill, struct timespec *time)
{
    switch (gran)
    {
    case 1:
        return testmemset8(pf, wholeBlock, wholeLen, ptr, len, fill, time);
    case 2:
        return testmemset16(pf, wholeBlock, wholeLen, ptr, len, fill, time);
    case 4:
        return testmemset32(pf, wholeBlock, wholeLen, ptr, len, fill, time);
    default:
        abort();
    }
}

void memsettest(memset_t, unsigned gran);

#define TEST_MAXOFFSET 64
#define TEST_MAXSMALL 64
#define TEST_MAXBOCKS 32
#define TEST_BLOCKSIZE 32

char buffer[32 + TEST_MAXOFFSET + TEST_MAXSMALL + TEST_BLOCKSIZE * TEST_MAXBOCKS + 32] __attribute__((__aligned__(64)));

int main(int argc, char **argv)
{
    struct timespec time;
    const struct CFuncEntry * const pStart = (const struct CFuncEntry *)g_Functable._p, * const pEnd = (const struct CFuncEntry *)g_Functable._p + g_Functable._size;
    unsigned i = 0;
    const struct CFuncEntry *pIter;
    setaffinity();

    bool result = testmemset(pStart[23]._f_memset32, 4, buffer, sizeof(buffer), buffer + 32 + 0x0, 4, 0x55565758, &time);
    if (!result)
    {
        abort();
    }
    for (i = 0; i < 2; ++i)
    {
        printf("warmup caches\n");
        memsettest(&memset, 1);
        memsettest((memset_t)&wmemset, sizeof(wchar_t));
    }

//    memsettest(&memseteabi);
    for (i = 0; i < 1; ++i)
    {
        for (pIter = pStart; pIter != pEnd; ++pIter)
        {
            printf("%d %s\n", pIter - pStart, pIter->_name);
            memsettest(pIter->_f_memset8, 1);
            if (pIter->_f_memset16)
                memsettest(pIter->_f_memset16, 2);
            if (pIter->_f_memset32)
                memsettest(pIter->_f_memset32, 4);
        }
    }

    {
        unsigned count = 10000;
        unsigned size = 32 * 1024;
        unsigned j = 0;
        void *ptr =  mmap(NULL, size,  PROT_READ |  PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
        for (j = 0; j < 3; ++j )
        {
            printf("%d\n", j);
            for (pIter = pStart; pIter != pEnd; ++pIter)
            {
                struct timespec before, after;
                memset_t pf = pIter->_f_memset8;
                if (j == 1)
                    pf = pIter->_f_memset16;
                if (j == 2)
                    pf = pIter->_f_memset32;
                if (!pf)
                    continue;
                printf("%d perf %s\n", pIter - pStart,pIter->_name);
                pf(ptr, 0, size / (1 << j));

                clock_gettime(CLOCK_MONOTONIC, &before);
                for (i = 0; i < count; ++i)
                    pf(ptr, 0, size / (1 << j));
                clock_gettime(CLOCK_MONOTONIC, &after);
                before = pdifftime(before, after);
                printf("%d done %f\n", 0, before.tv_sec + (double)before.tv_nsec / 1000000000);
            }
        }
    }
	
	//return g_Functable._esize;
}


void memsettest(memset_t pf, unsigned gran)
{
    struct timespec tottime = {0, 0};
	int fill = 0x55565758;
	unsigned offset, smallen, blocks;
	unsigned d = 0;
	for (offset = 0; offset < TEST_MAXOFFSET; offset += gran)
	{
		for (blocks = 0; blocks < TEST_MAXBOCKS; ++blocks)
		{
			for (smallen = 0; smallen < TEST_MAXSMALL; smallen += gran)
			{
				++d;
				unsigned len = smallen + blocks * TEST_BLOCKSIZE;
				
				char *pTest = buffer + 32 + offset;
				//printf("%p %02x %d\n",pTest, fill, len);
				struct timespec time;
				bool result = testmemset(pf, gran, buffer, sizeof(buffer), pTest, len, fill, &time);
				tottime.tv_sec += time.tv_sec + ((tottime.tv_nsec + time.tv_nsec) >= 1000000000 ? 1 : 0);
				tottime.tv_nsec += time.tv_nsec - ((tottime.tv_nsec + time.tv_nsec) >= 1000000000 ? 1000000000 : 0);
				if (!result)
				{
					printf("Failure (%d): %p %x %02x %d\n",gran, pTest, pTest - buffer - 32, fill, len);
					abort();
				}
				
			}

		}
	}

	printf("%d done %f\n", d, tottime.tv_sec + (double)tottime.tv_nsec / 1000000000);
}
