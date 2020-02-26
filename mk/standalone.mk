ifeq ($(strip $(DEVKITPRO)),)
$(error "Please set DEVKITPRO in your environment. export DEVKITPRO=<path to>/devkitpro")
endif

TOPDIR ?= $(CURDIR)
include $(DEVKITPRO)/libnx/switch_rules

SOURCE_ROOT = $(CURDIR)
LIB_ROOT = $(SOURCE_ROOT)/lib$(BASE_NAME)/
BASE_NAME = rtld
NAME = $(BASE_NAME)-$(ARCH)
SRC_DIR =

BUILD_DIR := $(SOURCE_ROOT)/build/$(ARCH)
BUILD_DIR_6XX := $(SOURCE_ROOT)/build/$(ARCH)-6xx

# see https://github.com/MegatonHammer/linkle
LINKLE = linkle

all: $(NAME).nso $(NAME)-6xx.nso

lib$(BASE_NAME)/lib$(NAME).a:
	make -C lib$(BASE_NAME) -f Makefile.$(ARCH) $(LIB_ROOT)/lib$(NAME).a

lib$(BASE_NAME)/lib$(NAME)-6xx.a:
	make -C lib$(BASE_NAME) -f Makefile.$(ARCH) $(LIB_ROOT)/lib$(NAME)-6xx.a

clean-lib$(BASE_NAME):
	make -C lib$(BASE_NAME) -f Makefile.$(ARCH) clean

clean: clean_compiler-rt clean-normal-objects clean-6xx-objects clean-lib$(BASE_NAME) clean-standalone

# inspired by libtransistor-base makefile


SRC_DIR = $(SOURCE_ROOT)/source $(SOURCE_ROOT)/source/$(ARCH)

export VPATH := $(foreach dir,$(SRC_DIR),$(dir))

# For compiler-rt and the app, we need some system headers + rtld headers
SYS_INCLUDES := -isystem $(realpath $(SOURCE_ROOT))/include/ -isystem $(realpath $(SOURCE_ROOT))/lib$(BASE_NAME)/include -isystem $(realpath $(SOURCE_ROOT))/lib$(BASE_NAME)/misc/$(ARCH) -isystem $(realpath $(SOURCE_ROOT))/lib$(BASE_NAME)/misc/system/include
CC_FLAGS := -fuse-ld=lld -fno-stack-protector $(CC_ARCH) -fPIC -nostdlib $(SYS_INCLUDES) -Wno-unused-command-line-argument -Wall -Wextra -O2 -ffunction-sections -fdata-sections
CXX_FLAGS := $(CC_FLAGS) -std=c++17 -nodefaultlibs -fno-rtti -fomit-frame-pointer -fno-exceptions -fno-asynchronous-unwind-tables -fno-unwind-tables
AS_FLAGS := -x assembler-with-cpp $(CC_ARCH) 

# 
# for compatiblity
CFLAGS := $(CC_FLAGS)
CXXFLAGS := $(CXX_FLAGS)

# export
export LD
export CC
export CXX
export LD_FOR_TARGET = $(LD)
export CC_FOR_TARGET = $(CC)
export RANLIB_FOR_TARGET = $(RANLIB)
export CFLAGS_FOR_TARGET = $(CC_FLAGS) -Wno-unused-command-line-argument -Wno-error-implicit-function-declaration
export TARGET_TRIPLET

include mk/compiler-rt.mk

%.a:
	@rm -f $@
	$(AR) -rc $@ $^

CFILES   := $(foreach dir,$(SRC_DIR),$(notdir $(wildcard $(dir)/*.c)))
CPPFILES := $(foreach dir,$(SRC_DIR),$(notdir $(wildcard $(dir)/*.cpp)))
ASMFILES := $(foreach dir,$(SRC_DIR),$(notdir $(wildcard $(dir)/*.s)))

OBJECTS_NORMAL = $(addprefix $(BUILD_DIR)/, $(CFILES:.c=.o) $(CPPFILES:.cpp=.o) $(ASMFILES:.s=.o))
OBJECTS_6XX = $(addprefix $(BUILD_DIR_6XX)/, $(CFILES:.c=.o) $(CPPFILES:.cpp=.o) $(ASMFILES:.s=.o))

clean-normal-objects:
	rm -rf $(OBJECTS_NORMAL)

clean-6xx-objects:
	rm -rf $(OBJECTS_6XX)

$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/%.o: %.s
	$(CC) $(AS_FLAGS) -o $@ $<

$(BUILD_DIR)/%.o: %.c
	$(CC) $(CC_FLAGS) -o $@ -c $<

$(BUILD_DIR)/%.o: %.cpp
	$(CXX) $(CXX_FLAGS) -o $@ -c $<

# 6.x+ build definition
$(BUILD_DIR_6XX):
	@mkdir -p $(BUILD_DIR_6XX)

$(BUILD_DIR_6XX)/%.o: %.s
	$(CC) $(AS_FLAGS) -o $@ $<

$(BUILD_DIR_6XX)/%.o: %.c
	$(CC) $(CC_FLAGS) $(DEFINE_6XX) -o $@ -c $<

$(BUILD_DIR_6XX)/%.o: %.cpp
	$(CXX) $(CXX_FLAGS) $(DEFINE_6XX) -o $@ -c $<

LD_FLAGS := \
            --version-script=$(SOURCE_ROOT)/exported.txt \
            --shared \
            --gc-sections \
            -T $(SOURCE_ROOT)/misc/$(ARCH)/application.ld \
            -init=__rtld_init \
            -fini=__rtld_fini \
            -z text \
            --build-id=sha1 \
            -L$(SOURCE_ROOT)/lib$(BASE_NAME)

$(BUILD_DIR_6XX)/$(NAME).elf: $(BUILD_DIR_6XX) $(OBJECTS_6XX) $(LIB_COMPILER_RT_BUILTINS) lib$(BASE_NAME)/lib$(NAME)-6xx.a
	$(LD) $(LD_FLAGS) -l$(NAME)-6xx -o $@ $(OBJECTS_6XX)

$(NAME)-6xx.nso: $(BUILD_DIR_6XX)/$(NAME).elf
	@elf2nso $< $@
	@echo built ... $(notdir $@)

$(BUILD_DIR)/$(NAME).elf: $(BUILD_DIR) $(OBJECTS_NORMAL) $(LIB_COMPILER_RT_BUILTINS) lib$(BASE_NAME)/lib$(NAME).a
	$(LD) $(LD_FLAGS) -l$(NAME) -o $@ $(OBJECTS_NORMAL)

$(NAME).nso: $(BUILD_DIR)/$(NAME).elf
	@elf2nso $< $@
	@echo built ... $(notdir $@)

clean-standalone:
	rm -rf $(BUILD_DIR_6XX)/$(NAME).elf $(NAME)-6xx.nso $(BUILD_DIR)/$(NAME).elf $(NAME).nso
