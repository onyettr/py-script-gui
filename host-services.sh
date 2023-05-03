#!/bin/bash
# Secure Enclave Services Release packager - Host SERVICES
# 

# 0.1.0 
# 0.2.0 SE-1269 adding codespell feature
# 0.3.0 SE-1217 updates for common services example builds
# 0.4.0         adding -cl(ean) option
# 0.5.0 SE-1440 adding CMake support for GNU C
# 0.6.0 SE-1512 adding License.txt to release
# 0.7.0 SE-1585 removing RTE, going CMSIS...
# 0.8.0 SE-1711 adding timestamp option
# 0.9.0 SE-1739 Remove libraries from manifest and release
# 0.9.1 SE-1742 Add REV_B0 examples by default to release pack. 
VERSION="0.9.1"

source ./common-utils.sh

# defaults
DEBUG_SUPPRESS_BUILD="OFF"
SPELLCHECK_SUPPRESS_BUILD="OFF"
TARBALL_OUTPUT="OFF"
CLEAN_BUILD="OFF"
BUILD_OPTION="ALL"
TIMESTAMP_OPTION="OFF"

#
# base directories
# release_dir         target directory for release, change as needed
#
release_dir=./se-host-service-release
services_dir=../services
setools_dir=.

# codespell
SPELLCHECK_TOOL_PARAM=--skip="*.o,*.bin,*.a,*.elf,*.hex,*.htm,*.disass,./example/mhu-comm-examples"
SPELLCHECK_TOOL="codespell"
SPELLCHECK_TOOL_CLI="codespell $SPELLCHECK_TOOL_PARAM"

# GIT 
current_branch=$(git rev-parse --abbrev-ref HEAD)

# Global error control
# -e enable exit on error
set -e

# Command line options parser 
display_release_help()
{
   echo "Usage: se-host-services-release builder"
   echo
   echo "Syntax: host-release [-option]                                     "
   echo "-h  --help      this screen                                        "
   echo "-b  --build     [B0]                                               "
   echo "-c  --codespell disable codespell build                            "
   echo "-cl --clean     clean up release directory                         "
   echo "-t  --tar       output tarball as well as ZIP                      "
   echo "-ts --time      output file contains date                          "
   echo "-v  --version   version                                            "
   echo "-zb --suppress  [DEBUG] suppress actual build                      "
   echo ""
#   echo "parameters: "
#   echo ""
#   echo "SPELLCHECK_SUPPRESS_BUILD $SPELLCHECK_SUPPRESS_BUILD               "
#   echo "DEBUG_SUPPRESS_BUILD      $DEBUG_SUPPRESS_BUILD                    "
#   echo "TIMESTAMP_OPTION          $TIMESTAMP_OPTION                        "
#   echo "TARBALL_OUTPUT            $TARBALL_OUTPUT                          "
#   echo "BUILD_OPTION              $BUILD_OPTION                            "
#   echo "CLEAN_BUILD               $CLEAN_BUILD                             "
#   echo "Default values are shown                                           "
   echo ""
   echo "Examples"
   echo ""
   echo " host-services.sh -cl           Clean, REV_A1 build, ZIP           "
   echo " host-services.sh -cl -b B0     Clean, REV_B0 build, ZIP           "
   echo " host-services.sh -cl -b B0 -ts Clean, REV_B0 build, ZIP, timestamp"
   echo
   echo "version $VERSION"
}

# internal debug function
function debug_show_params()
{
    echo "TARBALL_OUTPUT            $TARBALL_OUTPUT"
    echo "CLEAN_BUILD               $CLEAN_BUILD"
    echo "BUILD_OPTION              $BUILD_OPTION"
    echo "DEBUG SUPRESS             $DEBUG_SUPPRESS_BUILD"
}

# internal debug function
function show_params_short()
{
    release_print "[INFO] BOOTSTUB_SUPPRESS_BUILD   $DEBUG_SUPPRESS_BUILD"
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
            echo "[ERROR] Missing build argument [B0]"
            exit 1
        fi
        if [[ "$2" != @(B0) ]]; then
            echo "[ERROR] invalid build target [B0]"
            exit 1
        fi
        BUILD_OPTION="$2"
        shift 2
        ;;
      -c | --codespell)
        SPELLCHECK_SUPPRESS_BUILD="ON"
        shift 1
        ;;
      -cl | --clean)
        CLEAN_BUILD="ON"
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
      -v | --version)
        echo "$VERSION"
        if [ $# -le 1 ] 
        then
            exit 0
        fi
        shift 1
        ;;
       -zb | --suppress)
        DEBUG_SUPPRESS_BUILD="ON"
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

trap error_handler ERR

# Trap handler: any errors generated will force execution of the following
# negates the use of set -e ad make -i
function error_handler(){
  save_error=$?

  echo -n "[SETOOLS Release] Error - $save_error"
  echo " Running '$BASH_COMMAND' on line ${BASH_LINENO[0]}"

  exit $save_errorcode
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

# Clean up the build enviroonment
function clean_build()
{
    if [[ $CLEAN_BUILD == "ON" ]]
    then
        release_print "[INFO] CLEANing build"

        rm -rf se-host-service-release/ 
    else 
        release_print "[INFO] Skipped CLEAN build"
    fi
}

declare -a services_release_dir_rev_b0_manifest=(
    "$release_dir/example/m55_power"
    "$release_dir/example/m55_power/scatter"
    "$release_dir/example/m55_power/build"
    "$release_dir/example/m55_power/build/obj"
    "$release_dir/example/m55_power/inc"
    "$release_dir/example/m55_power/src"
)

#
# Release directory manifest
# each entry here will be a created directory
#
declare -a services_release_dir_manifest=(
    "$release_dir/services_lib"
    "$release_dir/example"
    "$release_dir/include"
    "$release_dir/build"
    "$release_dir/build/obj"
    "$release_dir/lib"
    "$release_dir/drivers"
    "$release_dir/drivers/include"
    "$release_dir/drivers/src"
    "$release_dir/example/common"
    "$release_dir/example/m55_he"
    "$release_dir/example/m55_hp"
    "$release_dir/example/m55_he/bin"
    "$release_dir/example/m55_he/build"
    "$release_dir/example/m55_he/build/obj"
    "$release_dir/example/m55_he/scatter"
    "$release_dir/example/m55_hp/bin"
    "$release_dir/example/m55_hp/build"
    "$release_dir/example/m55_hp/build/obj"
    "$release_dir/example/m55_hp/scatter"
    "$release_dir/example/a32_bare_metal"
    "$release_dir/example/a32_bare_metal/bin"
    "$release_dir/example/a32_bare_metal/src"
    "$release_dir/example/a32_bare_metal/build"
    "$release_dir/example/a32_bare_metal/build/obj"
    "$release_dir/example/a32_bare_metal/include"
    "$release_dir/example/services_app"
)

# Release build manifests:
# left entry is the source and the right entry is the destination
declare -a services_build_manifest=(
    "$services_dir/toolchain_make.mak"                                          "$release_dir/"
    "$services_dir/device_make-a1.mak"                                          "$release_dir/device_make.mak"
    "$services_dir/Makefile_linux"                                              "$release_dir/"
    "$services_dir/Makefile.gnu"                                                "$release_dir/"
    "$services_dir/Makefile"                                                    "$release_dir/"
	"$services_dir/CMakeLists.txt"                                              "$release_dir/"
    "$services_dir/License.txt"                                                 "$release_dir/"
    "$services_dir/README.md"                                                   "$release_dir/"
#   "$services_dir/toolchain-arm-non-eabi.cmake"                                "$release_dir/toolchain-arm-non-eabi.cmake"
#   "$services_dir/lib/libservices_m55_lib.a"                                   "$release_dir/lib/"
#   "$services_dir/lib/libservices_a32_lib.a"                                   "$release_dir/lib/"
#   "$services_dir/lib/libmhu_m55_lib.a"                                        "$release_dir/lib/"
#   "$services_dir/lib/libmhu_a32_lib.a"                                        "$release_dir/lib/"
    "$services_dir/include/services_lib_protocol.h"                             "$release_dir/include/"
    "$services_dir/include/services_lib_bare_metal.h"                           "$release_dir/include/"
    "$services_dir/include/services_lib_linux.h"                                "$release_dir/include/"
    "$services_dir/include/services_lib_api.h"                                  "$release_dir/include/"
    "$services_dir/include/services_lib_ids.h"                                  "$release_dir/include/"
    "$services_dir/drivers/include/drivers_common.h"                            "$release_dir/drivers/include/"
    "$services_dir/drivers/include/mhu_driver.h"                                "$release_dir/drivers/include/"
    "$services_dir/drivers/include/mhu.h"                                       "$release_dir/drivers/include/"
    "$services_dir/drivers/src/mhu_receiver.c"                                  "$release_dir/drivers/src/"
    "$services_dir/drivers/src/mhu_driver.c"                                    "$release_dir/drivers/src/"
    "$services_dir/drivers/src/mhu_sender.c"                                    "$release_dir/drivers/src/"
    "$services_dir/services_lib/services_host_handler_linux.c"                  "$release_dir/services_lib/"
    "$services_dir/services_lib/services_host_application.c"                    "$release_dir/services_lib/"
    "$services_dir/services_lib/services_host_maintenance.c"                    "$release_dir/services_lib/"
    "$services_dir/services_lib/services_host_cryptocell.c"                     "$release_dir/services_lib/"
    "$services_dir/services_lib/services_host_padcontrol.c"                     "$release_dir/services_lib/"
    "$services_dir/services_lib/services_host_handler.c"                        "$release_dir/services_lib/"
    "$services_dir/services_lib/services_host_clocks.c"                         "$release_dir/services_lib/"
    "$services_dir/services_lib/services_host_pinmux.c"                         "$release_dir/services_lib/"
    "$services_dir/services_lib/services_host_system.c"                         "$release_dir/services_lib/"
    "$services_dir/services_lib/services_host_error.c"                          "$release_dir/services_lib/"
    "$services_dir/services_lib/services_host_boot.c"                           "$release_dir/services_lib/"
    "$services_dir/services_lib/services_host_power.c"                          "$release_dir/services_lib/"
    "$services_dir/services_lib/CMakeLists.txt"                                 "$release_dir/services_lib/"

    "$services_dir/example/common/services_lib_interface.c"                     "$release_dir/example/common/"
    "$services_dir/example/common/services_lib_interface.h"                     "$release_dir/example/common/"
    "$services_dir/example/common/m55_services_main.c"                          "$release_dir/example/common/"
    "$services_dir/example/common/services_test.c"                              "$release_dir/example/common/"
    "$services_dir/example/common/newlib_stubs.c"                               "$release_dir/example/common/"
    "$services_dir/example/common/newlib_stubs.h"                               "$release_dir/example/common/"

    "$services_dir/example/m55_he/scatter/m55_he_services_test.scat"            "$release_dir/example/m55_he/scatter"
    "$services_dir/example/m55_he/scatter/m55_he_services_test_xip.scat"        "$release_dir/example/m55_he/scatter"
    "$services_dir/example/m55_he/scatter/m55_he_services_test.ld"              "$release_dir/example/m55_he/scatter"

    "$services_dir/example/m55_he/CMakeLists.txt"                               "$release_dir/example/m55_he/CMakeLists.txt"
    "$services_dir/example/m55_he/Makefile.gnu"                                 "$release_dir/example/m55_he/Makefile.gnu"
    "$services_dir/example/m55_he/Makefile"                                     "$release_dir/example/m55_he/Makefile"
    "$services_dir/example/m55_he/services-he-xip.json"                         "$release_dir/example/m55_he/services-he-xip.json"
    "$services_dir/example/m55_he/services-he.json"                             "$release_dir/example/m55_he/services-he.json"

    "$services_dir/example/m55_hp/CMakeLists.txt"                               "$release_dir/example/m55_hp/CMakeLists.txt"
    "$services_dir/example/m55_hp/Makefile.gnu"                                 "$release_dir/example/m55_hp/Makefile.gnu"
    "$services_dir/example/m55_hp/Makefile"                                     "$release_dir/example/m55_hp/Makefile"
    "$services_dir/example/m55_hp/services-he-hp-xip.json"                      "$release_dir/example/m55_hp/services-he-hp-xip.json"
    "$services_dir/example/m55_hp/services-hp-xip.json"                         "$release_dir/example/m55_hp/services-hp-xip.json"
    "$services_dir/example/m55_hp/services-he-hp.json"                          "$release_dir/example/m55_hp/services-he-hp.json"
    "$services_dir/example/m55_hp/services-hp.json"                             "$release_dir/example/m55_hp/services-hp.json"

    "$services_dir/example/m55_hp/scatter/m55_hp_services_test.scat"            "$release_dir/example/m55_hp/scatter"
    "$services_dir/example/m55_hp/scatter/m55_hp_services_test_xip.scat"        "$release_dir/example/m55_hp/scatter"
    "$services_dir/example/m55_hp/scatter/m55_hp_services_test.ld"              "$release_dir/example/m55_hp/scatter"    
    "$services_dir/example/m55_he/scatter/gcc_M55_HE_MRAM.ld"                   "$release_dir/example/m55_he/scatter"
    "$services_dir/example/m55_hp/scatter/gcc_M55_HP_MRAM.ld"                   "$release_dir/example/m55_hp/scatter"

    "$services_dir/example/a32_bare_metal/src/startup.s"                        "$release_dir/example/a32_bare_metal/src/"
    "$services_dir/example/a32_bare_metal/src/gic400.c"                         "$release_dir/example/a32_bare_metal/src/"
    "$services_dir/example/a32_bare_metal/src/main.c"                           "$release_dir/example/a32_bare_metal/src/"
    "$services_dir/example/a32_bare_metal/src/ipc.s"                            "$release_dir/example/a32_bare_metal/src/"
    "$services_dir/example/a32_bare_metal/include/system_level_functions.h"     "$release_dir/example/a32_bare_metal/include/"
    "$services_dir/example/a32_bare_metal/include/global_defines.h"             "$release_dir/example/a32_bare_metal/include/"
    "$services_dir/example/a32_bare_metal/include/sys_memory_map.h"             "$release_dir/example/a32_bare_metal/include/"
    "$services_dir/example/a32_bare_metal/include/cpu_asm_codes.h"              "$release_dir/example/a32_bare_metal/include/"
    "$services_dir/example/a32_bare_metal/include/core_cm0plus.h"               "$release_dir/example/a32_bare_metal/include/"
    "$services_dir/example/a32_bare_metal/include/sys_intr_map.h"               "$release_dir/example/a32_bare_metal/include/"
    "$services_dir/example/a32_bare_metal/include/mhu_test.h"                   "$release_dir/example/a32_bare_metal/include/"
    "$services_dir/example/a32_bare_metal/include/mhuv2_f1.h"                   "$release_dir/example/a32_bare_metal/include/"
    "$services_dir/example/a32_bare_metal/include/gic400.h"                     "$release_dir/example/a32_bare_metal/include/"
    "$services_dir/example/a32_bare_metal/include/system.h"                     "$release_dir/example/a32_bare_metal/include/"
    "$services_dir/example/a32_bare_metal/include/ipc.h"                        "$release_dir/example/a32_bare_metal/include/"
    "$services_dir/example/a32_bare_metal/a32_bare_metal_xip.scat"              "$release_dir/example/a32_bare_metal/"
    "$services_dir/example/a32_bare_metal/a32_bare_metal.scat"                  "$release_dir/example/a32_bare_metal/"
    "$services_dir/example/a32_bare_metal/services-a32-xip.json"                "$release_dir/example/a32_bare_metal/"
    "$services_dir/example/a32_bare_metal/services-a32.json"                    "$release_dir/example/a32_bare_metal/"
    "$services_dir/example/a32_bare_metal/Makefile"                             "$release_dir/example/a32_bare_metal/"

    "$services_dir/example/services-he-hp-a32-xip.json"                         "$release_dir/example/"
    "$services_dir/example/services-he-hp-a32.json"                             "$release_dir/example/"
    "$services_dir/example/services-he-hp-a32.json"                             "$release_dir/example/services-he-hp-a32.json"
    "$services_dir/example/arm_ds_debug_script_m55.ds"                          "$release_dir/example/"

    "$setools_dir/se-sw-services-user*.pdf"                                     "$release_dir/"
)

# Specific Manifest for REV_B0 Power example
declare -a setools_rev_b0_manifest=(
    "$services_dir/example/m55_power/scatter/m55_he_power_test.scat"            "$release_dir/example/m55_power/scatter"
    "$services_dir/example/m55_power/scatter/m55_he_power_test.ld"              "$release_dir/example/m55_power/scatter"

    "$services_dir/device_make-b0.mak"                                          "$release_dir/device_make.mak"
    "$services_dir/example/m55_power/Makefile"                                  "$release_dir/example/m55_power/"
    "$services_dir/example/m55_power/Makefile.gnu"                              "$release_dir/example/m55_power/"
    "$services_dir/example/m55_power/CMakeLists.txt"                            "$release_dir/example/m55_power/"

    "$services_dir/example/common/core_yamin.h"                                 "$release_dir/example/common"
    "$services_dir/example/common/exectb_mcu.h"                                 "$release_dir/example/common"
    "$services_dir/example/m55_power/inc/vbat_rtc.h"                            "$release_dir/example/m55_power/inc"
    "$services_dir/example/m55_power/src/services_test.c"                       "$release_dir/example/m55_power/src"
    "$services_dir/example/m55_power/src/vbat_rtc.c"                            "$release_dir/example/m55_power/src"
    "$services_dir/example/m55_power/src/power.c"                               "$release_dir/example/m55_power/src"
    "$services_dir/example/m55_power/src/main.c"                                "$release_dir/example/m55_power/src"

    "$services_dir/example/m55_power/services-he-power.json"                    "$release_dir/example/m55_power/"
    "$services_dir/example/services-he-hp-a32-b0.json"                          "$release_dir/example/services-he-hp-a32.json"
    "$services_dir/example/m55_he/services-he-b0.json"                          "$release_dir/example/m55_he/services-he.json"
    "$services_dir/example/m55_hp/services-he-hp-b0.json"                       "$release_dir/example/m55_hp/services-he-hp.json"
    "$services_dir/example/services-he-hp-a32-b0.json"                          "$release_dir/example/services-he-hp-a32.json"
  
    "$services_dir/device_make-b0.mak"                                          "$release_dir/device_make.mak"
    
    # these Malefiles are REV_B0 only !!!
#    "$services_dir-b0/Makefile_linux"                                              "$release_dir/Makefile_linux"
#    "$services_dir-b0/Makefile.gnu"                                                "$release_dir/Makefile.gnu"
#    "$services_dir-b0/Makefile"                                                    "$release_dir/Makefile"   
)

# create the release directory and subsequent sub-directories
function manifest_release_create(){
    release_print "-n" "[SETOOLS Release] creating release directory"
    release_print " creating $release_dir"
    mkdir $release_dir
 
    for i in "${services_release_dir_manifest[@]}"
    do
        release_print "+ creating $i"
        mkdir $i
    done

# create REV_B0 Directory manifest 
	if [[ $BUILD_OPTION == @("B0") ]]
	then
		release_print "[INFO] FUSION REV_B0 manifest creation"
		for i in "${services_release_dir_rev_b0_manifest[@]}"
		do
			release_print "+ creating $i"
			mkdir $i
		done
	fi
}

# use input manifest list and copy source to destination
# @brief manifest_copy  <list>
# @param[in] $1 manifest list
function manifest_copy(){
#    local -n argv1=$1  requires a later version of bash
  local argv=("$@")
  local len=${#argv[@]}
    
  for ((i=0; i<$len; i+=2))
  do
    cp ${argv[i]} ${argv[i+1]}
#    printf "\e[32m copying %-65s %-65s \e[0m\n" "${argv[$i]}" "${argv[$i+1]}"
    printf "\e[32m copying %-65s\t%s \e[0m\n" "${argv[$i]}" "${argv[$i+1]}"
  done
}

# Sanity check the release directory to start with
release_print "************ [SETOOLS] creating SERVICE release package **************"

# Clean Build
clean_build

release_print "-n" "[SETOOLS Release] SERVICES release directory: " $release_dir
if [ -d "$release_dir" ] 
then
    release_print " already exists"
else
    release_print " does not exist, will create"

    # Create the destination directory structure
    manifest_release_create
fi

# see if we can speed up builds
kernel_name="$(uname -s)"
includes "$kernel_name" "CYGWIN_NT" ||  release_print "[INFO] Parallel Make ENABLED" ; PARALLEL_TASKS="-j `nproc`"

profile_start

# SERVICES Host library manifest
release_print "** [SETOOLS Release] build Host Services libraries"
cd ../services

spell_check

# Build the Libraries using arm clang
if [[ $DEBUG_SUPPRESS_BUILD == @("OFF") ]]
then
    make realclean
	
	if [[ $BUILD_OPTION == @("B0") ]]
	then
		make ${PARALLEL_TASKS} -ks CPU=M55_HE DEVICE_REVISION=REV_B0 lib
	else
		make ${PARALLEL_TASKS} -ks CPU=M55_HE lib
	fi
	
    if [[ $? -ne 0 ]]; then
    exit 1
    fi

    make clean

	if [[ $BUILD_OPTION == @("B0") ]]
	then
		make ${PARALLEL_TASKS} -ks CPU=A32 DEVICE_REVISION=REV_B0 lib
	else
		make ${PARALLEL_TASKS} -ks CPU=A32 lib
	fi
	
    if [[ $? -ne 0 ]]; then
    exit 1
    fi

    make realclean
else
    release_print "[INFO] Skipped SERVICES Library build"
fi

cd ../setools
manifest_copy "${services_build_manifest[@]}"
if [[ $BUILD_OPTION == @("B0") ]]
then
    release_print "[INFO] FUSION REV_B0 manifest"
    manifest_copy "${setools_rev_b0_manifest[@]}"
fi

#
# The rest of the release manifest 
#
#echo "** [SETOOLS Release] copy other items"
#manifest_copy "${setools_others_manifest[@]}"

#
# Final step create the compressed tar ball 
#
release_print "-n" "** [SETOOLS Release] creating SERVICES release package "

# Tack on the Revision
if [[ $BUILD_OPTION == @("B0") ]]
then
    release_bundle="$release_dir-$current_branch-REV_B0"
else
    release_bundle="$release_dir-$current_branch"
fi

#echo "Bundle: $release_bundle"

# Tack on the date
if [[ $TIMESTAMP__OPTION == @("ON") ]]
then
    now_is_only_thing_that_is_real=$(date +"%m-%d")
    release_bundle="$release_bundle-$now_is_only_thing_that_is_real"
fi
release_tar="$release_bundle.zip"
release_print "\"$release_tar\""
zip -r $release_tar $release_dir/* 

if [[ $TARBALL_OUTPUT == @("ON") ]]
then
    release_tar="$release_bundle.tar"
    tar -czf $release_tar $release_dir/*
fi

profile_stop

# That's it
release_print ""
release_print "************ [SETOOLS] SERVICES release package complete **************"

# Fin
