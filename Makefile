
CURRENT_DATE=$(shell date +"%Y-%m-%d")
SOURCE_FILES=trash.m HGUtils.m HGCLIUtils.m fileSize.m

all: trash

docs: trash.1

trash: $(SOURCE_FILES)
	@echo
	@echo ---- Compiling:
	@echo ======================================
	$(CC) -O2 -Wall -Wextra -force_cpusubtype_ALL -mmacosx-version-min=10.5 -arch i386 -arch x86_64 -framework AppKit -framework ScriptingBridge -o $@ $(SOURCE_FILES)

analyze:
	@echo
	@echo ---- Analyzing:
	@echo ======================================
	clang --analyze $(SOURCE_FILES)

trash.1: trash.pod
	@echo
	@echo ---- Generating manpage from POD file:
	@echo ======================================
	pod2man --section=1 --center="trash" --date="$(CURRENT_DATE)" trash.pod > trash.1

clean:
	@echo
	@echo ---- Cleaning up:
	@echo ======================================
	-rm -Rf trash
	-rm -Rf trash.1
