# Example Makefile for Building Resource DLLs
# This makefile demonstrates how to build resource DLLs containing icons, audio, images, etc.

# Compiler and tools
RC = rc.exe
LINK = link.exe

# Directories
RESOURCE_SRC = ../worktrees/resources
BUILD_OUT = ../build-output/resources

# Resource files
ICON_RC = $(RESOURCE_SRC)/icons.rc
AUDIO_RC = $(RESOURCE_SRC)/audio.rc
IMAGE_RC = $(RESOURCE_SRC)/images.rc

# Output DLLs
ICON_DLL = $(BUILD_OUT)/icons.dll
AUDIO_DLL = $(BUILD_OUT)/audio.dll
IMAGE_DLL = $(BUILD_OUT)/images.dll

# Default target
all: $(ICON_DLL) $(AUDIO_DLL) $(IMAGE_DLL)

# Build icon resource DLL
$(ICON_DLL): $(ICON_RC)
	@echo Building icon resource DLL...
	$(RC) /fo $(BUILD_OUT)/icons.res $(ICON_RC)
	$(LINK) /DLL /NOENTRY /OUT:$(ICON_DLL) $(BUILD_OUT)/icons.res

# Build audio resource DLL
$(AUDIO_DLL): $(AUDIO_RC)
	@echo Building audio resource DLL...
	$(RC) /fo $(BUILD_OUT)/audio.res $(AUDIO_RC)
	$(LINK) /DLL /NOENTRY /OUT:$(AUDIO_DLL) $(BUILD_OUT)/audio.res

# Build image resource DLL
$(IMAGE_DLL): $(IMAGE_RC)
	@echo Building image resource DLL...
	$(RC) /fo $(BUILD_OUT)/images.res $(IMAGE_RC)
	$(LINK) /DLL /NOENTRY /OUT:$(IMAGE_DLL) $(BUILD_OUT)/images.res

# Clean build artifacts
clean:
	@echo Cleaning resource build artifacts...
	del /Q $(BUILD_OUT)\*.res $(BUILD_OUT)\*.dll

.PHONY: all clean
