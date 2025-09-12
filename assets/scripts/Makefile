#----------------------
# Parse makefile arguments
#----------------------
RUN_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
$(eval $(RUN_ARGS):;@:)

#----------------------
# Silence GNU Make
#----------------------
ifndef VERBOSE
MAKEFLAGS += --no-print-directory
endif

#----------------------
# Terminal
#----------------------

GREEN  := $(shell tput -Txterm setaf 2)
WHITE  := $(shell tput -Txterm setaf 7)
YELLOW := $(shell tput -Txterm setaf 3)
RESET  := $(shell tput -Txterm sgr0)

#------------------------------------------------------------------
# - Add the following 'help' target to your Makefile
# - Add help text after each target name starting with '\#\#'
# - A category can be added with @category
#------------------------------------------------------------------

HELP_FUN = \
	%help; \
	while(<>) { \
		push @{$$help{$$2 // 'options'}}, [$$1, $$3] if /^([a-zA-Z\-]+)\s*:.*\#\#(?:@([a-zA-Z\-]+))?\s(.*)$$/ }; \
		print "-----------------------------------------\n"; \
		print "| Welcome to EQEmu Docker!\n"; \
		print "-----------------------------------------\n"; \
		print "| usage: make [command]\n"; \
		print "-----------------------------------------\n\n"; \
		for (sort keys %help) { \
			print "${WHITE}$$_:${RESET \
		}\n"; \
		for (@{$$help{$$_}}) { \
			$$sep = " " x (32 - length $$_->[0]); \
			print "  ${YELLOW}$$_->[0]${RESET}$$sep${GREEN}$$_->[1]${RESET}\n"; \
		}; \
		print "\n"; \
	}

help: ##@other Show this help.
	@perl -e '$(HELP_FUN)' $(MAKEFILE_LIST)

#----------------------
# Init / Install
#----------------------

install: ##@init Install full application
	@make init-directories
	@make init-eqemu-config
	@make pull-eqemu-code
	@make pull-peq-quests
	@make pull-maps
	@make init-build
	@echo "Running create-symlinks.pl..."
	@~/assets/scripts/create-symlinks.pl || (echo "ERROR: create-symlinks.pl failed. Check ~/server/eqemu_config.json"; cat ~/server/eqemu_config.json; exit 1)
	@make init-eqemu-admin-assets
	@make init-eqemu-admin
	@make init-server-binaries
	@make init-peq-database
	@make init-loginserver
	@make init-peq-editor
	@make init-set-perms
	@make init-shared-memory
ifeq ("$(SPIRE_DEV)", "true")
	@make init-spire-dev
endif

init-spire-dev: ##@init Initialize Spire for development
	git -C ~/server/spire pull 2> /dev/null || git clone https://github.com/akkadius/spire ~/server/spire
	cd ~/server/spire && cp .env.dev .env
	cd ~/server/spire && go get
	cd ~/server/spire/frontend && npm install
	echo "VUE_APP_BACKEND_BASE_URL=http://${IP_ADDRESS}:3010" > ~/server/spire/frontend/.env

init-shared-memory: ##@init Run shared memory once on initial install
	cd ~/server/ && ./bin/shared_memory

init-eqemu-config: ##@init Bootstraps eqemu config
	@./assets/scripts/banner.pl "Initializing EQEmu Config"
	@echo "Environment variables check:"
	@echo "  EQEMU_DB_PASSWORD: ${EQEMU_DB_PASSWORD}"
	@echo "  PORT_RANGE_HIGH: ${PORT_RANGE_HIGH}"
	@echo "  IP_ADDRESS: ${IP_ADDRESS}"
	@if [ -z "${EQEMU_DB_PASSWORD}" ]; then echo "ERROR: EQEMU_DB_PASSWORD is not set"; exit 1; fi
	@if [ -z "${PORT_RANGE_HIGH}" ]; then echo "ERROR: PORT_RANGE_HIGH is not set"; exit 1; fi
	@if [ -z "${IP_ADDRESS}" ]; then echo "ERROR: IP_ADDRESS is not set"; exit 1; fi
	@make pull-docker-config
	@echo "Checking downloaded config file..."
	@ls -la ~/server/eqemu_config.json
	@echo "First 200 chars of downloaded config:"
	@head -c 200 ~/server/eqemu_config.json
	@echo ""
	@echo "Validating initial JSON..."
	@cat ~/server/eqemu_config.json | jq . > /dev/null && echo "Initial JSON is valid" || (echo "ERROR: Initial JSON is invalid"; exit 1)
	@echo "Processing config with jq..."
	@set -e; \
	 cat ~/server/eqemu_config.json \
    | jq '.server.database.password = "${EQEMU_DB_PASSWORD}"' \
    | jq '.server.world.key = "$(shell cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w $${1:-32} | head -n 1)"' \
    | jq '.server.zones.ports.high = ${PORT_RANGE_HIGH}' \
	  | jq '.server.world.shortname = "Honeytree"' \
	  | jq '.server.world.longname = "Honeytree"' \
    | jq '.server.world.address = "${IP_ADDRESS}"' \
	  | jq '.server.world.localaddress = "${IP_ADDRESS}"' \
	  | jq '.server.ucs.host = "${IP_ADDRESS}"' \
    > ~/server/eqemu_config_temp.json
	@echo "Validating processed JSON..."
	@cat ~/server/eqemu_config_temp.json | jq . > /dev/null && echo "Processed JSON is valid" || (echo "ERROR: Processed JSON is invalid"; cat ~/server/eqemu_config_temp.json; exit 1)
	@mv ~/server/eqemu_config_temp.json ~/server/eqemu_config.json
	@echo "Final config file size: $(shell wc -c < ~/server/eqemu_config.json) bytes"

init-directories: ##@init Bootstrap directories
	@./assets/scripts/banner.pl "Bootstrapping directories"
	sudo chown eqemu:eqemu ~/.cache -R
	sudo chown eqemu:eqemu ~/server -R
	sudo chown eqemu:eqemu ~/code -R
	mkdir -p ~/server/assets
	mkdir -p ~/server/assets/patches
	mkdir -p ~/server/assets/opcodes
	mkdir -p ~/server/bin
	mkdir -p ~/server/logs
	mkdir -p ~/server/shared
	mkdir -p ~/server/assets

init-peq-database: ##@init Sources fresh PEQ database (Warning: Will over-write existing)
	@./assets/scripts/banner.pl "Bootstrapping PEQ Database"
	@echo "=== PEQ Database Initialization Debug ==="
	@echo "Step 1: Getting database configuration"
	$(eval DB_USERNAME := $(shell ~/assets/scripts/init/get-config-var.sh '.server.database.username'))
	$(eval DB_PASSWORD := $(shell ~/assets/scripts/init/get-config-var.sh '.server.database.password'))
	$(eval DB_HOST := $(shell ~/assets/scripts/init/get-config-var.sh '.server.database.host'))
	$(eval DB_NAME := $(shell ~/assets/scripts/init/get-config-var.sh '.server.database.db'))
	@echo "✓ Database Host: ${DB_HOST}"
	@echo "✓ Database Name: ${DB_NAME}"
	@echo "✓ Database User: ${DB_USERNAME}"
	@echo "✓ Database Password: [REDACTED - length: $(shell echo '${DB_PASSWORD}' | wc -c)]"
	@echo "Step 2: Testing database connectivity"
	@echo "Testing connection to database..."
	mysql -u${DB_USERNAME} -p${DB_PASSWORD} -h ${DB_HOST} -e "SELECT 'Database connection successful' as status;" || (echo "✗ ERROR: Cannot connect to database. Check credentials and host." && exit 1)
	@echo "✓ Database connection successful"
	@echo "Step 3: Downloading PEQ database dump"
	@echo "Downloading latest PEQ database from http://db.projecteq.net/api/v1/dump/latest"
	curl --fail --progress-bar http://db.projecteq.net/api/v1/dump/latest -o /tmp/db.zip || (echo "✗ ERROR: Failed to download database dump" && exit 1)
	@echo "✓ Database dump downloaded successfully"
	@echo "Step 4: Extracting database dump"
	unzip -o /tmp/db.zip -d /tmp/db/ || (echo "✗ ERROR: Failed to extract database dump" && exit 1)
	@echo "✓ Database dump extracted"
	@echo "Step 5: Verifying extracted files"
	@if [ ! -d "/tmp/db/peq-dump" ]; then echo "✗ ERROR: Expected peq-dump directory not found after extraction" && ls -la /tmp/db/ && exit 1; fi
	@if [ ! -f "/tmp/db/peq-dump/create_all_tables.sql" ]; then echo "✗ ERROR: create_all_tables.sql not found" && ls -la /tmp/db/peq-dump/ && exit 1; fi
	@echo "✓ Required SQL file found: create_all_tables.sql"
	@echo "File size: $(shell stat -c%s /tmp/db/peq-dump/create_all_tables.sql 2>/dev/null || stat -f%z /tmp/db/peq-dump/create_all_tables.sql) bytes"
	@echo "Step 6: Backing up existing database (if any)"
	@echo "Checking if database ${DB_NAME} exists..."
	@if mysql -u${DB_USERNAME} -p${DB_PASSWORD} -h ${DB_HOST} -e "USE ${DB_NAME};" 2>/dev/null; then \
		echo "✓ Database ${DB_NAME} exists - creating backup"; \
		mysqldump -u${DB_USERNAME} -p${DB_PASSWORD} -h ${DB_HOST} ${DB_NAME} > /tmp/db_backup_$(shell date +%Y%m%d_%H%M%S).sql && \
		echo "✓ Backup created: /tmp/db_backup_$(shell date +%Y%m%d_%H%M%S).sql"; \
	else \
		echo "ℹ️  Database ${DB_NAME} does not exist - no backup needed (normal for fresh install)"; \
	fi
	@echo "Step 7: Importing PEQ database"
	@echo "WARNING: This will overwrite existing database content"
	@echo "Importing create_all_tables.sql..."
	cd /tmp/db/peq-dump/ && mysql -u${DB_USERNAME} -p${DB_PASSWORD} -h ${DB_HOST} ${DB_NAME} < ./create_all_tables.sql || (echo "✗ ERROR: Failed to import database" && echo "Check the MySQL error above for details" && exit 1)
	@echo "✓ Database import successful"
	@echo "Step 8: Cleaning up temporary files"
	rm -rf /tmp/db/
	@echo "✓ Temporary files cleaned up"
	@echo "Step 9: Running database updates"
	@echo "Running world database:updates command..."
	cd ~/server && ./bin/world database:updates || (echo "⚠️  WARNING: Database updates failed - this may be normal for initial setup" && echo "Check ~/server/logs/ for details")
	@echo "=== PEQ Database Initialization Complete ==="

init-loginserver: ##@init Initializes Loginserver
	@./assets/scripts/banner.pl "Initializing Loginserver"
	wget --quiet https://raw.githubusercontent.com/EQEmu/Server/master/loginserver/login_util/login.json -O /tmp/login.json
	wget --quiet https://raw.githubusercontent.com/EQEmu/Server/master/loginserver/login_util/login_opcodes.conf -O ~/server/assets/opcodes/login_opcodes.conf
	wget --quiet https://raw.githubusercontent.com/EQEmu/Server/master/loginserver/login_util/login_opcodes_sod.conf -O ~/server/assets/opcodes/login_opcodes_sod.conf
	cat /tmp/login.json | grep -o '^[^/]*' | jq '' \
		| jq '.database.host = "$(shell ~/assets/scripts/init/get-config-var.sh '.server.database.host')"' \
		| jq '.database.db = "$(shell ~/assets/scripts/init/get-config-var.sh '.server.database.db')"' \
		| jq '.database.user = "$(shell ~/assets/scripts/init/get-config-var.sh '.server.database.username')"' \
		| jq '.database.password = "$(shell ~/assets/scripts/init/get-config-var.sh '.server.database.password')"' \
		| jq '.client_configuration.titanium_opcodes = "assets/opcodes/login_opcodes.conf"' \
		| jq '.client_configuration.sod_opcodes = "assets/opcodes/login_opcodes_sod.conf"' \
		> ~/server/login.json
	wget --quiet https://raw.githubusercontent.com/EQEmu/Server/master/loginserver/login_util/login_schema.sql -O /tmp/login_schema.sql
	mysql -u$(shell ~/assets/scripts/init/get-config-var.sh '.server.database.username') \
		-p$(shell ~/assets/scripts/init/get-config-var.sh '.server.database.password') \
		-h $(shell ~/assets/scripts/init/get-config-var.sh '.server.database.host') \
		$(shell ~/assets/scripts/init/get-config-var.sh '.server.database.db') < /tmp/login_schema.sql
	@./assets/scripts/banner.pl "Loginserver initialized!"

BIN_FILE_NAME=spire-admin-bin-$(shell date +"%m-%d-%Y-%H-%M-%S")

ADMIN_PASSWORD=${SPIRE_ADMIN_PASSWORD}
ifeq ("${ADMIN_PASSWORD}", "")
	ADMIN_PASSWORD=$(shell cat ~/server/eqemu_config.json 2>/dev/null | jq '.["web-admin"].application.admin.password' | tr -d '"' || echo "")
endif

init-eqemu-admin-assets: ##@init Initializes EQEmu Admin Assets
	@./assets/scripts/banner.pl "Initializing EQEmu Admin Assets"
	@if [ $(shell find ~/.cache/spire/assets/assets | wc -l) -gt 10 ] ; then \
		echo "spire assets are initialized"; \
	else \
		echo "spire assets are not initialized"; \
		curl -L https://github.com/Akkadius/eq-asset-preview/releases/latest/download/build.zip -o /tmp/build.zip; \
		mkdir -p ~/.cache/spire; \
		mkdir -p ~/.cache/spire/assets; \
		unzip -o /tmp/build.zip -d ~/.cache/spire/assets; \
	fi

init-eqemu-admin: ##@init Initializes EQEmu Admin
	rm -f ~/server/bin/eqemu-admin-*
	rm -f ~/server/bin/spire-*
	wget --progress=bar:force:noscroll --quiet https://github.com/akkadius/spire/releases/latest/download/spire-linux-amd64.zip -O /tmp/spire.zip
	unzip -o /tmp/spire.zip -d ~/server/bin
	mv ~/server/bin/spire-linux-amd64 ~/server/bin/spire
	chmod +x ~/server/bin/spire
	cd ~/server && SKIP_ASSET_CHECK=1 ./bin/spire spire:init admin ${ADMIN_PASSWORD} || echo "Already initialized"
	@echo "=== Configuring EQEmu Admin Settings ==="
	@echo "ADMIN_PASSWORD: ${ADMIN_PASSWORD}"
	@echo "Step 1: Reading and validating current config"
	cat ~/server/eqemu_config.json > /tmp/config_step0.json
	jq empty /tmp/config_step0.json && echo "✓ Initial JSON is valid" || (echo "✗ ERROR: Initial JSON is invalid" && exit 1)
	@echo "Step 2: Setting web-admin password"
	jq '.["web-admin"].application.admin.password = "${ADMIN_PASSWORD}"' /tmp/config_step0.json > /tmp/config_step1.json
	@echo "✓ Password set to: ${ADMIN_PASSWORD}"
	@echo "Step 3: Generating and setting application key"
	$(eval APP_KEY := $(shell cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1))
	@echo "✓ Generated key: ${APP_KEY}"
	jq '.["web-admin"].application.key = "${APP_KEY}"' /tmp/config_step1.json > /tmp/config_step2.json
	@echo "Step 4: Setting runSharedMemory"
	jq '.["web-admin"].launcher.runSharedMemory = true' /tmp/config_step2.json > /tmp/config_step3.json
	@echo "✓ runSharedMemory set to true"
	@echo "Step 5: Setting minZoneProcesses"
	jq '.["web-admin"].launcher.minZoneProcesses = 10' /tmp/config_step3.json > /tmp/config_step4.json
	@echo "✓ minZoneProcesses set to 10"
	@echo "Step 6: Setting staticZones"
	jq '.["web-admin"].launcher.staticZones = "butcher,erudnext,freporte,qeynos,freeporte,oot,iceclad,nro,oasis,nedaria,abysmal,natimbi,timorous,abysmal,firiona,overthere"' /tmp/config_step4.json > /tmp/config_step5.json
	@echo "✓ staticZones configured"
	@echo "Step 7: Final validation and port type checking"
	jq empty /tmp/config_step5.json && echo "✓ Final JSON is valid" || (echo "✗ ERROR: Final JSON is invalid" && exit 1)
	@echo "Checking for port type issues..."
	@if jq -e '.server.zones.ports.high | type == "number"' /tmp/config_step5.json >/dev/null 2>&1; then \
		echo "⚠️  WARNING: ports.high is number type, Go expects string"; \
		echo "Current value: $$(jq -r '.server.zones.ports.high' /tmp/config_step5.json)"; \
		echo "Converting to string..."; \
		jq '.server.zones.ports.high = (.server.zones.ports.high | tostring)' /tmp/config_step5.json > /tmp/config_step6.json; \
		mv /tmp/config_step6.json /tmp/config_step5.json; \
		echo "✓ ports.high converted to string"; \
	fi
	@if jq -e '.server.zones.ports.low | type == "number"' /tmp/config_step5.json >/dev/null 2>&1; then \
		echo "⚠️  WARNING: ports.low is number type, Go expects string"; \
		echo "Current value: $$(jq -r '.server.zones.ports.low' /tmp/config_step5.json)"; \
		echo "Converting to string..."; \
		jq '.server.zones.ports.low = (.server.zones.ports.low | tostring)' /tmp/config_step5.json > /tmp/config_step6.json; \
		mv /tmp/config_step6.json /tmp/config_step5.json; \
		echo "✓ ports.low converted to string"; \
	fi
	@echo "Step 8: Showing final configuration sections"
	@echo "web-admin configuration:"
	jq '.["web-admin"]' /tmp/config_step5.json
	@echo "ports configuration:"
	jq '.server.zones.ports // "ports section not found"' /tmp/config_step5.json
	@echo "Step 9: Writing final config"
	jq -M . /tmp/config_step5.json > /tmp/config.json && mv /tmp/config.json ~/server/eqemu_config.json
	@echo "✓ Final config written successfully"
	@echo "Step 10: Cleaning up temporary files"
	rm -f /tmp/config_step*.json
	@echo "=== EQEmu Admin Configuration Complete ==="
	cd ~/server && ./bin/spire spire:init admin ${ADMIN_PASSWORD} || echo "Already initialized"
	cd ~/server && ./bin/spire spire:occulus-update

init-eqemu-admin-dev: ##@init Initializes EQEmu Admin (Development)
	cd ~/server && if cd eqemu-web-admin 2> /dev/null; then git pull; else git clone https://github.com/Akkadius/eqemu-web-admin; fi
	cd ~/server/eqemu-web-admin && git checkout release
	cd ~/server/eqemu-web-admin && npm install
	cd ~/server/eqemu-web-admin/frontend && npm install

init-peq-editor: ##@init Initializes PEQ Editor DB tables
	@wget --quiet https://raw.githubusercontent.com/ProjectEQ/peqphpeditor/master/sql/schema.sql -O /tmp/schema.sql
	@mysql -u$(shell ~/assets/scripts/init/get-config-var.sh '.server.database.username') \
    		-p$(shell ~/assets/scripts/init/get-config-var.sh '.server.database.password') \
    		-h $(shell ~/assets/scripts/init/get-config-var.sh '.server.database.host') \
    		$(shell ~/assets/scripts/init/get-config-var.sh '.server.database.db') < /tmp/schema.sql
	@mysql -u$(shell ~/assets/scripts/init/get-config-var.sh '.server.database.username') \
    		-p$(shell ~/assets/scripts/init/get-config-var.sh '.server.database.password') \
    		-h $(shell ~/assets/scripts/init/get-config-var.sh '.server.database.host') \
    		$(shell ~/assets/scripts/init/get-config-var.sh '.server.database.db') -e 'update peq_admin SET password = MD5("${PEQ_EDITOR_PASSWORD}") where id = 1'

init-set-perms: ##@init Sets permissions recursively
	find ~/ -not -user eqemu -execdir sudo chown eqemu:eqemu {} \+

init-server-binaries: ##@init Initializes server binaries
	cd ~/server && ./bin/spire eqemu-server:update --release-binaries=true --auto=true

init-perl: ##@init Initializes perl - compiles perl from source to /opt/eqemu-perl
	@./assets/scripts/banner.pl "Initializing Perl"
	sudo mkdir -p /opt/eqemu-perl
	mkdir -p /tmp/eqemu-perl
	sudo chown eqemu:eqemu /opt/eqemu-perl -R
	cd /tmp && wget https://github.com/Perl/perl5/archive/refs/tags/v5.32.1.tar.gz -O perl.tar.gz
	cd /tmp && tar -xzf perl.tar.gz --strip-components=1 -C /tmp/eqemu-perl
	cd /tmp/eqemu-perl && ./Configure -des -Dprefix=/opt/eqemu-perl -Dusethreads -Dusemultiplicity -Duse64bitall -Dnoextensions -Duseshrplib
	cd /tmp/eqemu-perl && make -j$(shell nproc)
	# cd /opt/eqemu-perl && make -j$(shell nproc) test_harness
	cd /tmp/eqemu-perl && make install
	rm -rf /tmp/perl.tar.gz
	rm -rf /tmp/eqemu-perl
	# install DBI and DBD::mysql
	yes | sudo /opt/eqemu-perl/bin/perl -MCPAN -e 'install App::cpanminus'
	sudo /opt/eqemu-perl/bin/cpanm DBI
	sudo /opt/eqemu-perl/bin/cpanm DBD::mysql@4.046_01
	sudo /opt/eqemu-perl/bin/cpanm JSON
	sudo /opt/eqemu-perl/bin/cpanm Data::Dumper
	sudo /opt/eqemu-perl/bin/cpanm File::Find
	sudo /opt/eqemu-perl/bin/cpanm File::Path
	sudo /opt/eqemu-perl/bin/cpanm List::Util
	sudo /opt/eqemu-perl/bin/cpanm -n Module::Refresh
	sudo chown eqemu:eqemu -R /opt/eqemu-perl/

#----------------------
# Assets
#----------------------

pull-maps: ##@assets Pulls maps
	@./assets/scripts/banner.pl "Pulling latest EQEmu Maps"
	@if [ $(shell find ~/server/maps | wc -l) -gt 10 ] ; then \
		echo "maps is initialized"; \
	else \
		echo "maps is not initialized"; \
		cd server && wget --progress=bar:force:noscroll https://github.com/Akkadius/eqemu-maps/releases/latest/download/maps.zip -O /tmp/maps.zip && unzip -o /tmp/maps.zip -d ~/server/maps && rm /tmp/maps.zip || true; \
	fi

pull-eqemu-code: ##@assets Pulls eqemu code
	@./assets/scripts/banner.pl "Pulling EQEmu Source Code into [./code]"
	git -C ./code pull 2> /dev/null || git clone https://github.com/EQEmu/Server.git code

pull-peq-quests: ##@assets Pulls ProjectEQ quests
	@./assets/scripts/banner.pl "Pulling Latest ProjectEQ Quests"
	cd ~/server && git -C ./quests pull 2> /dev/null || git clone https://github.com/ProjectEQ/projecteqquests.git quests

pull-docker-config: ##@assets Pulls default eqemu_config.json
	@./assets/scripts/banner.pl "Bootstrapping default [eqemu_config.json]"
	cd ~/server && wget --progress=bar:force:noscroll --no-cache --no-check-certificate --no-cookies https://raw.githubusercontent.com/Akkadius/eqemu-install-v2/master/eqemu_config_docker.json -O eqemu_config.json

#----------------------
# mgmt
#----------------------

mgmt-mc: ##@mgmt Connect to MySQL Server
	mysql -u$(shell ~/assets/scripts/init/get-config-var.sh '.server.database.username') -p$(shell ~/assets/scripts/init/get-config-var.sh '.server.database.password') -h $(shell ~/assets/scripts/init/get-config-var.sh '.server.database.host') $(shell ~/assets/scripts/init/get-config-var.sh '.server.database.db')

last-crash: ##@mgmt Shows last crash that happened
	cat ~/server/logs/crashes/$$(ls -Art ~/server/logs/crashes | tail -n 1)

#----------------------
# build
#----------------------

ARCH := $(shell uname -m)
PERL_ARCH := $(if $(filter $(ARCH),aarch64 arm64),aarch64-linux-thread-multi,x86_64-linux-thread-multi)

init-build: ##@build Initialize build
	@./assets/scripts/banner.pl "Initializing EQEmu Server Build"
	cd ~/code && \
		git submodule init && \
		git submodule update && \
		rm -rf build && \
		mkdir -p build && \
		cd build && \
		cmake \
			-DEQEMU_BUILD_LOGIN=ON \
			-DEQEMU_BUILD_LUA=ON \
			-DCMAKE_BUILD_TYPE=RelWithDebInfo \
			-DPERL_LIBRARY=/opt/eqemu-perl/lib/5.32.1/$(PERL_ARCH)/CORE/libperl.so \
			-DPERL_EXECUTABLE=/opt/eqemu-perl/bin/perl \
			-DPERL_INCLUDE_PATH=/opt/eqemu-perl/lib/5.32.1/$(PERL_ARCH)/CORE/ \
			-DCMAKE_CXX_FLAGS_RELWITHDEBINFO:STRING="-Wno-everything" \
			-DCMAKE_CXX_COMPILER_LAUNCHER=ccache -G 'Unix Makefiles' ..

init-dev-build: ##@build Initialize build for development (faster compiles, uses ninja)
	@./assets/scripts/banner.pl "Initializing EQEmu Server Build"
	cd ~/code && \
		git submodule init && \
		git submodule update && \
		rm -rf build && \
		mkdir -p build && \
		cd build && \
		cmake -DEQEMU_BUILD_LOGIN=ON \
			-DEQEMU_BUILD_TESTS=ON \
			-DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
			-DPERL_LIBRARY=/opt/eqemu-perl/lib/5.32.1/$(PERL_ARCH)/CORE/libperl.so \
			-DPERL_EXECUTABLE=/opt/eqemu-perl/bin/perl \
			-DPERL_INCLUDE_PATH=/opt/eqemu-perl/lib/5.32.1/$(PERL_ARCH)/CORE/ \
			-DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=gold \
			-DCMAKE_CXX_FLAGS_RELWITHDEBINFO:STRING="-O0 -g -Wno-everything -fno-lto" -G "Ninja" ..

build: ##@build Build EQEmu server
	@./assets/scripts/banner.pl "Building EQEmu Server"
	cd ~/code/build && make

build-clean: ##@build Cleans build directory
	cd ~/code/build && make clean

#----------------------
# update
#----------------------

L_SPIRE_PORT=${SPIRE_PORT}
ifeq ("${L_SPIRE_PORT}", "")
	L_SPIRE_PORT=3000
endif

update-admin-panel: ##@update Update admin panel
	kill $(shell ps aux | grep "eqemu-admin" | grep "web" | grep -v "grep" | awk '{print $$2}' | tr '\n' ' ') &>/dev/null || echo "Nothing to kill"
	kill $(shell ps aux | grep "spire" | grep "http:serve" | grep -v "grep" | awk '{print $$2}' | tr '\n' ' ') &>/dev/null || echo "Nothing to kill"
	wget --progress=bar:force:noscroll --quiet $(shell curl -s https://api.github.com/repos/Akkadius/spire/releases/latest | jq -r '.assets[].browser_download_url' | grep spire-linux) -O /tmp/spire.zip
	unzip -o /tmp/spire.zip -d ~/server/bin
	mv ~/server/bin/spire-linux-amd64 ~/server/bin/spire
	chmod +x ~/server/bin/spire
	while true; do cd ~/server/ && nohup ./bin/spire http:serve --port=${L_SPIRE_PORT} >/dev/null 2>&1; sleep 1; done &
