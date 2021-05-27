.POSIX:

help: ## Show this help message.
	@egrep -h '\s##\s' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

SHELL = /bin/bash

# ------------------------------------------------------------
# NOTES
# ------------------------------------------------------------
#
# -	This Makefile has a hard dependency on several values
#	existing within the included make_env file.  Anywhere you
#	find a variable name starting with MAKE_ENV_, that value
#	comes from the make_env file.
#	This is set up so the Makefile itself may be fully generic
#	and portable, while the make_env is altered per-repo.
#
# - This Makefile has hard dependencies on several values
#	existing within a configuration file out on target servers
#	(make_secrets).
#	At present, these variables are not named according to
#	their origin.
#
# -	The commented-out $(info "") sections may be uncommented
#	in order to perform debugging on the Makefile.  These are
#	commonly headed by a "# DEBUG" comment.
#
# ------------------------------------------------------------

# ------------------------------------------------------------
# Constants
# ------------------------------------------------------------
DEBUG			= yes

# ------------------------------------------------------------
# Secrets
# ------------------------------------------------------------
# The `make_secrets` file contains global "secret" values.
include make_secrets

# DEBUG
ifeq (${DEBUG},yes)
# Make sure we have the GITHUB_TOKEN onboard.
$(info "GITHUB_TOKEN=${GITHUB_TOKEN}")

# Make sure we have the DOCKER_* credentials onboard.
$(info "DOCKER_USER=${DOCKER_USER}")
$(info "DOCKER_PASSWORD=${DOCKER_PASSWORD}")
endif

# ------------------------------------------------------------
# git
# ------------------------------------------------------------
# If no branch is specified, get it from local git.
ifeq (${BRANCH_NAME},)
	BRANCH_NAME := ${GIT_BRANCH}
endif

# Retrieve git repository name.
REPO_NAME	:= $(shell echo ${GIT_URL} | awk -F/ '{gsub(".git","");print $$NF}')

# Retrieve git commit hash.
GIT_HASH	:= $(shell git rev-parse --short HEAD)

# Create release tag in the format of YYYYMMDD/<HASH>
# This will set the folder for the release, with multiple releases in a given
# day going into the same date folder.
RELEASE_TAG	:= $(shell date +%Y%m%d)/${GIT_HASH}

# Retrieve lowercased author, remove spaces, alphanumeric only.
AUTHOR		:= $(shell git show -s --format='%aN' ${GIT_HASH} | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]._-')

# Semver info
SEMVER		:= $(shell find . -type f -name "VERSION" -exec cat {} + | head -n1)

MAJOR		:= $(shell echo ${SEMVER} | cut -d '.' -f 1)
MINOR		:= $(shell echo ${SEMVER} | cut -d '.' -f 2)
PATCH		:= $(shell echo ${SEMVER} | cut -d '.' -f 3)

# DEBUG
ifeq (${DEBUG},yes)
$(info "AUTHOR=${AUTHOR}")
$(info "GIT_HASH=${GIT_HASH}")
$(info "REPO_NAME=${REPO_NAME}")
$(info "BRANCH_NAME=${BRANCH_NAME}")
$(info "RELEASE_TAG=${RELEASE_TAG}")
$(info "BUILD_NUMBER=${BUILD_NUMBER}")
$(info "SEMVER=${SEMVER}")
$(info "MAJOR=${MAJOR}")
$(info "MINOR=${MINOR}")
$(info "PATCH=${PATCH}")
endif

# ------------------------------------------------------------
# RECIPES
# ------------------------------------------------------------

start_deployment: ## Issue the start message.
	@echo "Building ${REPO_NAME} on branch ${BRANCH_NAME}@${GIT_HASH}..."
# END start_deployment

docker_pull_robot: ## Refresh the robot framework Docker image.
	@echo "Refreshing robot framework Docker image..."
	-docker pull ppodgorsek/robot-framework:latest
# END docker_pull_robot

docker_pull_sass: ## Refresh the robot framework Docker image.
	@echo "Refreshing SASS compiler Docker image..."
	@-docker pull registry.ocweb.team/og-sass-compiler:latest
# END docker_pull_sass

docker_login: ## Log into our private registry.
	@echo ":docker_login"
	@echo "Refreshing docker registry login..."
	@-echo "${DOCKER_PASSWORD}" | docker login --username ${DOCKER_USER} --password-stdin registry.ocweb.team
# END docker_login

docker_refresh: docker_login docker_pull_robot docker_pull_sass ## Refresh Docker components (login, standard images).
	@echo ":docker_refresh"
	@echo "Docker resources refreshed."
# END docker_refresh

test_pass: docker_refresh ## Run "PASS" tests against WordPress.
	@echo ":test_pass"
	@echo "Testing WordPress PASS conditions..."

	@echo "Creating reporting endpoint [ ${REPORT_ENDPOINT} ]..."
	mkdir -p ${REPORT_ENDPOINT}/report
	chmod -R 0777 ${REPORT_ENDPOINT}
	chown -R jenkins:jenkins ${REPORT_ENDPOINT}

	@echo "Testing installation..."
	cp ${PWD}/src/tests/creds.robot ${PWD}/src/tests/success/creds.robot
	cp ${PWD}/src/tests/login_resource.robot ${PWD}/src/tests/success/login_resource.robot
	-docker run --rm -e BROWSER=chrome -e ROBOT_THREADS=4 --shm-size=512m \
		-v ${REPORT_ENDPOINT}/report:/opt/robotframework/reports \
		-v ${PWD}/src/tests/success:/opt/robotframework/tests:Z \
	 	ppodgorsek/robot-framework 2>&1 > ${REPORT_ENDPOINT}/docker.output

	@echo " "
	@echo "------------------------------"
	@echo "Read [ ${REPORT_ENDPOINT}/docker.output ] for exit code..."
	cat ${REPORT_ENDPOINT}/docker.output
	@echo "------------------------------"
	@echo " "
# END test_pass

test_fail: docker_refresh ## Run "intended to fail" tests against WordPress (FAIL = passing).
	@echo ":test_pass"
	@echo "Testing WordPress 'FAIL = passing' conditions..."

	@echo "Nothing here yet."
# END test_fail

create_release: ## Makes a release, zips plugin, and uploads to release.
	@echo ":create_release"
	@echo "Creating release..."

	echo "GITHUB_TOKEN=${GITHUB_TOKEN}" > /tmp/release_env
	echo "REPO_NAME=${REPO_NAME}" >> /tmp/release_env
	echo "BRANCH_NAME=${BRANCH_NAME}" >> /tmp/release_env
	echo "BUILD_NUMBER=${BUILD_NUMBER}" >> /tmp/release_env

	/bin/bash /jd/scripts/create_plugin_release.sh /tmp/release_env
# END stamp

default: help