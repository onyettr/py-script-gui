#!/bin/bash
# ##############################################################################
# Release builder script
# - creates and builds a release structure from the SE FW git repo into a
#   release archive
#
# - Component Builds include
#   - seram-bl 
#   - debug stubs
# 
# ##############################################################################

# Turn this on to debug ....
#set -x

# Version Trail
# 0.1.0     Added -d option for doxygen generation
VERSION="0.1.0"

source ./common-utils.sh

# Build option defaults
RELEASE_BUILD_PARAM=ON
DOCUMENTATION_BUILD="OFF"
DEBUG_SUPPRESS_BUILD="OFF"
BOOTSTUB_SUPPRESS_BUILD="OFF"
BURNER_SUPPRESS_BUILD="ON"
PROVISION_SUPPRESS_BUILD="OFF"
SPELLCHECK_SUPPRESS_BUILD="OFF"
MANIFEST_SUPPRESS="OFF"
HEX_GENERATE="OFF"
CLEAN_BUILD="OFF"
TARBALL_OUTPUT="OFF"
BUILD_OPTION="ALL"
TIMESTAMP_OPTION="OFF"

PLATFORM_OPTION="EVALUATION_BOARD"

DEBUG_EXIT="OFF"

# base directories
# release_dir         target directory for release, change as needed
release_dir=./bringup_package
seram_dir=../seram-bl
bootstubs_dir=../bootstubs 
setools_dir=.

# Doxygen
DOXYGEN_TOOL="doxygen"
DOXYGEN_BASE=./doxygen

# codespell skip
# hex files
# disass files
# erom.c as it gets confused with 'ba' 
SPELLCHECK_TOOL_PARAM=--skip="*.o,*.bin,*.a,*.elf,*.hex,*.htm,*.disass,erom.c"
SPELLCHECK_TOOL="codespell"
SPELLCHECK_TOOL_CLI="codespell $SPELLCHECK_TOOL_PARAM"

# GIT 
current_branch=$(git rev-parse --abbrev-ref HEAD)

#
# Trap handler: any errors generated will force execution of the following
# negates the use of set -e ad make -i
# Errors will print out in RED
function error_handler(){
  save_error=$?

if [ $save_error -ne 0 ]; then
# reset the trap so we dont come back in here
  trap '' EXIT

  echo -e "\e[31m"
  echo "***** [Release] Error - $save_error"
  echo " Running '$BASH_COMMAND' on line ${BASH_LINENO[0]}"
  echo -e "\e[0m"
  exit
fi

if [[ $save_error -eq 0 ]]; then
  echo "***** [Release] Build is ok, Error - $save_error"
fi

  exit
}

# Command line options parser 
display_release_help()
{
    echo "Usage: revb0 test release builder"
    echo
    echo "Syntax: revb0_test [-option]                                    "
    echo "-h  --help      this screen                                     "
    echo "-c  --codespell disable codespell build (default ENABLED)       "
    echo "-r  --release   disable release build (default ENABLED)         "
    echo "-t  --tar       output tarball as well as ZIP                   "
    echo "-v  --version   version                                         "
    echo "-cl --clean     clean up release directory (default DISABLED)   "
    echo "-mo --manoff    disable Manifest creation (default ENABLED)     "
    echo "-hx --hexon     enable HEX file creation (default DISABLED)     "
    echo "-ts --time      output file contains date                       "
    echo "-zb --suppress  [DEBUG] suppress actual build                   "
    echo "-zs --debugshow [DEBUG] show options set                        "
    echo
    echo "version $VERSION"
}

# internal debug function
function debug_show_params()
{
    echo "RELEASE_BUILD             $RELEASE_BUILD_PARAM"
    echo "DOCUMENTATION_BUILD       $DOCUMENTATION_BUILD"
    echo "DEBUG_SUPPRESS_BUILD      $DEBUG_SUPPRESS_BUILD"
    echo "BOOTSTUB_SUPPRESS_BUILD   $BOOTSTUB_SUPPRESS_BUILD"
    echo "SPELLCHECK_SUPPRESS_BUILD $SPELLCHECK_SUPPRESS_BUILD"
    echo "TARBALL_OUTPUT            $TARBALL_OUTPUT"
    echo "CLEAN_BUILD               $CLEAN_BUILD"
    echo "BUILD_OPTION              $BUILD_OPTION"
    echo "MANIFEST_SUPPRESS         $MANIFEST_SUPPRESS"
}

# internal debug function
function show_params_short()
{
    release_print "[INFO] BUILD_OPTION              $BUILD_OPTION"
    release_print "[INFO] RELEASE_BUILD             $RELEASE_BUILD_PARAM"
    release_print "[INFO] PLATFORM_OPTION           $PLATFORM_OPTION"
#    release_print "[INFO] BOOTSTUB_SUPPRESS_BUILD   $BOOTSTUB_SUPPRESS_BUILD"
#    release_print "[INFO] BURNER_SUPPRESS_BUILD     $BURNER_SUPPRESS_BUILD"
#    release_print "[INFO] PROVISION_SUPPRESS_BUILD  $PROVISION_SUPPRESS_BUILD"
#    release_print "[INFO] DOCUMENTATION_BUILD       $DOCUMENTATION_BUILD"
#    release_print "[INFO] SPELLCHECK_SUPPRESS_BUILD $SPELLCHECK_SUPPRESS_BUILD"
#    release_print "[INFO] TARBALL_OUTPUT            $TARBALL_OUTPUT"
}

while [ $# -gt 0 ]; do
  case "$1" in 
      -h | --help) 
        display_release_help 
        exit 1
        ;;
      -b | --build)
        if [ -z "$2" ]
        then
            echo "[ERROR] Missing build argument [ALL | B0]"
            exit 1
        fi
        if [[ "$2" != @(ALL|B0) ]]; then
            echo "[ERROR] invalid build target [ALL | B0]"
            exit 1
        fi
        BUILD_OPTION="$2"
        shift 2
        ;;
      -p | --platform)
        if [[ "$2" != @(FPGA|EVALUATION_BOARD) ]]; then
            echo "[ERROR] invalid platform target [EVALUATION_BOARD | FPGA]"
            exit 1
        fi
        PLATFORM_OPTION="$2"
        shift 2
        ;;
      -bs | --boot)
        BOOTSTUB_SUPPRESS_BUILD="ON"
        shift 1
        ;;
      -bu | --burner)
        BURNER_SUPPRESS_BUILD="ON"
        shift 1
        ;;
      -pr | --prov)
        PROVISION_SUPPRESS_BUILD="ON"
        shift 1
        ;;
      -mo | --manoff)
        MANIFEST_SUPPRESS="ON"
        shift 1
        ;;
      -hx | --hexon)
        HEX_GENERATE="ON"
        shift 1
        ;;
      -cl | --clean)
        CLEAN_BUILD="ON"
        shift 1
        ;;
      -c | --codespell)
        SPELLCHECK_SUPPRESS_BUILD="ON"
        shift 1
        ;;
      -d | --docs)
        DOCUMENTATION_BUILD="ON"
	    shift 1
	    ;;
      -r | --release)
        RELEASE_BUILD_PARAM=OFF
        shift 1
        ;;
      -t | --tarball)
        TARBALL_OUTPUT="ON"
        shift 1
        ;;
      -ts | --time)
        TIMESTAMP__OPTION="ON"
        shift 1
        ;;
      -zb | --suppress)
        DEBUG_SUPPRESS_BUILD="ON"
        BURNER_SUPPRESS_BUILD="ON"
        PROVISION_SUPPRESS_BUILD="ON"
        BOOTSTUB_SUPPRESS_BUILD="ON"
        shift 1
        ;;
      -zs | --debugshow)
        DEBUG_EXIT="ON"
        shift 1
        ;;
      -v | --version)
        echo "$VERSION"
        if [ $# -le 1 ] 
        then
            exit 0
        fi
        shift 1
        ;;
      *) 
        echo "[ERROR] unknown option $1"
        exit 1
        break
        ;;
  esac
done

shift $((OPTIND -1))

if [[ $DEBUG_EXIT == @("ON") ]]
then
    debug_show_params
    exit 1
fi

release_print "************ [REV_B0] creating test release package **************"
#release_print "Build Option  $BUILD_OPTION, Release build $RELEASE_BUILD, DOCS $DOCUMENTATION_BUILD"
show_params_short

# see if we can speed up builds
kernel_name="$(uname -s)"
includes "$kernel_name" "CYGWIN_NT" ||  release_print "[INFO] Parallel Make             ENABLED" ; PARALLEL_TASKS="-j `nproc`"

# Error Handling
trap error_handler ERR EXIT

# Global error control
# -e enable exit on error
set -e

#
# Release build manifests:
# left entry is the source and the right entry is the destination
#

declare -a setools_seram_manifest=(
    "$seram_dir/build/seram_fusion_b0_evaluation_board.elf" "$release_dir/"
    "$seram_dir/build/seram_fusion_b0_evaluation_board.bin" "$release_dir/"
)

declare -a setools_m55_stub_manifest=(
    "$bootstubs_dir/m55_stub/build/m55_stub.bin"                "$release_dir/"
)

# Common Manifest for all devices
declare -a setools_common_manifest=(
    "$seram_dir/rev_b0_bringup_script.ds"                       "$release_dir/"
    "$setools_dir/load_script.py"                               "$release_dir/"
    "$setools_dir/jlink/b0_he_memap_patch.jlinkscript"          "$release_dir/"
    "$setools_dir/jlink/rev_b0_bringup_script.jlink"            "$release_dir/"
    "$setools_dir/jlink/handler_exit.bin"                       "$release_dir/"
    "$setools_dir/jlink/handler_exit.S"                         "$release_dir/"
    "$setools_dir/jlink/hf_clear.bin"                           "$release_dir/"
)

# Release directory manifest
# each entry here will be created
declare -a setools_release_dir_manifest=(
)

# create the release directory and subsequent sub-directories
function manifest_release_create(){
    if [[ $MANIFEST_SUPPRESS == "ON" ]]
    then
      release_print "[INFO] Skipped Manifest release create"
    else
      release_print "[SETOOLS Release] creating release directory"
      release_print "creating $release_dir"
      mkdir $release_dir
 
      for i in "${setools_release_dir_manifest[@]}"
      do
        release_print "+ creating $i"
        mkdir $i
      done
    fi
}

# use input manifest list and copy source to destination
# @brief manifest_copy  <list>
# @param[in] $1 manifest list
#
function manifest_copy(){
#    local -n argv1=$1  requires a later version of bash
  local argv=("$@")
  local len=${#argv[@]}

  if [[ $MANIFEST_SUPPRESS == "ON" ]]
  then
     release_print "[INFO] Skipped Manifest copy"
  else
     for ((i=0; i<$len; i+=2))
     do
        cp ${argv[i]} ${argv[i+1]}
#        printf "\e[32m copying %-30s \t %-30s \e[0m\n" "${argv[$i]}" "${argv[$i+1]}"
        printf "\e[32m copying %-50s\t%.50s \e[0m\n" "${argv[$i]}" "${argv[$i+1]}"
     done
  fi
}

#  support function to see if an external programme exists
function test_exists()
{
    command -v "$1" >/dev/null
}

# generate the documentation
# @brief create documentation e.g. doxygen
function generate_docs()
{
    local argv=("$@")
    if [[ $DOCUMENTATION_BUILD == "ON" ]]
    then
        export PROJECT_NUMBER="$argv"
        if test_exists $DOXYGEN_TOOL 
        then
            release_print "[INFO] Generating Doxygen documentation for $PROJECT_NUMBER"
            cd ../$DOXYGEN_BASE
#            pwd
#            $DOXYGEN_TOOL $DOXYGEN_BASE/Doxyfile > $DOXYGEN_BASE/doxylog.txt 2>&1
            $DOXYGEN_TOOL Doxyfile > doxylog.txt 
            cd ../setools
#            pwd
            release_print "[INFO] Generated Doxygen documentation in $DOXYGEN_BASE"

        else
            release_error "[ERROR] doxygen tool is missing"
            exit 1     # trigger the error handler
        fi
        exit 0
    else
        release_print "[INFO] Skipped Doxygen DOCUMENTATION BUILD"
    fi
}

# generate spell check on sources before build
# @brief run spell before release
function spell_check()
{
    if [[ $SPELLCHECK_SUPPRESS_BUILD == "OFF" ]]
    then
        if test_exists $SPELLCHECK_TOOL
        then
            release_print "[SETOOLS Release] spell phase"
#            $(echo $SPELLCHECK_TOOL_CLI)
            
            # Get the return code from teh spellcheck issue warning only
            exit_result=0
            $SPELLCHECK_TOOL_CLI || exit_result=$?
            if [ $exit_result -ne 0 ]
            then
                release_error "[ERROR] spelling mistakes"
            fi
        else
            release_error "[ERROR] spell check $SPELLCHECK_TOOL is missing"
            exit 1     # trigger the error handler
        fi
    else
        release_print "[INFO] Skipped SPELLCHECK"
    fi
}

# generate the executables
# @brief 
function executable_create()
{
    if [[ $EXE_CREATE_SUPPRESS_BUILD == "OFF" ]]
    then
        opsys=$(what_os)
	
        if [[ $opsys == "Cygwin" ]]
        then
            release_print "[INFO] build EXECUTABLE (Windows)"
	    if [[ ! -d "app-release" ]]
	    then
		release_error "[ERROR] app-release directory not created, run oem-release.sh"
		exit 1     # trigger the error handler		
	    fi

            # Clean out the previous version
#            rm -rf app-release-exec/
#            python3 build-app-executables.py
        fi

        if [[ $opsys == "Linux" ]]
        then
            release_print "[INFO] build EXECUTABLE (Linux)"

	    if [[ ! -d "app-release" ]]
	    then
		release_error "[ERROR] app-release-linux directory not created, run oem-release.sh"
		exit 1 # trigger 
	    fi
 
            # Clean out the previous version
 #           rm -rf app-release-exec-linux/
 #           rm -rf venv/
 #           python3 build-app-executables-linux.py
        fi
    else
        release_print "[INFO] Skipped build EXECUTABLE"
    fi
}

# Clean up the build enviroonment
function clean_build()
{
    if [[ $CLEAN_BUILD == "ON" ]]
    then
        release_print "[INFO] CLEANing build"
        rm -rf $release_dir
        rm -f $release_dir*.zip
    else 
        release_print "[INFO] Skipped CLEAN build"
    fi
}

function generate_bootstubs_m55()
{
    # bootstubs manifest M55
    if [[ $BOOTSTUB_SUPPRESS_BUILD == @("OFF") ]]
    then
        release_print "** [Release] build bootstub"

        cd ../bootstubs/m55_stub

        make clean
        make ${PARALLEL_TASKS}
        if [[ $? -ne 0 ]]
        then
            exit 1
        fi

        cd ../../setools

        manifest_copy "${setools_m55_stub_manifest[@]}"
    else
        release_print "[INFO] Skipped boot stubs for M55"
    fi
}

function generate_seram()
{
    # seram-bl manifest for different builds (REVs and Platforms)
    cd ../seram-bl

    spell_check

    # seram-bl manifest for different builds (REVs and Platforms)
    if [[ $BUILD_OPTION == @("ALL"|"B0") && $DEBUG_SUPPRESS_BUILD == @("OFF") ]]
    then
        release_print "** [Release] seram-bl Build for REV_B0, $PLATFORM_OPTION, Release $RELEASE_BUILD_PARAM"
        make clean
        make ${PARALLEL_TASKS} DEVICE_TYPE=FUSION DEVICE_REVISION=REV_B0 PLATFORM_TYPE=$PLATFORM_OPTION RELEASE_BUILD=$RELEASE_BUILD_PARAM
        if [[ $? -ne 0 ]]
        then
            exit 1
        fi
    else
        release_print "[INFO] Skipped SERAM build for REV_B0"
    fi
}

# Run through SERAM manifests and build as needed
function generate_seram_manifest_copy()
{
    cd ../setools

    # SERAM image copying
    if [[ $BUILD_OPTION == @("ALL") ]]
    then
        manifest_copy "${setools_seram_manifest[@]}"
    fi

    # The rest of the release manifest 
    #
    release_print "** [Release] copy common items"
    manifest_copy "${setools_common_manifest[@]}"
    
    if [[ $BUILD_OPTION == @("B0") ]]
    then
        release_print "** [Release] copy B0 items"
        if [[ $PLATFORM_OPTION == @("EVALUATION_BOARD") ]]
        then
            release_print "** [Release] copy EVALUATION BOARD B0 items"
            manifest_copy "${setools_seram_rev_b0_manifest[@]}"
        fi
    fi
}

# ##############################################################################
# Start of the Release builder Execution Path
# STEPS: 
# 1     Check the directory existence
# 2     Generate DOXYGEN release
# 6     BOOTSTUBS - M55
# 7     SERAM Source builds
# 8     SERAM Manifest Copy
# 10    Create TAR / ZIP bundle
# ##############################################################################

profile_start                       # Take the start Time here

clean_build                         # Clean Build

# Sanity check the release directory to start with
release_print "-n" "[Release] release directory: " $release_dir
if [ -d "$release_dir" ] 
then
    release_print " already exists"
else
    release_print " does not exist, will create"
    manifest_release_create         # Create release directory structure
fi

# Generate documents
generate_docs "$current_branch"

generate_bootstubs_m55              # Generate BOOTSTUBS M55

generate_seram                      # Generate SERAM-BL

generate_seram_manifest_copy        # Generate SERAM-BL Manifest copy

#cd ../
pwd
# Final step create the compressed tar ball 
if [[ $MANIFEST_SUPPRESS == "ON" ]]
then
   release_print "[INFO] Skipped release package create"
else
    # Tack on the Revision
    release_bundle="$release_dir-$current_branch"

    # Tack on the date
    if [[ $TIMESTAMP__OPTION == @("ON") ]]
    then
        now_is_only_thing_that_is_real=$(date +"%m-%d")
        release_bundle="$release_bundle-$now_is_only_thing_that_is_real"
    fi
    echo $release_dir

    release_print "-n" "** [Release] creating release package "
    release_tar="$release_bundle.zip"
    release_print "\"$release_tar\""

    zip -r $release_tar $release_dir

    if [[ $TARBALL_OUTPUT == @("ON") ]]
    then
    #    release_tar="$release_dir-$current_branch.tar"
        release_tar="$release_bundle.tar"
#        tar -czf $release_tar $release_dir/*
    fi
fi

release_print ""

profile_stop

printf "\e[32m ** Build Time %02dm%02ds \e[0m\n" $minutes_time $seconds_time

release_print "************ [REV_B0] test release package complete **************"

# Fin
