# trash makefile
# 

SOURCE_FILES=trash.m HGUtils.m HGCLIUtils.m fileSize.m

all: trash

docs: trash.1

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
# compile the binary itself
#-------------------------------------------------------------------------
trash: $(SOURCE_FILES)
	@echo
	@echo ---- Compiling:
	@echo ======================================
	$(CC) -O2 -Wall -Wextra -force_cpusubtype_ALL -mmacosx-version-min=10.5 -arch i386 -framework AppKit -framework ScriptingBridge -o $@ $(SOURCE_FILES)

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
# run clang static analyzer
#-------------------------------------------------------------------------
analyze:
	@echo
	@echo ---- Analyzing:
	@echo ======================================
	$(COMPILER_CLANG) --analyze $(SOURCE_FILES)


#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
# generate main man page from POD syntax file
#-------------------------------------------------------------------------
trash.1: trash.pod
	@echo
	@echo ---- Generating manpage from POD file:
	@echo ======================================
	pod2man --section=1 --release=$(APP_VERSION) --center="trash" --date="$(CURRDATE)" trash.pod > trash.1


#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
clean:
	@echo
	@echo ---- Cleaning up:
	@echo ======================================
	-rm -Rf trash
	-rm -Rf trash.1



