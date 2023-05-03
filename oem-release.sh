#!/bin/bash
#
# mram_burner, oem-provision, seram-bl are all built from scratch
# 
# 0.1.0 Conept + realisation
# 0.2.0 Added EXE creation facility 
# 0.3.0 Added B0 build
# 0.4.0 Deprecated A0 support (do not include header.bin)
# 0.5.0 add timestamp (date) to output file
# 0.6.0 modified global-cfg.db name in copy source
# 0.6.1 added isp/device_probe.py
# 0.6.2 copying REV_B0 example JSONs 
VERSION="0.6.2"

source ./common-utils.sh

# defaults
SPELLCHECK_SUPPRESS_BUILD="OFF"
EXE_CREATE_SUPPRESS_BUILD="ON"
PROVISION_SUPPRESS_BUILD="ON"  # OEM Provision is not enabled currently
BOOTSTUB_SUPPRESS_BUILD="OFF"
DEBUG_SUPPRESS_BUILD="OFF"
TARBALL_OUTPUT="OFF"
BUILD_OPTION="ALL"
HEX_GENERATE="OFF"
CLEAN_BUILD="OFF"
TIMESTAMP_OPTION="OFF"

#
# base directories
# release_dir         target directory for release, change as needed
#
release_dir=./app-release
release_dir_exec=./app-release-exec
bootstubs_dir=../bootstubs
app_prov_dir=./factory-tools/app-prov
setools_dir=.

# codespell
SPELLCHECK_TOOL_PARAM=--skip="*.hex,*.disass"
SPELLCHECK_TOOL="codespell"
SPELLCHECK_TOOL_CLI="codespell $SPELLCHECK_TOOL_PARAM"

# GIT 
current_branch=$(git rev-parse --abbrev-ref HEAD)

# Command line options parser 
display_release_help()
{
   echo "Usage: app-release builder"
   echo
   echo "Syntax: app-release [-option]                                   "
   echo "-h  --help      this screen                                     "
   echo "-b  --build     (default A1) B0                                 "
   echo "-c  --codespell disable codespell build (default ENABLED)       "
   echo "-e  --exe       enable EXEcuteable build (default DISABLED)     "
   echo "-bs --boot      disable bootstub build (default ENABLED)        "
   echo "-pr --prov      enable  provision tool build (default DISABLED) "
   echo "-hx --hexon     enable HEX file creation (default DISABLED)     "
   echo "-t  --tar       output tarball as well as ZIP                   "
   echo "-ts --time      output file contains date                       "
   echo "-v  --version   version                                         "
   echo "-zb --suppress  [DEBUG] suppress actual build                   "
   echo
   echo "version $VERSION"
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
      -e | --exe)
        EXE_CREATE_SUPPRESS_BUILD="OFF"
        shift 1
        ;;
      -bs | --boot)
        BOOTSTUB_SUPPRESS_BUILD="ON"
        shift 1
        ;;
      -pr | --prov)
        PROVISION_SUPPRESS_BUILD="ON"
        shift 1
        ;;
      -hx | --hexon)
        HEX_GENERATE="ON"
        shift 1
        ;;
      -zb | --suppress)
        DEBUG_SUPPRESS_BUILD="ON"
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
      *) 
        echo "[ERROR] unknown option $1"
        exit 1
        break
        ;;
  esac
done

shift $((OPTIND -1))

#
# Trap handler: any errors generated will force execution of the following
# negates the use of set -e ad make -i
# Errors will print out in RED
function error_handler()
{
  save_error=$?
  
  if [ $save_error -ne 0 ]; then
  # reset the trap so we dont come back in here
    trap '' EXIT

    echo -e "\e[31m"
    echo "***** [SETOOLS App Release] Error - $save_error"
    echo " Running '$BASH_COMMAND' on line ${BASH_LINENO[0]}"
    echo -e "\e[0m"
    exit
  fi

  if [[ $save_error -eq 0 ]]; then
    release_print "***** [SETOOLS Release] Build is ok, Error - $save_error"
  fi

  exit
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

            # Clean out the previous version
            rm -rf app-release-exec/
        fi
 
        if [[ $opsys == "Linux" ]]
        then
            release_print "[INFO] build EXECUTABLE (Linux)"

            # Clean out the previous version
            rm -rf app-release-exec-linux/
            rm -rf venv/
        fi

        if [[ $TIMESTAMP__OPTION == @("ON") ]]
        then
            python3 build-app-executables.py 1 $BUILD_OPTION
        else
            python3 build-app-executables.py 0 $BUILD_OPTION
        fi

    else
        release_print "[INFO] Skipped build EXECUTABLE"
    fi
}

# Error Handling
trap error_handler ERR EXIT

# Global error control
# -e enable exit on error
set -e

# see if we can speed up builds
kernel_name="$(uname -s)"
includes "$kernel_name" "CYGWIN_NT" ||  release_print "[INFO] Parallel Make ENABLED" ; PARALLEL_TASKS="-j `nproc`"

# Release build manifests:
# formt is left entry is the source and the right entry is the destination

declare -a setools_a32_stub_manifest=(
    "$bootstubs_dir/a32_stub/build/a32_stub_0.bin"     "$release_dir/build/images/a32_stub_0.bin"
)

declare -a setools_m55_stub_manifest=(
    "$bootstubs_dir/m55_stub/build/m55_stub.bin"        "$release_dir/build/images/m55_stub_hp.bin"
    "$bootstubs_dir/m55_stub/build/m55_stub.bin"        "$release_dir/build/images/m55_stub_he.bin"
    "$bootstubs_dir/m55_bare_metal_xip/build/m55_blink_he.bin"  "$release_dir/build/images/m55_blink_he.bin"
)

# Common Manifest for each APP-RELEASE
declare -a setools_others_manifest=(
    "$setools_dir/updateSystemPackage.py"               "$release_dir/"
    "$setools_dir/app-write-mram.py"                    "$release_dir/"
#      $setools_dir/create_image.py"                      "$release_dir/"
    "$setools_dir/tools-config.py"                      "$release_dir/"
    "$setools_dir/app-gen-rot.py"                       "$release_dir/"
    "$setools_dir/app-gen-toc.py"                       "$release_dir/"
    "$setools_dir/maintenance.py"                       "$release_dir/"
#     "$setools_dir/sign_image.py"                        "$release_dir/"

#   "$setools_dir/icv-release/build/AlifTocPackage.bin.sign" "$release_dir/alif/SystemPackage.bin.sign"
#   "$setools_dir/icv-release/build/AlifTocPackage.bin" "$release_dir/alif/SystemPackage.bin"
#   "$setools_dir/icv-release/build/header.bin"         "$release_dir/alif"
#   "$setools_dir/icv-release/build/offset.bin.sign"    "$release_dir/alif"
#   "$setools_dir/icv-release/build/offset.bin"         "$release_dir/alif"

 # for now, we copy all generated packages but it would be better to have more control...
    "$setools_dir/icv-release/build/SystemPackage-rev*"  "$release_dir/alif"
    "$setools_dir/icv-release/build/offset-rev*"         "$release_dir/alif"

#   Build Config items
    "$setools_dir/build/config/app-cpu-stubs.json"      "$release_dir/build/config"
    "$setools_dir/build/config/app-cfg.json"            "$release_dir/build/config" 
    "$setools_dir/build/config/app-cfg-b0.json"         "$release_dir/build/config" 
    "$setools_dir/build/config/app-cpu-stubs-b0.json"   "$release_dir/build/config"
# @todo when we switch to REV_B0 as default, the above lines need to change

#    "$setools_dir/build/images/m55_blink_he.bin"        "$release_dir/build/images"

    "$setools_dir/cert/OEMSBKey1.crt"                   "$release_dir/cert"
    "$setools_dir/cert/OEMSBKey2.crt"                   "$release_dir/cert"

# All ISP components
    "$setools_dir/isp/otp_mfgr_decode.py"               "$release_dir/isp"
    "$setools_dir/isp/version_decode.py"                "$release_dir/isp"
    "$setools_dir/isp/serom_errors.py"                  "$release_dir/isp"
    "$setools_dir/isp/trace_decode.py"                  "$release_dir/isp"
    "$setools_dir/isp/power_decode.py"                  "$release_dir/isp"
    "$setools_dir/isp/isp_protocol.py"                  "$release_dir/isp"
    "$setools_dir/isp/serialport.py"                    "$release_dir/isp"
    "$setools_dir/isp/toc_decode.py"                    "$release_dir/isp"
    "$setools_dir/isp/isp_print.py"                     "$release_dir/isp"
    "$setools_dir/isp/isp_util.py"                      "$release_dir/isp"
    "$setools_dir/isp/isp_core.py"                      "$release_dir/isp"
    "$setools_dir/isp/recovery.py"                      "$release_dir/isp"
    "$setools_dir/isp/otp.py"                           "$release_dir/isp"
    "$setools_dir/isp/device_probe.py"                  "$release_dir/isp"

    "$setools_dir/utils/cert_sb_content_util.py"        "$release_dir/utils"
    "$setools_dir/utils/user_validations.py"            "$release_dir/utils"
    "$setools_dir/utils/device_config.py"               "$release_dir/utils"
    "$setools_dir/utils/cert_key_util.py"               "$release_dir/utils"
    "$setools_dir/utils/hbk_gen_util.py"                "$release_dir/utils"
    "$setools_dir/utils/rsa_keygen.py"                  "$release_dir/utils"
    "$setools_dir/utils/toc_common.py"                  "$release_dir/utils"
    "$setools_dir/utils/firewall.py"                    "$release_dir/utils"
    "$setools_dir/utils/discover.py"                    "$release_dir/utils"
    "$setools_dir/utils/config.py"                      "$release_dir/utils"
    "$setools_dir/utils/pinmux.py"                      "$release_dir/utils"
    "$setools_dir/utils/clocks.py"                      "$release_dir/utils"
    "$setools_dir/utils/proj.cfg"                       "$release_dir/utils"
    "$setools_dir/utils/LICENSE"                        "$release_dir/utils"

    "$setools_dir/utils/app-jtag-adapters.db"           "$release_dir/utils/jtag-adapters.db"
    "$setools_dir/utils/app-devicesDB.db"               "$release_dir/utils/devicesDB.db"
    "$setools_dir/utils/app-familiesDB.db"              "$release_dir/utils/familiesDB.db"
    "$setools_dir/utils/app-featuresDB.db"              "$release_dir/utils/featuresDB.db"
    "$setools_dir/utils/app-global-cfg.db"              "$release_dir/utils/global-cfg.db"
    "$setools_dir/utils/menuconfDB.db"                  "$release_dir/utils"
    "$setools_dir/utils/maintDB.db"                     "$release_dir/utils"

    "$setools_dir/utils/lzf-lnx"                        "$release_dir/utils"
    "$setools_dir/utils/lzf.exe"                        "$release_dir/utils"
   
    "$setools_dir/utils/cfg/OEMSBContent_lvs_1.cfg"     "$release_dir/utils/cfg"
    "$setools_dir/utils/cfg/OEMSBContent_lvs_2.cfg"     "$release_dir/utils/cfg"
    "$setools_dir/utils/cfg/OEMSBKey1.cfg"              "$release_dir/utils/cfg"
    "$setools_dir/utils/cfg/OEMSBKey2.cfg"              "$release_dir/utils/cfg"

    "$setools_dir/utils/common/flags_global_defines.py" "$release_dir/utils/common"
    "$setools_dir/utils/common/global_defines.py"       "$release_dir/utils/common"
    "$setools_dir/utils/common/certificates.py"         "$release_dir/utils/common"
    "$setools_dir/utils/common/cryptolayer.py"          "$release_dir/utils/common"
    "$setools_dir/utils/common/exceptions.py"           "$release_dir/utils/common"
    "$setools_dir/utils/common/util_logger.py"          "$release_dir/utils/common"

    "$setools_dir/utils/common_cert_lib/developercertificateconfig.py" "$release_dir/utils/common_cert_lib"
    "$setools_dir/utils/common_cert_lib/contentcertificateconfig.py"   "$release_dir/utils/common_cert_lib"
    "$setools_dir/utils/common_cert_lib/enablercertificateconfig.py"   "$release_dir/utils/common_cert_lib"
    "$setools_dir/utils/common_cert_lib/keycertificateconfig.py"       "$release_dir/utils/common_cert_lib"
    "$setools_dir/utils/common_cert_lib/x509certificateconfig.py"      "$release_dir/utils/common_cert_lib"

    "$setools_dir/utils/key/oem_keys_pass.pwd"          "$release_dir/utils/key"
    "$setools_dir/utils/key/OEMSBContentPublic.pem"     "$release_dir/utils/key"
    "$setools_dir/utils/key/OEMSBKeyPublic.pem"         "$release_dir/utils/key"
    "$setools_dir/utils/key/OEMRoTPublic.pem"           "$release_dir/utils/key"
    "$setools_dir/utils/key/OEMSBContent.pem"           "$release_dir/utils/key"
    "$setools_dir/utils/key/OEMSBKey.pem"               "$release_dir/utils/key"
    "$setools_dir/utils/key/OEMRoT.pem"                 "$release_dir/utils/key"
    "$setools_dir/utils/key/hbk1_hash.txt"              "$release_dir/utils/key"
    "$setools_dir/utils/key/hbk1_zeros.txt"             "$release_dir/utils/key"
    "$setools_dir/utils/key/kce.txt"                    "$release_dir/utils/key"

    "$setools_dir/Alif*.pdf"                            "$release_dir/"

    "$setools_dir/utils/gen_fw_cfg.py"                  "$release_dir/utils"
)

# Specific Manifets (items to copy over) for REV_B0
declare -a setools_rev_b0_manifest=(
    "$setools_dir/utils/app-global-cfg-b0.db"           "$release_dir/utils/global-cfg.db"
    "$setools_dir/build/config/device-config-app.json"  "$release_dir/build/config/device-config-app.json" 
    "$setools_dir/build/config/app-cfg-b0.json"         "$release_dir/build/config/app-cfg.json" 
    "$setools_dir/build/config/app-cpu-stubs-b0.json"   "$release_dir/build/config/app-cpu-stubs.json"
# Rev_B0 only configuration
#   "$setools_dir/utils/app-featuresDB-b0.db"           "$release_dir/utils/featuresDB.db"
)

#
# Release directory manifest
# each directory entry here will be created
#
declare -a setools_release_dir_manifest=(
    "$release_dir/alif"
    "$release_dir/build"
    "$release_dir/build/config"
    "$release_dir/build/images"
    "$release_dir/build/logs"
    "$release_dir/utils"
    "$release_dir/utils/cfg"
    "$release_dir/utils/key"
    "$release_dir/utils/common"
    "$release_dir/utils/common_cert_lib"
    "$release_dir/cert"
    "$release_dir/bin"
    "$release_dir/isp"
)

#
# create the release directory and subsequent sub-directories
#
function manifest_release_create(){
    if [[ $DEBUG_SUPPRESS_BUILD == "ON" ]]
    then
        release_print "[INFO] Skipped Manifest release create"
    else
        release_print "[SETOOLS Application Release] creating release directory"
        release_print "creating $release_dir"
        mkdir $release_dir
 
        for i in "${setools_release_dir_manifest[@]}"
        do
            release_print "+ creating $i"
            mkdir $i
        done
    fi
}

# 
# use input manifest list and copy source to destination
# @brief manifest_copy  <list>
# @param[in] $1 manifest list
#
function manifest_copy(){
#    local -n argv1=$1  requires a later version of bash
  local argv=("$@")
  local len=${#argv[@]}

  if [[ $DEBUG_SUPPRESS_BUILD == "ON" ]]
  then
    release_print "[INFO] Skipped Manifest release copy"
  else    
    for ((i=0; i<$len; i+=2))
    do
        cp ${argv[i]} ${argv[i+1]}
        printf "\e[32m copying %-30s \t %-30s \e[0m\n" "${argv[$i]}" "${argv[$i+1]}"
    done
  fi
}

release_print "*********** [SETOOLS] creating Application release package *************"

# see if we can speed up builds
kernel_name="$(uname -s)"
includes "$kernel_name" "CYGWIN_NT" ||  release_print "[INFO] Parallel Make ENABLED" ; PARALLEL_TASKS="-j `nproc`"

profile_start

# Sanity check: oem-release.sh has to be run after icv-release.sh
# for some dependencies. So check that icv-release/ already exists...

release_print "[SETOOLS Release] Checking if icv-release/ folder exists..."
release_print "-n" "folder icv-release/"
if [ -d "icv-release/" ] 
then
    release_print "[INFO] already exists. Continue with process..."
else
    release_print "[ERROR] does not exist... Process will stop!"
    exit 1
fi

# Sanity check the release directory to start with
release_print "-n" "[SETOOLS Release] Application release directory: " $release_dir
if [ -d "$release_dir" ] 
then
    release_print " already exists"
else
    release_print " does not exist, will create"
    manifest_release_create
fi

# oem-provision manifest
if [[ $PROVISION_SUPPRESS_BUILD == @("OFF") ]]
then
    release_print "** [SETOOLS Application Release] build oem provision"
    cd factory-tools/oem-prov
    
    if [[ $DEBUG_SUPPRESS_BUILD == @("OFF") ]]
    then
        $(make clean)
        make ${PARALLEL_TASKS} -i
        if [[ $? -ne 0 ]]; then
            exit 1
        fi
     fi
#    manifest_copy "${setools_oemprov_manifest[@]}"

    cd ../..
else
    release_print "[INFO] Skipped oem Provision build as not enabled"
fi

#
# bootstubs manifest
#
if [[ $BOOTSTUB_SUPPRESS_BUILD == @("OFF") ]]
then
    release_print "** [SETOOLS Application Release] build bootstubs"
    cd ../bootstubs/a32_stub

    if [[ $DEBUG_SUPPRESS_BUILD == @("OFF") ]]
    then
        make clean
        make ${PARALLEL_TASKS} A32_CORE=0
        if [[ $? -ne 0 ]]; then
            exit 1
        fi
    fi
#    make clean
#    make ${PARALLEL_TASKS} A32_CORE=0 XIP=ON

    cd ../../setools
    manifest_copy "${setools_a32_stub_manifest[@]}"

# Bootstubs::m55_debug stubs / non-xip
    cd ../bootstubs/m55_stub
    if [[ $DEBUG_SUPPRESS_BUILD == @("OFF") ]]
    then
        make clean
        make ${PARALLEL_TASKS} -i
        if [[ $? -ne 0 ]]; then
            exit 1
        fi
    fi

    #make clean
    #make ${PARALLEL_TASKS} XIP=ON CPU_NAME=M55_HE
    #make clean
    #make ${PARALLEL_TASKS} XIP=ON CPU_NAME=M55_HP

    cd ../../setools

# Bootstubs::m55_blinky xip / non-xip
    cd ../bootstubs/m55_bare_metal_xip

    if [[ $DEBUG_SUPPRESS_BUILD == @("OFF") ]]
    then
        make realclean
        make ${PARALLEL_TASKS} XIP=OFF CPU_NAME=M55_HE
        if [[ $? -ne 0 ]]; then
            exit 1
        fi
    fi

    #make clean
    #make ${PARALLEL_TASKS} XIP=ON CPU_NAME=M55_HE 

    cd ../../setools
    manifest_copy "${setools_m55_stub_manifest[@]}"
else
    release_print "[INFO] Skipped boot stubs for M55/A32"
fi

#
# The rest of the release manifest 
#
release_print "** [SETOOLS Application Release] copy other items"
manifest_copy "${setools_others_manifest[@]}"


if [[ $BUILD_OPTION == @("B0") ]]
then
    release_print "[INFO] FUSION REV_B0 manifest"
    manifest_copy "${setools_rev_b0_manifest[@]}"
fi

if [[ $HEX_GENERATE == "ON" ]]
then
    release_print "[INFO] copying create_image.py to $release_dir"
    cp create_image.py $release_dir
fi

# update OEMTocPackage.bin
release_print "** [SETOOLS Application Release] generating AppTocPackage.bin (Stubs Use Case)"
cd "$release_dir/"

# BETA REV_A1 Default ATOC package
if [[ $BUILD_OPTION == @("B0") ]]
then
    python3 tools-config.py -p "E7 (AE722F80F55D5AE) - 5.5 MRAM / 13.5 SRAM" -r B0
fi
python3 app-gen-toc.py

# Note: pip install pylink-square (not possible on vncsrv01, but no where else)
# Create HEX MRAM image from build
if [[ $HEX_GENERATE == "OFF" ]]
then
    release_print "[INFO] Skipped HEX file image build"
else
    python3 create_image.py
fi
cd ../

# remove pycache
release_print "** [SETOOLS Application Release] generating AlifTocPackage.bin"
cd "$release_dir/"
rm -r utils/__pycache__
cd ../

#ls -l "$release_dir/utils/lzf-lnx"
#chmod +x "$release_dir/utils/lzf-lnx"   # add executable premission to the utility
#ls -l "$release_dir/utils/lzf-lnx"

executable_create               # EXE builder
#
# Final step create the compressed tar ball 
#
release_print "-n" "** [SETOOLS Application Release] creating release package "
# Tack on the Revision
if [[ $BUILD_OPTION == @("B0") ]]
then
    release_bundle="$release_dir-$current_branch-REV_B0"
else
    release_bundle="$release_dir-$current_branch"
fi
# echo "Bundle: $release_bundle"
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
#    release_tar="$release_dir-$current_branch.tar"
    release_tar="$release_bundle.tar"
    tar -czf $release_tar $release_dir/*
fi

# Complete build time statistics
profile_stop

release_print "*********** [SETOOLS] Application release package complete *************"

# Fin
