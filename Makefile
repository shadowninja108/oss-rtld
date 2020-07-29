.PHONY: clean all aarch64 

all: aarch64

aarch64:
	$(MAKE) -f Makefile.aarch64

#armv7:
# 	todo: make toolchain work with ARMv7
# 	z$(MAKE) -f Makefile.armv7

clean:
	$(MAKE) -f Makefile.aarch64 clean
	$(MAKE) -f Makefile.armv7 clean
