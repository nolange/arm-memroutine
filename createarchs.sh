#!/bin/sh
CC=$1
ALLARCHS="$($CC -march=nullx -xc - </dev/null 2>&1 >/dev/null | sed -n 's/.*are: \(.*\)/\1/p' | sed 's, *native,,g')"
ARMARCHS=
THUMBARCHS=
THUMB1ARCHS=
for arch in $ALLARCHS; do
  echo ".arm"   | $CC -march=$arch -xassembler-with-cpp -c -o /dev/null 1>/dev/null 2>/dev/null - && ARMARCHS="$ARMARCHS $arch"
  if echo ".thumb" | $CC -march=$arch -mthumb -xassembler-with-cpp -c -o /dev/null 1>/dev/null 2>/dev/null -; then
    THUMBARCHS="$THUMBARCHS $arch"
    printf "#ifdef __thumb2__\n#error Thumb1\n#endif" | $CC -march=$arch -mthumb -xassembler-with-cpp -c -o /dev/null 1>/dev/null 2>/dev/null - && THUMB1ARCHS="$THUMB1ARCHS $arch"
  fi
done

echo 'ARM_ALL :=' $ALLARCHS
echo 'ARM_ARM :=' $ARMARCHS
echo 'ARM_THU :=' $THUMBARCHS
echo 'ARM_THI :=' $THUMB1ARCHS
  
