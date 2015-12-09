CC_FOR_TARGET := arm-linux-gnueabihf-gcc
CC_TYPE := gcc
comma := ,
CFLAGS := -O3 -g3 -mfloat-abi=hard

#all: memsetthumb1.o memset8.o


all: memset_c.o memset8.o armmemset thumemset testmemset memsetthumb1.o sendfirefly


archs.mk:
	sh createarchs.sh $(CC_FOR_TARGET) >$@

include archs.mk
# filter out some archs for clang
# ARM_ARM := $(filter-out armv2% armv3%,$(ARM_ARM))
# ARM_THU := $(filter-out armv2% armv3%,$(ARM_THU))

# gcc bug? armv5e is described as surported, but isnt?
ARM_ARM := $(filter-out %+crc,$(ARM_ARM))
ARM_THU := $(filter-out %+crc,$(ARM_THU))
# need to create a thumb1 version
# ARM_THI := $(filter-out $(ARM_ARM),$(ARM_THI))
# ARM_THU := $(filter-out %+crc $(ARM_THI),$(ARM_THU))


all: 

armmemset: $(patsubst %,memset8a-%.o,$(ARM_ARM))
thumemset: $(patsubst %,memset8t-%.o,$(ARM_THU))


memset_c.o : memset_c.c memsetpriv.h
	$(CC_FOR_TARGET) -std=c99 -O3 -march=armv6t2 -o $@ -c $<
	
memsetthumb1.o : memset_c.c memsetpriv.h
	$(CC_FOR_TARGET) -std=c99 $(filter-out -mfloat-abi%,$(CFLAGS)) -O3 -mfloat-abi=soft -march=armv4t -mthumb -o $@ -c $<

memset8.o : memset8.S memsetpriv.h
	$(CC_FOR_TARGET) $(CFLAGS) -march=armv5te -mthumb -o $@ -c $<
	
compfile = TMPFILE=$$(mktemp -d); trap "rm -rf $$TMPFILE" 0; \
	sed -e 's/^FUNCTION memset$$//' -e 's/^FUNCTION wmemset$$//' -e 's,\b_\(_*[am][_a-z0-9]*\b\),_\1_$(3)'$(subst -,_,$(1))',g' $< >$$TMPFILE/$(notdir $<); \
		$(CC_FOR_TARGET) $(CFLAGS) -I$(dir $<) -xassembler-with-cpp $(2) $(if ,,-fdebug-prefix-map=$$TMPFILE=$(patsubst %/,%,$(dir $<))) -o $@ -c $$TMPFILE/$(notdir $<)


memset8a-%.o : memset8.S memsetpriv.h
	$(call compfile,$*,-marm -march=$*,)

memset8t-%.o : memset8.S memsetpriv.h
	$(call compfile,$*,-mthumb -march=$*,t)

memset16a-%.o : memset16.S memsetpriv.h
	$(call compfile,$*,-marm -march=$*,)

memset16t-%.o : memset16.S memsetpriv.h
	$(call compfile,$*,-mthumb -march=$*,t)

memset32a-%.o : memset32.S memsetpriv.h
	$(call compfile,$*,-marm -march=$*,)

memset32t-%.o : memset32.S memsetpriv.h
	$(call compfile,$*,-mthumb -march=$*,t)

memset8a-armhf.o : memset8.S memsetpriv.h
	$(call compfile,armhf,-marm -march=armv7-a -mfloat-abi=hard -mfpu=vfp,)
	
memset8t-armhf.o : memset8.S memsetpriv.h
	$(call compfile,armhf,-marm -march=armv7-a -mfloat-abi=hard -mfpu=vfp,t)
	
memset16a-armhf.o : memset16.S memsetpriv.h
	$(call compfile,armhf,-marm -march=armv7-a -mfloat-abi=hard -mfpu=vfp,)

memset16t-armhf.o : memset16.S memsetpriv.h
	$(call compfile,armhf,-mthumb -march=armv7-a -mfloat-abi=hard -mfpu=vfp,t)
	
memset32a-armhf.o : memset32.S memsetpriv.h
	$(call compfile,armhf,-marm -march=armv7-a -mfloat-abi=hard -mfpu=vfp,)

memset32t-armhf.o : memset32.S memsetpriv.h
	$(call compfile,armhf,-mthumb -march=armv7-a -mfloat-abi=hard -mfpu=vfp,t)

FUNCTIONS := _memset8 _memset16 _memset32
IMPLS := $(subst -,_,$(ARM_ARM) armhf $(addprefix t,$(ARM_THU) armhf))
memsettable.c:
	echo >$@ "#include <stddef.h>"
	for suffix in $(IMPLS); do \
	  echo >>$@ "$(foreach func,$(FUNCTIONS),void * $(func)_$$suffix(void *, int, size_t) ;)"; \
	done
	echo >>$@ "void * memset_c(void *, int, size_t);";
	echo >>$@ "void * memset(void *, int, size_t);";
	echo >>$@ "typedef void *(*memset_t)(void *, int, size_t);"
	echo >>$@ "struct CFuncEntry {const char *_name; $(foreach func,$(FUNCTIONS),memset_t _f$(func) ;) } s_Table[] = {"
	echo >>$@ "  { \"cfun\", &memset_c },";
	echo >>$@ "  { \"memset\", &memset },";
	echo >>$@ "  { \"armhf\", &_memset8_armhf },";
	for suffix in $(IMPLS); do \
	  echo >>$@ "  { \"$$suffix\" $(foreach func,$(FUNCTIONS),$(comma)&$(func)_$$suffix) },"; \
	done
	echo >>$@ "};"
	echo >>$@ "struct CTablePtr {const void *_p; unsigned _size; unsigned _esize;};"
	echo >>$@ "struct CTablePtr g_Functable = {&s_Table, sizeof(s_Table)/sizeof(s_Table[0]), sizeof(s_Table[0])};"

memsettable.o: memsettable.c
	$(CC_FOR_TARGET) $(CFLAGS) -o $@ -c $<

testmemset : testmemset.c libmemsetma.a
	$(CC_FOR_TARGET) $(CFLAGS) -O3  -o $@ $+


libmemsetma.a: memset_c.o memsettable.o $(patsubst %,memset8a-%.o,$(ARM_ARM) armhf) $(patsubst %,memset8t-%.o,$(ARM_THU) armhf) $(patsubst %,memset16a-%.o,$(ARM_ARM) armhf) $(patsubst %,memset16t-%.o,$(ARM_THU) armhf) $(patsubst %,memset32a-%.o,$(ARM_ARM) armhf) $(patsubst %,memset32t-%.o,$(ARM_THU) armhf)
	ar crus $@ $^

sendfirefly: testmemset
	-scp $< firefly@192.168.0.138:/tmp
	
gdbserv: sendfirefly
	ssh firefly@192.168.0.138 "gdbserver :10000 /tmp/testmemset &"   
	
clean:
	rm -f memset*.o libmemset*.a memsettable.? testmemset

PHONY: all armmemset thumemset clean sendfirefly

print_compiler-gcc:
	$(CC_FOR_TARGET) -std=c99 -O3 -mthumb -march=armv7-a -mfloat-abi=hard -mfpu=vfp \
		-E -P -dD -x c -v - < /dev/null 2>&1 

print_compiler-g++: print_compiler-gcc



PHONY: print_compiler-gcc print_compiler-g++