ifeq ($(strip $(DEVKITPRO)),)
$(error "Please set DEVKITPRO in your environment. export DEVKITPRO=<path to>/devkitpro")
endif

export SOURCE_ROOT = $(CURDIR)
LIB_ROOT = $(SOURCE_ROOT)/lib$(BASE_NAME)/
BASE_NAME = rtld
NAME = $(BASE_NAME)-$(ARCH)
SRC_DIR =

BUILD_DIR := $(SOURCE_ROOT)/build/$(ARCH)
BUILD_DIR_6XX := $(SOURCE_ROOT)/build/$(ARCH)-6xx


all: $(NAME).nso $(NAME)-6xx.nso

lib$(BASE_NAME)/lib$(NAME).a:
	make -C lib$(BASE_NAME) -f Makefile.$(ARCH) $(LIB_ROOT)/lib$(NAME).a

lib$(BASE_NAME)/lib$(NAME)-6xx.a:
	make -C lib$(BASE_NAME) -f Makefile.$(ARCH) $(LIB_ROOT)/lib$(NAME)-6xx.a

clean-lib$(BASE_NAME):
	make -C lib$(BASE_NAME) -f Makefile.$(ARCH) clean

clean: clean-normal-objects clean-6xx-objects clean-lib$(BASE_NAME) clean-standalone
export LD	:= $(CXX)

SRC_DIR = $(SOURCE_ROOT)/source $(SOURCE_ROOT)/source/$(ARCH)

export VPATH := $(foreach dir,$(SRC_DIR),$(dir))

# For the app, we need some system headers + rtld headers
SYS_INCLUDES := -isystem $(realpath $(SOURCE_ROOT))/include/ -isystem $(realpath $(SOURCE_ROOT))/lib$(BASE_NAME)/include -isystem $(realpath $(SOURCE_ROOT))/lib$(BASE_NAME)/misc/$(ARCH) -isystem $(realpath $(SOURCE_ROOT))/lib$(BASE_NAME)/misc/system/include
CC_FLAGS := -fno-stack-protector $(CC_ARCH) -fPIC -nostartfiles $(SYS_INCLUDES) -Wno-unused-command-line-argument -Wall -Wextra -O2 -ffunction-sections -fdata-sections
CXX_FLAGS := $(CC_FLAGS) -std=c++17 -nodefaultlibs -nostdinc++ -fno-rtti -fomit-frame-pointer -fno-exceptions -fno-asynchronous-unwind-tables -fno-unwind-tables
AR_FLAGS := rcs
AS_FLAGS := 

# required compiler-rt definitions
LIB_COMPILER_RT_PATH := $(BUILD_DIR)/lib
LIB_COMPILER_RT_BUILTINS :=

# 
# for compatiblity
CFLAGS := $(CC_FLAGS)
CXXFLAGS := $(CXX_FLAGS)

# export
export LD
export CC
export CXX
export AS
export AR
export LD_FOR_TARGET = $(LD)
export CC_FOR_TARGET = $(CC)
export AS_FOR_TARGET = $(AS) -arch=$(ARCH)
export AR_FOR_TARGET = $(AR)
export RANLIB_FOR_TARGET = $(RANLIB)
export CFLAGS_FOR_TARGET = $(CC_FLAGS) -Wno-unused-command-line-argument -Wno-error-implicit-function-declaration
export TARGET_TRIPLET


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
	$(AS) $(AS_FLAGS) -filetype=obj -o $@ $<

$(BUILD_DIR)/%.o: %.c
	$(CC) $(CC_FLAGS) -o $@ -c $<

$(BUILD_DIR)/%.o: %.cpp
	$(CXX) $(CXX_FLAGS) -o $@ -c $<

# 6.x+ build definition
$(BUILD_DIR_6XX):
	@mkdir -p $(BUILD_DIR_6XX)

$(BUILD_DIR_6XX)/%.o: %.s
	$(AS) $(AS_FLAGS) -filetype=obj -o $@ $<

$(BUILD_DIR_6XX)/%.o: %.c
	$(CC) $(CC_FLAGS) $(DEFINE_6XX) -o $@ -c $<

$(BUILD_DIR_6XX)/%.o: %.cpp
	$(CXX) $(CXX_FLAGS) $(DEFINE_6XX) -o $@ -c $<

LD_FLAGS := \
			-specs=$(SOURCE_ROOT)/misc/rtld.specs \
            -L$(LIB_COMPILER_RT_PATH) \
            -L$(SOURCE_ROOT)/lib$(BASE_NAME)

$(BUILD_DIR_6XX)/$(NAME).elf: $(BUILD_DIR_6XX) $(OBJECTS_6XX) $(LIB_COMPILER_RT_BUILTINS) lib$(BASE_NAME)/lib$(NAME)-6xx.a
	$(LD) $(LD_FLAGS) -l$(NAME)-6xx -o $@ $(OBJECTS_6XX)

$(NAME)-6xx.nso: $(BUILD_DIR_6XX)/$(NAME).elf
	elf2nso  $< $@

$(BUILD_DIR)/$(NAME).elf: $(BUILD_DIR) $(OBJECTS_NORMAL) $(LIB_COMPILER_RT_BUILTINS) lib$(BASE_NAME)/lib$(NAME).a
	$(LD) $(LD_FLAGS) -l$(NAME) -o $@ $(OBJECTS_NORMAL)

$(NAME).nso: $(BUILD_DIR)/$(NAME).elf
	elf2nso  $< $@

clean-standalone:
	rm -rf $(BUILD_DIR_6XX)/$(NAME).elf $(NAME)-6xx.nso $(BUILD_DIR)/$(NAME).elf $(NAME).nso
