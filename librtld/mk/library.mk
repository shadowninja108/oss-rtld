ifeq ($(strip $(DEVKITPRO)),)
$(error "Please set DEVKITPRO in your environment. export DEVKITPRO=<path to>/devkitpro")
endif

TOPDIR ?= $(CURDIR)
include $(DEVKITPRO)/libnx/switch_rules

SOURCE_ROOT = $(CURDIR)/
NAME = librtld-$(ARCH)
SRC_DIR = $(SOURCE_ROOT)/source $(SOURCE_ROOT)/source/$(ARCH)

BUILD_DIR := $(SOURCE_ROOT)/build/$(ARCH)
BUILD_DIR_6XX := $(SOURCE_ROOT)/build/$(ARCH)-6xx

all: $(SOURCE_ROOT)/$(NAME).a $(SOURCE_ROOT)/$(NAME)-6xx.a

clean: clean-normal-objects clean-6xx-objects
	rm -rf $(NAME).a $(NAME)-6xx.a $(BUILD_DIR) $(BUILD_DIR_6XX)

# inspired by libtransistor-base makefile


export VPATH := $(foreach dir,$(SRC_DIR),$(dir))

# We need some system header for rtld (target configuration, ect)
SYS_INCLUDES := -isystem $(realpath $(SOURCE_ROOT))/include/ -isystem $(realpath $(SOURCE_ROOT))/misc/$(ARCH) -isystem $(realpath $(SOURCE_ROOT))/misc/system/include
CC_FLAGS := -fuse-ld=lld -fno-stack-protector $(CC_ARCH) -fPIC -nostdlib $(SYS_INCLUDES) -Wno-unused-command-line-argument -Wall -Wextra -O2 -ffunction-sections -fdata-sections
CXX_FLAGS := $(CC_FLAGS) -std=c++17 -nodefaultlibs -nostdinc++ -fno-rtti -fomit-frame-pointer -fno-exceptions -fno-asynchronous-unwind-tables -fno-unwind-tables
AS_FLAGS := -x assembler-with-cpp $(CC_ARCH) 

# Used to build 6.x+ rtld
DEFINE_6XX := -D__RTLD_6XX__

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

$(SOURCE_ROOT)/$(NAME).a: $(BUILD_DIR) $(OBJECTS_NORMAL)
	@rm -f $@
	$(AR) -rc $@ $(OBJECTS_NORMAL)

$(SOURCE_ROOT)/$(NAME)-6xx.a: $(BUILD_DIR_6XX) $(OBJECTS_6XX)
	@rm -f $@
	$(AR) -rc $@ $(OBJECTS_6XX)