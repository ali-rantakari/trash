# trash makefile
# 

SHELL=/bin/bash

CURRDATE=$(shell date +"%Y-%m-%d")
SCP_TARGET=$(shell cat ./deploymentScpTarget)
APP_VERSION=$(shell grep "^const int VERSION_" trash.m | awk '{print $$NF}' | tr -d ';' | tr '\n' '.' | sed -e 's/.$$//')
VERSION_ON_SERVER=$(shell curl -Ss http://hasseg.org/trash/?versioncheck=y)
TEMP_DEPLOYMENT_DIR=deployment/$(APP_VERSION)
TEMP_DEPLOYMENT_ZIPFILE=$(TEMP_DEPLOYMENT_DIR)/trash-v$(APP_VERSION).zip
TEMP_DEPLOYMENT_USAGEFILE="usage.txt"
VERSIONCHANGELOGFILELOC="$(TEMP_DEPLOYMENT_DIR)/changelog.html"
GENERALCHANGELOGFILELOC="changelog.html"
SCP_TARGET=$(shell cat ./deploymentScpTarget)
DEPLOYMENT_INCLUDES_DIR="./deployment-files"
COMPILER="/Developer/usr/bin/clang"
#COMPILER="gcc"



all: trash

docs: trash.1 usage.txt


usage.txt: trash
	@echo
	@echo ---- generating usage.txt:
	@echo ======================================
	./trash > usage.txt


#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
# compile the binary itself
#-------------------------------------------------------------------------
trash: trash.m
	@echo
	@echo ---- Compiling:
	@echo ======================================
	$(COMPILER) -O2 -Wall -force_cpusubtype_ALL -mmacosx-version-min=10.5 -arch i386 -arch ppc -framework AppKit -framework ScriptingBridge -o $@ trash.m



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
# make release package (prepare for deployment)
#-------------------------------------------------------------------------
package: trash docs
	@echo
	@echo ---- Preparing for deployment:
	@echo ======================================
	
# create zip archive
	mkdir -p $(TEMP_DEPLOYMENT_DIR)
	echo "-D -j $(TEMP_DEPLOYMENT_ZIPFILE) trash trash.1" | xargs zip
	cd "$(DEPLOYMENT_INCLUDES_DIR)"; echo "-g -R ../$(TEMP_DEPLOYMENT_ZIPFILE) *" | xargs zip
	
# if changelog doesn't already exist in the deployment dir
# for this version, get 'general' changelog file from root if
# one exists, and if not, create an empty changelog file
	@( if [ ! -e $(VERSIONCHANGELOGFILELOC) ];then\
		if [ -e $(GENERALCHANGELOGFILELOC) ];then\
			cp $(GENERALCHANGELOGFILELOC) $(VERSIONCHANGELOGFILELOC);\
			echo "Copied existing changelog.html from project root into deployment dir - opening it for editing";\
		else\
			echo -e "<ul>\n	<li></li>\n</ul>\n" > $(VERSIONCHANGELOGFILELOC);\
			echo "Created new empty changelog.html into deployment dir - opening it for editing";\
		fi; \
	else\
		echo "changelog.html exists for $(APP_VERSION) - opening it for editing";\
	fi )
	@open -a Smultron $(VERSIONCHANGELOGFILELOC)




#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
# deploy to server
#-------------------------------------------------------------------------
deploy: package
	@echo
	@echo ---- Deploying to server:
	@echo ======================================
	
	@echo "Checking latest version number vs. current version number..."
	@( if [ "$(VERSION_ON_SERVER)" != "$(APP_VERSION)" ];then\
		echo "Latest version on server is $(VERSION_ON_SERVER). Uploading $(APP_VERSION).";\
	else\
		echo "NOTE: Current version exists on server: ($(APP_VERSION)).";\
	fi;\
	echo "Press enter to continue uploading to server or Ctrl-C to cancel.";\
	read INPUTSTR;\
	scp -r $(TEMP_DEPLOYMENT_DIR) $(TEMP_DEPLOYMENT_USAGEFILE) $(SCP_TARGET); )





#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
clean:
	@echo
	@echo ---- Cleaning up:
	@echo ======================================
	-rm -Rf trash
	-rm -Rf usage.txt
	-rm -Rf trash.1



