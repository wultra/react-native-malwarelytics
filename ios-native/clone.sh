#!/bin/bash
###############################################################################
# Include common functions...
# -----------------------------------------------------------------------------
TOP=$(dirname $0)
source "${TOP}/common-functions.sh"
source "${TOP}/config.sh"

# -----------------------------------------------------------------------------
# USAGE prints help and exits the script with error code from provided parameter
# Parameters:
#   $1   - error code to be used as return code from the script
# -----------------------------------------------------------------------------
function USAGE
{
    echo ""
    echo "Usage:  $CMD  version  [options]"
    echo ""
    echo "  Script prepare git repository with PowerAuth mobile SDK source"
    echo "  codes with a specific version at the predefined local path."
    echo ""
    echo "    version        Existing PowerAuth mobile SDK version to prepare"
    echo "                   for Swift Package Manager inregration. Only X.Y.Z"
    echo "                   format is accepted or use 'develop' if develop"
    echo "                   build is going to prepare."
    echo ""
    echo "options are:"
    echo "    -v0            turn off all prints to stdout"
    echo "    -v1            print only basic log about build progress"
    echo "    -v2            print full build log with rich debug info"
    echo "    -h | --help    print this help information"
    echo ""
    exit $1
}

# -----------------------------------------------------------------------------
# Main script starts here

OPT_BRANCH=

while [[ $# -gt 0 ]]
do
    opt="$1"
    case "$opt" in
        -v*)
            SET_VERBOSE_LEVEL_FROM_SWITCH $opt ;;
        -h | --help)
            USAGE 0 ;;
        develop)
            VERSION='develop' 
            OPT_BRANCH='develop' ;;
        *)
            VALIDATE_AND_SET_VERSION_STRING $opt 
            OPT_BRANCH= ;;
    esac
    shift
done

[[ -z "$VERSION" ]] && FAILURE "You must specify version to clone."

REQUIRE_COMMAND git

SDK_DIR_NAME=$(basename "$SDK_DIR")
if [ -z "$OPT_BRANCH" ]; then
    SDK_BRANCH_NAME=spm/$VERSION
else
    SDK_BRANCH_NAME=$OPT_BRANCH
fi

# Validate cloned repository with SDK sources
DO_CLONE=0
if [ -d "$SDK_DIR" ]; then
    if [ ! -d "$SDK_DIR/.git" ]; then
        WARNING "Directory '$SDK_DIR_NAME' exists but is not a valid clone of git repository."
        $RM -rf "$SDK_DIR"
        DO_CLONE=1
    fi
else
    DO_CLONE=1
fi

# Silence output from git depending on verbose level
if [ x$VERBOSE == x2 ]; then
    GIT_VERBOSE=""
else
    GIT_VERBOSE="--quiet"
fi

# Clone or Fetch
if [ x$DO_CLONE == x1 ]; then
    LOG "Cloning SDK repository..."
    git clone --recurse-submodules $GIT_VERBOSE $SDK_REPO "$SDK_DIR"
    if [ -z "$OPT_BRANCH" ]; then
        LOG "Switching to version $VERSION..."
        git -C "$SDK_DIR" checkout $GIT_VERBOSE tags/$VERSION -b $SDK_BRANCH_NAME
    else
        LOG "Switching to branch $SDK_BRANCH_NAME..."
        git -C "$SDK_DIR" checkout $GIT_VERBOSE $SDK_BRANCH_NAME
    fi
else
    LOG "Updating SDK repository..."
    git -C "$SDK_DIR" fetch --all --tags $GIT_VERBOSE
    if [ -z "$OPT_BRANCH" ]; then
        LOG "Switching to version $VERSION..."
        if git -C "$SDK_DIR" rev-parse --quiet --verify $SDK_BRANCH_NAME 2>&1 1>/dev/null; then
            # Local branch for tag exists
            git -C "$SDK_DIR" checkout $GIT_VERBOSE $SDK_BRANCH_NAME
        else
            # Local branch for tag doesn't exist
            git -C "$SDK_DIR" checkout $GIT_VERBOSE tags/$VERSION -b $SDK_BRANCH_NAME
        fi
    else
        LOG "Switching to branch $SDK_BRANCH_NAME..."
        # Local branch for tag exists
        git -C "$SDK_DIR" checkout $GIT_VERBOSE $SDK_BRANCH_NAME
        LOG "Pulling changes for branch $SDK_BRANCH_NAME..."
        git -C "$SDK_DIR" pull $GIT_VERBOSE
    fi
fi
LOG "Updating submodules..."
git -C "$SDK_DIR" submodule update --recursive $GIT_VERBOSE
