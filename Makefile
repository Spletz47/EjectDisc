#---------------------------------------------------------------------------------
# Clear the implicit built in rules
#---------------------------------------------------------------------------------
.SUFFIXES:
#---------------------------------------------------------------------------------
ifeq ($(strip $(DEVKITPPC)),)
$(error "Please set DEVKITPPC in your environment. export DEVKITPPC=<path to>/devkitPPC")
endif
ifeq ($(strip $(DEVKITPRO)),)
$(error "Please set DEVKITPRO in your environment. export DEVKITPRO=<path to>/devkitPro")
endif

TOPDIR ?= $(CURDIR)

#-------------------------------------------------------------------------------
# APP_NAME sets the long name of the application
# APP_SHORTNAME sets the short name of the application
# APP_AUTHOR sets the author of the application
#-------------------------------------------------------------------------------
APP_NAME		:= Test LED
APP_SHORTNAME	:= Test LED
APP_AUTHOR		:= Spletz

include $(DEVKITPRO)/wut/share/wut_rules

WUT_ROOT := $(DEVKITPRO)/wut
WUMS_ROOT := $(DEVKITPRO)/wums

#---------------------------------------------------------------------------------
# TARGET is the name of the output
# BUILD is the directory where object files & intermediate files will be placed
# SOURCES is a list of directories containing source code
# DATA is a list of directories containing data files
# INCLUDES is a list of directories containing extra header files
# CONTENT is the path to the bundled folder that will be mounted as /vol/content/
# ICON is the game icon, leave blank to use default rule
# TV_SPLASH is the image displayed during bootup on the TV, leave blank to use default rule
# DRC_SPLASH is the image displayed during bootup on the DRC, leave blank to use default rule
#---------------------------------------------------------------------------------
TARGET		:=	EjectDisc
BUILD		:=	build
SOURCES		:=	src
DATA		:=	data
INCLUDES	:=  src
#ICON		:=  meta/menu-icon.png

#---------------------------------------------------------------------------------
# options for code generation
#---------------------------------------------------------------------------------
CFLAGS	:=  -O2 -Wall -Wextra -ffunction-sections $(MACHDEP)

CFLAGS	+=	$(INCLUDE) -D__WIIU__ -D__WUT__

CXXFLAGS := $(CFLAGS) -std=c++20

ASFLAGS	:= $(ARCH)
LDFLAGS	= $(ARCH) $(RPXSPECS) -Wl,-Map,$(notdir $*.map)

#---------------------------------------------------------------------------------
# any extra libraries we wish to link with the project
#---------------------------------------------------------------------------------
LIBS	:= -lmocha -lwut

#---------------------------------------------------------------------------------
# list of directories containing libraries, this must be the top level containing
# include and lib
#---------------------------------------------------------------------------------
LIBDIRS	:= $(PORTLIBS) $(WUMS_ROOT) $(WUT_ROOT) $(WUT_ROOT)/usr

#---------------------------------------------------------------------------------
# no real need to edit anything past this point unless you need to add additional
# rules for different file extensions
#---------------------------------------------------------------------------------
ifneq ($(BUILD),$(notdir $(CURDIR)))
#---------------------------------------------------------------------------------
export OUTPUT	:=	$(CURDIR)/$(TARGET)
export TOPDIR	:=	$(CURDIR)
export VPATH	:=	$(foreach dir,$(SOURCES),$(CURDIR)/$(dir)) \
					$(foreach dir,$(DATA),$(CURDIR)/$(dir))
export DEPSDIR	:=	$(CURDIR)/$(BUILD)

#---------------------------------------------------------------------------------
# automatically build a list of object files for our project
#---------------------------------------------------------------------------------
CFILES		:=	$(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.c)))
CPPFILES	:=	$(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.cpp)))
sFILES		:=	$(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.s)))
SFILES		:=	$(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.S)))
BINFILES	:=	$(foreach dir,$(DATA),$(notdir $(wildcard $(dir)/*.*)))

#---------------------------------------------------------------------------------
# use CXX for linking C++ projects, CC for standard C
#---------------------------------------------------------------------------------
ifeq ($(strip $(CPPFILES)),)
	export LD	:=	$(CC)
else
	export LD	:=	$(CXX)
endif

export OFILES_BIN	:=	$(addsuffix .o,$(BINFILES))
export OFILES_SRC	:=	$(CPPFILES:.cpp=.o) $(CFILES:.c=.o) \
						$(sFILES:.s=.o) $(SFILES:.S=.o)
export OFILES 		:=	$(OFILES_BIN) $(OFILES_SRC)
export HFILES_BIN	:=	$(addsuffix .h,$(subst .,_,$(BINFILES)))

#---------------------------------------------------------------------------------
# build a list of include paths
#---------------------------------------------------------------------------------
export INCLUDE	:=	$(foreach dir,$(INCLUDES),-I$(CURDIR)/$(dir)) \
					$(foreach dir,$(LIBDIRS),-I$(dir)/include) \
					-I$(CURDIR)/$(BUILD)

#---------------------------------------------------------------------------------
# build a list of library paths
#---------------------------------------------------------------------------------
export LIBPATHS	:=	$(foreach dir,$(LIBDIRS),-L$(dir)/lib)

ifneq (,$(strip $(CONTENT)))
	export APP_CONTENT := $(TOPDIR)/$(CONTENT)
endif

ifneq (,$(strip $(ICON)))
	export APP_ICON := $(TOPDIR)/$(ICON)
else ifneq (,$(wildcard $(TOPDIR)/$(TARGET).png))
	export APP_ICON := $(TOPDIR)/$(TARGET).png
else ifneq (,$(wildcard $(TOPDIR)/icon.png))
	export APP_ICON := $(TOPDIR)/icon.png
endif

ifneq (,$(strip $(TV_SPLASH)))
	export APP_TV_SPLASH := $(TOPDIR)/$(TV_SPLASH)
else ifneq (,$(wildcard $(TOPDIR)/tv-splash.png))
	export APP_TV_SPLASH := $(TOPDIR)/tv-splash.png
else ifneq (,$(wildcard $(TOPDIR)/splash.png))
	export APP_TV_SPLASH := $(TOPDIR)/splash.png
endif

ifneq (,$(strip $(DRC_SPLASH)))
	export APP_DRC_SPLASH := $(TOPDIR)/$(DRC_SPLASH)
else ifneq (,$(wildcard $(TOPDIR)/drc-splash.png))
	export APP_DRC_SPLASH := $(TOPDIR)/drc-splash.png
else ifneq (,$(wildcard $(TOPDIR)/splash.png))
	export APP_DRC_SPLASH := $(TOPDIR)/splash.png
endif

.PHONY: $(BUILD) clean all

#---------------------------------------------------------------------------------
all: $(BUILD)

$(BUILD):
	@$(shell [ ! -d $(BUILD) ] && mkdir -p $(BUILD))
	@$(MAKE) --no-print-directory -C $(BUILD) -f $(CURDIR)/Makefile

#---------------------------------------------------------------------------------
clean:
	@echo clean ...
	@rm -fr $(BUILD) $(TARGET).wuhb $(TARGET).rpx $(TARGET).elf $(TARGET).bin

#---------------------------------------------------------------------------------
else
.PHONY:	all

DEPENDS	:=	$(OFILES:.o=.d)

#---------------------------------------------------------------------------------
# main targets
#---------------------------------------------------------------------------------
all:	$(OUTPUT).wuhb

$(OUTPUT).wuhb:	$(OUTPUT).rpx
$(OUTPUT).rpx:	$(OUTPUT).elf
$(OUTPUT).elf:  $(OFILES)

$(OFILES_SRC)	: $(HFILES_BIN)

#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
%.bin.o %_bin.h : %.bin
	@echo $(notdir $<)
	@$(bin2o)

-include $(DEPENDS)

#---------------------------------------------------------------------------------
endif
#---------------------------------------------------------------------------------
