#!/bin/bash
# ##############################################################################
# Release builder script
# - creates and builds a release structure from the SE FW git repo into a
#   release archive
#
# - Component Builds include
#   - mram_burner
#   - lauter bach burner
#   - icv-provision
#   - seram-bl 
#   - debug stubs
# 
# @todo
#    use printf() instead of echo
#    firewall.py is not being copied
#    documentation is not copied
# ##############################################################################

# Turn this on to debug ....
#set -x

# Version Trail
# 0.16.2    added PLATFORM_OPTION e.g. FPGA
# 0.16.1    added isp/device_probe.py
# 0.16.0    Using common-utils.sh to reduce duplication
#           added timestamp feature
# 0.15.0    added Multiple DEV Keys support and
#           modified global-cfg.db names from source
# 0.14.0    updating doxygen support
#           removing default build of REV_B0 SIMBOLT
# 0.13.0    Deprecated REV_A0 support
# 0.12.0    Adding REV_B0 dedicated support
# 0.11.0    Add generation of HEX images to builder
# 0.10.0    Just build dont create manifest option
#           adding otp.py to manifest
# 0.9.0     Adding seram_trace.py to release
# 0.8.0     Copy individual MRAM burner files
# 0.7.0     Added B1 (SPARK) Manifest
# 0.6.0     Added REV_A6/A7 support
# 0.5.0     Added SKIP of bootstubs build if not build ALL
# 0.4.0     Added -d option for doxygen generation
VERSION="0.16.2"

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
release_dir=./icv-release
mram_burner_dir=./mram_burner
lb_mram_burner_dir=./lb_mram_burner
icv_prov_dir=./factory-tools/icv-prov
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
  echo "***** [SETOOLS Release] Error - $save_error"
  echo " Running '$BASH_COMMAND' on line ${BASH_LINENO[0]}"
  echo -e "\e[0m"
  exit
fi

if [[ $save_error -eq 0 ]]; then
  echo "***** [SETOOLS Release] Build is ok, Error - $save_error"
fi

  exit
}

# Command line options parser 
display_release_help()
{
    echo "Usage: icv-release builder"
    echo
    echo "Syntax: icv-release [-option]                                   "
    echo "-h  --help      this screen                                     "
    echo "-b  --build     ALL (default A1 B0) | A0 | A1 | A6 | A7 | B0 | SIMBOLT | B1"
    echo "-p  --platform  EVALUATION_BOARD (default) | FPGA               "
    echo "-c  --codespell disable codespell build (default ENABLED)       "
    echo "-r  --release   disable release build (default ENABLED)         "
    echo "-s  --sim       generate simulation images (default DISABLED)   "
    echo "-d  --docs      generate Doxygen pages (default DISABLED)       "
    echo "-t  --tar       output tarball as well as ZIP                   "
    echo "-v  --version   version                                         "
    echo "-bs --boot      disable bootstub build (default ENABLED)        "
    echo "-bu --burn      disable burner build (default ENABLED)          "
    echo "-cl --clean     clean up release directory (default DISABLED)   "
    echo "-pr --prov      disable provision tool build (default ENABLED)  "
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
    echo "BURNER_SUPPRESS_BUILD     $BURNER_SUPPRESS_BUILD"
    echo "PROVISION_SUPPRESS_BUILD  $PROVISION_SUPPRESS_BUILD"
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
            echo "[ERROR] Missing build argument [ALL | A0 | A1 | A6 | A7 | B0 | SIMBOLT | FPGA | B1]"
            exit 1
        fi
        if [[ "$2" != @(ALL|A0|A1|A6|A7|B0|SIMBOLT|FPGA|B1) ]]; then
            echo "[ERROR] invalid build target [ALL | A0 | A1 | A6 | A7 | B0 | SIMBOLT | FPGA |  B1]"
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

release_print "************ [SETOOLS] creating ALIF release package **************"
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
declare -a setools_mramburner_manifest=(
#    "$mram_burner_dir/build/mram_burner_fusion_a0_evaluation_board.axf"        "$release_dir/bin/"
    "$mram_burner_dir/build/mram_burner_fusion_a1_evaluation_board.axf"        "$release_dir/bin/"
#    "$mram_burner_dir/build/mram_burner_fusion_b0_fpga.axf"                    "$release_dir/bin/"
    "$mram_burner_dir/build/mram_burner_fusion_b0_evaluation_board.axf"        "$release_dir/bin/"
)

declare -a setools_mramburner_b0_manifest=(
#    "$mram_burner_dir/build/mram_burner_fusion_b0_fpga.axf"                    "$release_dir/bin/"
    "$mram_burner_dir/build/mram_burner_fusion_b0_evaluation_board.axf"        "$release_dir/bin/"
)

# SPARK B1 REV_A0
declare -a setools_mramburner_b1_manifest=(
    "$mram_burner_dir/build/mram_burner_spark_a0_fpga.axf"                     "$release_dir/bin/"
)

declare -a setools_lbmramburner_manifest=(
    "$lb_mram_burner_dir/build/lb_mram_burner.bin"  "$release_dir/bin/lb_mram_burner.bin"
)

declare -a setools_icvprov_manifest=(
    "$icv_prov_dir/build/icv-prov.bin"              "$release_dir/bin/icv-prov.bin"
    "$icv_prov_dir/icv-factory-prov.ds"             "$release_dir/bin/icv-factory-prov.ds"
)

declare -a setools_seram_manifest=(
#    "$seram_dir/build/seram_fusion_a0_evaluation_board.bin" "$release_dir/build/images/seram_fusion_a0_evaluation_board_0.bin"
#    "$seram_dir/build/seram_fusion_a0_evaluation_board.bin" "$release_dir/build/images/seram_fusion_a0_evaluation_board_1.bin"

    "$seram_dir/build/seram_fusion_a1_evaluation_board.bin" "$release_dir/build/images/seram_fusion_a1_evaluation_board_0.bin"
    "$seram_dir/build/seram_fusion_a1_evaluation_board.bin" "$release_dir/build/images/seram_fusion_a1_evaluation_board_1.bin"

# uncomment for the fateful day we get REV_B0 Evaluation boards...
    "$seram_dir/build/seram_fusion_b0_evaluation_board.bin" "$release_dir/build/images/seram_fusion_b0_evaluation_board_0.bin"
    "$seram_dir/build/seram_fusion_b0_evaluation_board.bin" "$release_dir/build/images/seram_fusion_b0_evaluation_board_1.bin"

#    "$seram_dir/build/seram_fusion_b0_fpga.bin"             "$release_dir/build/images/seram_fusion_b0_fpga_0.bin"
#    "$seram_dir/build/seram_fusion_b0_fpga.bin"             "$release_dir/build/images/seram_fusion_b0_fpga_1.bin"

#    "$setools_dir/utils/icv-global-cfg.db"                  "$release_dir/utils/global-cfg.db"
)

# REV_A0 SERAM images
declare -a setools_seram_rev_a0_manifest=(
   "$seram_dir/build/seram_fusion_a0_evaluation_board.bin" "$release_dir/build/images/seram_fusion_a0_evaluation_board_0.bin"
   "$seram_dir/build/seram_fusion_a0_evaluation_board.bin" "$release_dir/build/images/seram_fusion_a0_evaluation_board_1.bin"
   #"$setools_dir/utils/icv-global-cfg.db"                  "$release_dir/utils/global-cfg.db"
)
# REV_A1 SERAM images
declare -a setools_seram_rev_a1_manifest=(
   "$seram_dir/build/seram_fusion_a1_evaluation_board.bin" "$release_dir/build/images/seram_fusion_a1_evaluation_board_0.bin"
   "$seram_dir/build/seram_fusion_a1_evaluation_board.bin" "$release_dir/build/images/seram_fusion_a1_evaluation_board_1.bin"
#   "$setools_dir/utils/icv-global-cfg.db"                  "$release_dir/utils/global-cfg.db"
)

# REV_B0 SERAM images
declare -a setools_seram_rev_b0_manifest=(
# uncomment for the fateful day we get REV_B0 Evaluation boards...
   "$seram_dir/build/seram_fusion_b0_evaluation_board.bin" "$release_dir/build/images/seram_fusion_b0_evaluation_board_0.bin"
   "$seram_dir/build/seram_fusion_b0_evaluation_board.bin" "$release_dir/build/images/seram_fusion_b0_evaluation_board_1.bin"
#   "$setools_dir/utils/icv-global-cfg-b0.db"               "$release_dir/utils/global-cfg.db"
   "$setools_dir/build/config/device-config-b0.json"       "$release_dir/build/config/device-config.json"
   "$setools_dir/build/config/device-config-app.json"      "$release_dir/build/config/device-config-app.json"
)

# REV_B0 SERAM images SIMBOLT
declare -a setools_seram_simbolt_manifest=(
   "$seram_dir/build/seram_fusion_b0_simbolt.bin"          "$release_dir/build/images/seram_fusion_b0_simbolt_0.bin"
   "$seram_dir/build/seram_fusion_b0_simbolt.bin"          "$release_dir/build/images/seram_fusion_b0_simbolt_1.bin"
   "$setools_dir/build/config/device-config-b0.json"       "$release_dir/build/config/device-config.json"
   "$setools_dir/build/config/device-config-app.json"      "$release_dir/build/config/device-config-app.json"
   "$setools_dir/build/config/E7-B0-simbolt-cfg.json"      "$release_dir/build/config/E7-B0-cfg.json"
)

# REV_B0 SERAM images FPGA
declare -a setools_seram_rev_b0_fpga_manifest=(
   "$seram_dir/build/seram_fusion_b0_fpga.bin"             "$release_dir/build/images/seram_fusion_b0_fpga_0.bin"
   "$seram_dir/build/seram_fusion_b0_fpga.bin"             "$release_dir/build/images/seram_fusion_b0_fpga_1.bin"
   #"$setools_dir/utils/icv-global-cfg-b0.db"               "$release_dir/utils/global-cfg.db"
   "$setools_dir/build/config/device-config-b0.json"       "$release_dir/build/config/device-config.json"
   "$setools_dir/build/config/device-config-app.json"      "$release_dir/build/config/device-config-app.json"
   "$setools_dir/build/config/E7-B0-FPGA-cfg.json"         "$release_dir/build/config/E7-B0-FPGA-cfg.json"
)
# REV_B1 (SPARK) SERAM images
declare -a setools_seram_rev_b1_manifest=(
   "$seram_dir/build/seram_spark_a0_fpga.bin"              "$release_dir/build/images/seram_spark_a0_fpga.bin"
)

# REV_B1 (SPARK) - Only 1 debug stub needed
declare -a setools_m55_b1_stub_manifest=(
    "$bootstubs_dir/m55_stub/build/m55_stub.bin"           "$release_dir/build/images/m55_stub_he.bin"
)

# REV_B1 (SPARK) SERAM images
declare -a setools_seram_rev_b1_manifest=(
   "$seram_dir/build/seram_spark_a0_fpga.bin"              "$release_dir/build/images/seram_spark_a0_fpga.bin"
)

declare -a setools_a32_stub_manifest=(
    "$bootstubs_dir/a32_stub/build/a32_stub_0.bin"     "$release_dir/build/images/a32_stub_0.bin"
#   "$bootstubs_dir/a32_stub/build/a32_stub_0_xip.bin" "$release_dir/build/a32_stub_0_xip.bin"
)

declare -a setools_m55_stub_manifest=(
    "$bootstubs_dir/m55_stub/build/m55_stub.bin"    "$release_dir/build/images/m55_stub_modem.bin"
    "$bootstubs_dir/m55_stub/build/m55_stub.bin"    "$release_dir/build/images/m55_stub_gnss.bin"
    "$bootstubs_dir/m55_stub/build/m55_stub.bin"    "$release_dir/build/images/m55_stub_hp.bin"
    "$bootstubs_dir/m55_stub/build/m55_stub.bin"    "$release_dir/build/images/m55_stub_he.bin"
)

# Common Manifest for all devices
declare -a setools_common_manifest=(
    "$setools_dir/gen-toc.py"                       "$release_dir/"
    "$setools_dir/cert-check.py"                    "$release_dir/"
#   "$setools_dir/icv-provision.py"                 "$release_dir/"
    "$setools_dir/write-image.py"                   "$release_dir/"
    "$setools_dir/icv-recovery.py"                  "$release_dir/"
    "$setools_dir/alif-image-check.py"              "$release_dir/"
    "$setools_dir/tools-config.py"                  "$release_dir/"
    "$setools_dir/maintenance.py"                   "$release_dir/"
    "$setools_dir/sign_image.py"                    "$release_dir/"
    "$setools_dir/generate-packages.py"             "$release_dir/"

    "$setools_dir/build/config/E7-A1-cfg.json"      "$release_dir/build/config"
    "$setools_dir/build/config/E7-B0-cfg.json"      "$release_dir/build/config"
    "$setools_dir/build/config/B1-A0-cfg.json"      "$release_dir/build/config"

# Deprectaed devices
#"$setools_dir/build/config/E7-A0-cfg.json"      "$release_dir/build/config"
#"$setools_dir/build/config/C7-A0-cfg.json"      "$release_dir/build/config"
#"$setools_dir/build/config/C7-A1-cfg.json"      "$release_dir/build/config"

    "$setools_dir/build/config/device-config.json"     "$release_dir/build/config"
    "$setools_dir/build/config/device-config-b0.json"  "$release_dir/build/config"
    "$setools_dir/build/config/device-config-app.json" "$release_dir/build/config"

    "$setools_dir/build/images/zeros.bin"           "$release_dir/build/images"
    "$setools_dir/bin/zero.bin"                     "$release_dir/bin"
#   "$setools_dir/build/E7_fw_cfg.bin"              "$release_dir/build"
#   "$setools_dir/build/C7_fw_cfg.bin"              "$release_dir/build"
#   "$setools_dir/build/fw_cfg_no_mram_prot.bin"    "$release_dir/build"

    "$setools_dir/bin/icv-prov-dummy.bin"           "$release_dir/bin/icv-prov-dummy.bin"

    "$setools_dir/lib/icons/Check_32x32.png"        "$release_dir/lib/icons"
    "$setools_dir/lib/icons/Delete_32x32.png"       "$release_dir/lib/icons"
    "$setools_dir/lib/icons/Logo.PNG"               "$release_dir/lib/icons"

    #"$setools_dir/cert/ICVSBKey1.crt"               "$release_dir/cert"
    #"$setools_dir/cert/ICVSBKey2.crt"               "$release_dir/cert"
    "$setools_dir/src/alif-image-check.ui"          "$release_dir/src"
    "$setools_dir/src/cert_check.ui"                "$release_dir/src"

    "$setools_dir/isp/otp_mfgr_decode.py"           "$release_dir/isp"
    "$setools_dir/isp/version_decode.py"            "$release_dir/isp"
    "$setools_dir/isp/serom_errors.py"              "$release_dir/isp"
    "$setools_dir/isp/trace_decode.py"              "$release_dir/isp"
    "$setools_dir/isp/power_decode.py"              "$release_dir/isp"
    "$setools_dir/isp/isp_protocol.py"              "$release_dir/isp"
    "$setools_dir/isp/serialport.py"                "$release_dir/isp"
    "$setools_dir/isp/toc_decode.py"                "$release_dir/isp"
    "$setools_dir/isp/isp_print.py"                 "$release_dir/isp"
    "$setools_dir/isp/isp_util.py"                  "$release_dir/isp"
    "$setools_dir/isp/isp_core.py"                  "$release_dir/isp"
    "$setools_dir/isp/recovery.py"                  "$release_dir/isp"
    "$setools_dir/isp/otp.py"                       "$release_dir/isp"
    "$setools_dir/isp/device_probe.py"              "$release_dir/isp"

    "$setools_dir/utils/cmpu_asset_pkg_util.py"     "$release_dir/utils"
    "$setools_dir/utils/hbk_gen_util.py"            "$release_dir/utils"
    "$setools_dir/utils/rsa_keygen.py"              "$release_dir/utils"
    "$setools_dir/utils/cert_key_util.py"           "$release_dir/utils"
    "$setools_dir/utils/discover.py"                "$release_dir/utils"
    "$setools_dir/utils/user_validations.py"        "$release_dir/utils"
    "$setools_dir/utils/toc_common.py"              "$release_dir/utils"
    "$setools_dir/utils/device_config.py"           "$release_dir/utils"
    "$setools_dir/utils/config.py"                  "$release_dir/utils"
    "$setools_dir/utils/firewall.py"                "$release_dir/utils"
    "$setools_dir/utils/pinmux.py"                  "$release_dir/utils"
    "$setools_dir/utils/clocks.py"                  "$release_dir/utils"
    "$setools_dir/utils/icv-devicesDB.db"           "$release_dir/utils/devicesDB.db"
    "$setools_dir/utils/icv-familiesDB.db"          "$release_dir/utils/familiesDB.db"
    "$setools_dir/utils/icv-featuresDB.db"          "$release_dir/utils/featuresDB.db"
    "$setools_dir/utils/maintDB.db"                 "$release_dir/utils"
    "$setools_dir/utils/menuconfDB.db"              "$release_dir/utils"
    "$setools_dir/utils/icv-jtag-adapters.db"       "$release_dir/utils/jtag-adapters.db"
    "$setools_dir/utils/proj.cfg"                   "$release_dir/utils"
    "$setools_dir/utils/lzf-lnx"                    "$release_dir/utils"
    "$setools_dir/utils/lzf.exe"                    "$release_dir/utils"
    "$setools_dir/utils/cert_sb_content_util.py"    "$release_dir/utils"
    "$setools_dir/utils/common/certificates.py"     "$release_dir/utils/common"
    "$setools_dir/utils/common/cryptolayer.py"      "$release_dir/utils/common"
    "$setools_dir/utils/common/exceptions.py"       "$release_dir/utils/common"
    "$setools_dir/utils/common/flags_global_defines.py" "$release_dir/utils/common"
    "$setools_dir/utils/common/global_defines.py"   "$release_dir/utils/common"
    "$setools_dir/utils/common/util_logger.py"      "$release_dir/utils/common"
    "$setools_dir/utils/cfg/asset_icv_ce.cfg"       "$release_dir/utils/cfg"
    "$setools_dir/utils/cfg/asset_icv_cp.cfg"       "$release_dir/utils/cfg"
    "$setools_dir/utils/cfg/ICVSBKey1.cfg"          "$release_dir/utils/cfg"
    "$setools_dir/utils/cfg/ICVSBKey2.cfg"          "$release_dir/utils/cfg"
    "$setools_dir/utils/cfg/ICVSBContent_lvs_0.cfg" "$release_dir/utils/cfg"
    "$setools_dir/utils/cfg/ICVSBContent_lvs_1.cfg" "$release_dir/utils/cfg"
    "$setools_dir/utils/cfg/ICVSBContent_lvs_2.cfg" "$release_dir/utils/cfg"

    # * * * * * SUPPORT FOR MULTIPLE DEV KEYS * * * * * 
    # copy rev_a1 DEV keys
    "$setools_dir/utils/key/fusion_rev_a1/ICVSBContent.pem"       "$release_dir/utils/key/fusion_rev_a1/"
    "$setools_dir/utils/key/fusion_rev_a1/ICVSBContentPublic.pem" "$release_dir/utils/key/fusion_rev_a1/"
    "$setools_dir/utils/key/fusion_rev_a1/kceicv.txt"             "$release_dir/utils/key/fusion_rev_a1/"
    "$setools_dir/utils/key/fusion_rev_a1/icv_keys_pass.pwd"      "$release_dir/utils/key/fusion_rev_a1/"
    #"$setools_dir/utils/key/fusion_rev_a1/icv-assets.bin"         "$release_dir/utils/key/fusion_rev_a1/"
    "$setools_dir/utils/key/fusion_rev_a1/key_rev_a1.txt"         "$release_dir/utils/key/fusion_rev_a1/"

    # copy rev_b0 DEV keys
    "$setools_dir/utils/key/fusion_rev_b0/ICVSBContent.pem"       "$release_dir/utils/key/fusion_rev_b0/"
    "$setools_dir/utils/key/fusion_rev_b0/ICVSBContentPublic.pem" "$release_dir/utils/key/fusion_rev_b0/"
    "$setools_dir/utils/key/fusion_rev_b0/kceicv.txt"             "$release_dir/utils/key/fusion_rev_b0/"
    "$setools_dir/utils/key/fusion_rev_b0/icv_keys_pass.pwd"      "$release_dir/utils/key/fusion_rev_b0/"
    #"$setools_dir/utils/key/fusion_rev_b0/icv-assets.bin"         "$release_dir/utils/key/fusion_rev_b0/"
    "$setools_dir/utils/key/fusion_rev_b0/key_rev_b0.txt"         "$release_dir/utils/key/fusion_rev_b0/"

    # copy rev_a1 DEV keys as Default ones
    "$setools_dir/utils/key/fusion_rev_a1/ICVSBContent.pem"       "$release_dir/utils/key/"
    "$setools_dir/utils/key/fusion_rev_a1/ICVSBContentPublic.pem" "$release_dir/utils/key/"
    "$setools_dir/utils/key/fusion_rev_a1/kceicv.txt"             "$release_dir/utils/key/"
    "$setools_dir/utils/key/fusion_rev_a1/icv_keys_pass.pwd"      "$release_dir/utils/key/"
    #"$setools_dir/utils/key/fusion_rev_a1/icv-assets.bin"         "$release_dir/utils/key/"
    "$setools_dir/utils/key/fusion_rev_a1/key_rev_a1.txt"         "$release_dir/utils/key/"

    # copy fusion_rev_a1 DEV certs
    "$setools_dir/cert/fusion_rev_a1/ICVSBKey1.crt"               "$release_dir/cert/fusion_rev_a1/"
    "$setools_dir/cert/fusion_rev_a1/ICVSBKey2.crt"               "$release_dir/cert/fusion_rev_a1/"
    "$setools_dir/cert/fusion_rev_a1/cert_rev_a1.txt"             "$release_dir/cert/fusion_rev_a1/"    

    # copy fusion_rev_b0 DEV certs
    "$setools_dir/cert/fusion_rev_b0/ICVSBKey1.crt"               "$release_dir/cert/fusion_rev_b0/"
    "$setools_dir/cert/fusion_rev_b0/ICVSBKey2.crt"               "$release_dir/cert/fusion_rev_b0/"
    "$setools_dir/cert/fusion_rev_b0/cert_rev_b0.txt"             "$release_dir/cert/fusion_rev_b0/"

    # copy fusion_rev_a1 DEV certs as Default ones
    "$setools_dir/cert/fusion_rev_a1/ICVSBKey1.crt"               "$release_dir/cert/"
    "$setools_dir/cert/fusion_rev_a1/ICVSBKey2.crt"               "$release_dir/cert/"
    "$setools_dir/cert/fusion_rev_a1/cert_rev_a1.txt"             "$release_dir/cert/"

    # we should have only one global config with the default part
    # before generating the package, we can use tools-config.py with options to change the defaults
    "$setools_dir/utils/icv-global-cfg.db"                         "$release_dir/utils/global-cfg.db"

    "$setools_dir/utils/common_cert_lib/contentcertificateconfig.py"    "$release_dir/utils/common_cert_lib"
    "$setools_dir/utils/common_cert_lib/developercertificateconfig.py"  "$release_dir/utils/common_cert_lib"
    "$setools_dir/utils/common_cert_lib/enablercertificateconfig.py"    "$release_dir/utils/common_cert_lib"
    "$setools_dir/utils/common_cert_lib/keycertificateconfig.py"        "$release_dir/utils/common_cert_lib"
    "$setools_dir/utils/common_cert_lib/x509certificateconfig.py"       "$release_dir/utils/common_cert_lib"

    "$setools_dir/system-se-sw-setools-user-manual-v*.pdf"              "$release_dir/"
    "$setools_dir/se-sw-release-v*.pdf"                                 "$release_dir/"

    "$setools_dir/utils/gen_fw_cfg.py"              "$release_dir/utils"
    "$setools_dir/firewall/fw_cfg_rev_a.json"       "$release_dir/firewall"
    "$setools_dir/firewall/fw_cfg_rev_b.json"       "$release_dir/firewall"
    "$setools_dir/firewall/mram.json"               "$release_dir/firewall"
    "$setools_dir/firewall/sram.json"               "$release_dir/firewall"
)

# Balletto REV_A0 (SPARK) Specific manifest 
declare -a setools_spark_common_manifest=(
    "$setools_dir/gen-toc.py"                       "$release_dir/"
    "$setools_dir/cert-check.py"                    "$release_dir/"
#   "$setools_dir/icv-provision.py"                 "$release_dir/"
    "$setools_dir/write-image.py"                   "$release_dir/"
    "$setools_dir/icv-recovery.py"                  "$release_dir/"
    "$setools_dir/alif-image-check.py"              "$release_dir/"
    "$setools_dir/tools-config.py"                  "$release_dir/"
    "$setools_dir/maintenance.py"                   "$release_dir/"
    "$setools_dir/sign_image.py"                    "$release_dir/"

    "$setools_dir/build/config/B1-A0-cfg.json"      "$release_dir/build/config"

    "$setools_dir/build/config/device-config.json"     "$release_dir/build/config"
    "$setools_dir/build/config/device-config-b0.json"  "$release_dir/build/config"
    "$setools_dir/build/config/device-config-app.json" "$release_dir/build/config"

    "$setools_dir/build/images/zeros.bin"           "$release_dir/build/images"
    "$setools_dir/bin/zero.bin"                     "$release_dir/bin"

    "$setools_dir/bin/icv-prov-dummy.bin"           "$release_dir/bin/icv-prov-dummy.bin"

    "$setools_dir/lib/icons/Check_32x32.png"        "$release_dir/lib/icons"
    "$setools_dir/lib/icons/Delete_32x32.png"       "$release_dir/lib/icons"
    "$setools_dir/lib/icons/Logo.PNG"               "$release_dir/lib/icons"

    "$setools_dir/cert/ICVSBKey1.crt"               "$release_dir/cert"
    "$setools_dir/cert/ICVSBKey2.crt"               "$release_dir/cert"
    "$setools_dir/src/alif-image-check.ui"          "$release_dir/src"
    "$setools_dir/src/cert_check.ui"                "$release_dir/src"

    "$setools_dir/isp/otp_mfgr_decode.py"           "$release_dir/isp"
    "$setools_dir/isp/version_decode.py"            "$release_dir/isp"
    "$setools_dir/isp/serom_errors.py"              "$release_dir/isp"
    "$setools_dir/isp/trace_decode.py"              "$release_dir/isp"
    "$setools_dir/isp/power_decode.py"              "$release_dir/isp"
    "$setools_dir/isp/isp_protocol.py"              "$release_dir/isp"
    "$setools_dir/isp/serialport.py"                "$release_dir/isp"
    "$setools_dir/isp/toc_decode.py"                "$release_dir/isp"
    "$setools_dir/isp/isp_print.py"                 "$release_dir/isp"
    "$setools_dir/isp/isp_util.py"                  "$release_dir/isp"
    "$setools_dir/isp/isp_core.py"                  "$release_dir/isp"
    "$setools_dir/isp/recovery.py"                  "$release_dir/isp"
    "$setools_dir/isp/otp.py"                       "$release_dir/isp"

    "$setools_dir/utils/cmpu_asset_pkg_util.py"     "$release_dir/utils"
    "$setools_dir/utils/hbk_gen_util.py"            "$release_dir/utils"
    "$setools_dir/utils/rsa_keygen.py"              "$release_dir/utils"
    "$setools_dir/utils/cert_key_util.py"           "$release_dir/utils"
    "$setools_dir/utils/discover.py"                "$release_dir/utils"
    "$setools_dir/utils/user_validations.py"        "$release_dir/utils"
    "$setools_dir/utils/toc_common.py"              "$release_dir/utils"
    "$setools_dir/utils/device_config.py"           "$release_dir/utils"
    "$setools_dir/utils/config.py"                  "$release_dir/utils"
    "$setools_dir/utils/firewall.py"                "$release_dir/utils"
    "$setools_dir/utils/pinmux.py"                  "$release_dir/utils"
    "$setools_dir/utils/clocks.py"                  "$release_dir/utils"
    "$setools_dir/utils/icv-devicesDB.db"           "$release_dir/utils/devicesDB.db"
    "$setools_dir/utils/icv-familiesDB.db"          "$release_dir/utils/familiesDB.db"
    "$setools_dir/utils/icv-featuresDB.db"          "$release_dir/utils/featuresDB.db"
    "$setools_dir/utils/icv-global-cfg.db"          "$release_dir/utils/global-cfg.db"
    "$setools_dir/utils/maintDB.db"                 "$release_dir/utils"  
    "$setools_dir/utils/menuconfDB.db"              "$release_dir/utils"  
    "$setools_dir/utils/icv-jtag-adapters.db"       "$release_dir/utils/jtag-adapters.db"
    "$setools_dir/utils/proj.cfg"                   "$release_dir/utils"
    "$setools_dir/utils/lzf-lnx"                    "$release_dir/utils"
    "$setools_dir/utils/lzf.exe"                    "$release_dir/utils"
    "$setools_dir/utils/cert_sb_content_util.py"    "$release_dir/utils"
    "$setools_dir/utils/common/certificates.py"     "$release_dir/utils/common"
    "$setools_dir/utils/common/cryptolayer.py"      "$release_dir/utils/common"
    "$setools_dir/utils/common/exceptions.py"       "$release_dir/utils/common"
    "$setools_dir/utils/common/flags_global_defines.py" "$release_dir/utils/common"
    "$setools_dir/utils/common/global_defines.py"   "$release_dir/utils/common"
    "$setools_dir/utils/common/util_logger.py"      "$release_dir/utils/common"
    "$setools_dir/utils/cfg/asset_icv_ce.cfg"       "$release_dir/utils/cfg"
    "$setools_dir/utils/cfg/asset_icv_cp.cfg"       "$release_dir/utils/cfg"
    "$setools_dir/utils/cfg/ICVSBKey1.cfg"          "$release_dir/utils/cfg"
    "$setools_dir/utils/cfg/ICVSBKey2.cfg"          "$release_dir/utils/cfg"
    "$setools_dir/utils/cfg/ICVSBContent_lvs_0.cfg" "$release_dir/utils/cfg"
    "$setools_dir/utils/cfg/ICVSBContent_lvs_1.cfg" "$release_dir/utils/cfg"
    "$setools_dir/utils/cfg/ICVSBContent_lvs_2.cfg" "$release_dir/utils/cfg"
    "$setools_dir/utils/key/ICVSBContent.pem"       "$release_dir/utils/key"
    "$setools_dir/utils/key/ICVSBContentPublic.pem" "$release_dir/utils/key"
    "$setools_dir/utils/key/kceicv.txt"             "$release_dir/utils/key"
    "$setools_dir/utils/key/icv_keys_pass.pwd"      "$release_dir/utils/key"
    "$setools_dir/utils/key/icv-assets.bin"         "$release_dir/utils/key"
    "$setools_dir/utils/common_cert_lib/contentcertificateconfig.py"    "$release_dir/utils/common_cert_lib"
    "$setools_dir/utils/common_cert_lib/developercertificateconfig.py"  "$release_dir/utils/common_cert_lib"
    "$setools_dir/utils/common_cert_lib/enablercertificateconfig.py"    "$release_dir/utils/common_cert_lib"
    "$setools_dir/utils/common_cert_lib/keycertificateconfig.py"        "$release_dir/utils/common_cert_lib"
    "$setools_dir/utils/common_cert_lib/x509certificateconfig.py"       "$release_dir/utils/common_cert_lib"

    "$setools_dir/system-se-sw-setools-user-manual-v*.pdf"              "$release_dir/"
    "$setools_dir/se-sw-release-v*.pdf"                                 "$release_dir/"

    "$setools_dir/utils/gen_fw_cfg.py"              "$release_dir/utils"
    "$setools_dir/firewall/fw_cfg_rev_a.json"       "$release_dir/firewall"
    "$setools_dir/firewall/fw_cfg_rev_b.json"       "$release_dir/firewall"
    "$setools_dir/firewall/mram.json"               "$release_dir/firewall"
    "$setools_dir/firewall/sram.json"               "$release_dir/firewall"
)
# Release directory manifest
# each entry here will be created
declare -a setools_release_dir_manifest=(
    "$release_dir/build"
    "$release_dir/build/logs"
    "$release_dir/build/config"
    "$release_dir/build/images"
    "$release_dir/cert"
    "$release_dir/cert/fusion_rev_a1"
    "$release_dir/cert/fusion_rev_b0"   
    "$release_dir/bin"
    "$release_dir/src"
    "$release_dir/lib"
    "$release_dir/lib/icons"
    "$release_dir/isp"
    "$release_dir/utils"
    "$release_dir/utils/cfg"
    "$release_dir/utils/key"
    "$release_dir/utils/key/fusion_rev_a1"
    "$release_dir/utils/key/fusion_rev_b0"
    "$release_dir/utils/common"
    "$release_dir/utils/common_cert_lib"
	"$release_dir/firewall"
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
            rm -rf app-release-exec/
            python3 build-app-executables.py
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
            rm -rf app-release-exec-linux/
            rm -rf venv/
            python3 build-app-executables-linux.py
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

        rm -rf app-release-exec-linux/
        rm -rf app-release-exec/
        rm -rf icv-release/
        rm -rf app-release/
        rm -rf se-host-service-release/ 
        rm -rf venv/
        rm -rf *.zip
        rm -rf *.tar
    else 
        release_print "[INFO] Skipped CLEAN build"
    fi
}

# Generate MRAM Burners
function generate_mram_burners()
{
    # MRAM burner build manifest
    if [[ $BURNER_SUPPRESS_BUILD == @("OFF") ]]
    then
        release_print "** [SETOOLS Release] build write_image"
        cd mram_burner

        # Start nice and clean
        make realclean

        #    builder_make REV_A EVALUATION_BOARD
#        if [[ $BUILD_OPTION == @("ALL"|"A0") ]]
        if [[ $BUILD_OPTION == @("A0") ]]
        then
            release_print "** [SETOOLS Release] build mram_burner for REV_A EVALUATION BOARD"
            make clean
            make ${PARALLEL_TASKS} DEVICE_REVISION=REV_A PLATFORM_TYPE=EVALUATION_BOARD
            if [ $? -ne 0 ]
            then
                exit 1
            fi
        else
            release_print "[INFO] Skipped REV_A  MRAM burner"
        fi

        #    builder_make REV_A1 EVALUATION_BOARD
        if [[ $BUILD_OPTION == @("ALL"|"A1") ]]
        then
            release_print "** [SETOOLS Release] build mram_burner for REV_A1 EVALUATION BOARD"
            make clean
            make ${PARALLEL_TASKS} DEVICE_REVISION=REV_A1 PLATFORM_TYPE=EVALUATION_BOARD
            if [[ $? -ne 0 ]]; then
                exit 1
            fi
        else
            release_print "[INFO] Skipped REV_A1 MRAM burner"
        fi

        #    builder_make REV_B0 EVALUATION_BOARD
        if [[ $BUILD_OPTION == @("ALL"|"B0") ]]
        then
            release_print "** [SETOOLS Release] build mram_burner for REV_B0 EVALUATION_BOARD"
            make clean
            make ${PARALLEL_TASKS} DEVICE_REVISION=REV_B0 PLATFORM_TYPE=EVALUATION_BOARD
            if [[ $? -ne 0 ]]; then
                exit 1
            fi
        else
            release_print "[INFO] Skipped REV_B0 MRAM burner"
        fi

        #    builder_make SPARK REV_A0 FPGA
        if [[ $BUILD_OPTION == @("B1") ]]
        then
            release_print "** [SETOOLS Release] build mram_burner for SPARK REV_A0 FPGA"
            make clean
            make ${PARALLEL_TASKS} DEVICE_TYPE=SPARK PLATFORM_TYPE=FPGA
            if [[ $? -ne 0 ]]; then
                exit 1
            fi
        else
            release_print "[INFO] Skipped SPARK REV_A0 MRAM burner"
        fi

        cd ..

        if [[ $BUILD_OPTION == @("B0") ]]
        then
            manifest_copy "${setools_mramburner_b0_manifest[@]}"
        else
            manifest_copy "${setools_mramburner_manifest[@]}"
        fi
    else
        release_print "[INFO] Skipped MRAM burner build"
    fi
}

# generate LB MRAM Burner
function generate_mram_burner_lb
{
    # LB MRAM burner manifest
    if [[ $BUILD_OPTION == @("ALL") && $BURNER_SUPPRESS_BUILD == @("OFF") ]]
    then
        release_print "** [SETOOLS Release] build lb_mram_burner"
        cd lb_mram_burner

        make clean
        make ${PARALLEL_TASKS} -i
        if [[ $? -ne 0 ]]; then
            exit 1
        fi

        cd ..
        manifest_copy "${setools_lbmramburner_manifest[@]}"
    else
        release_print "[INFO] Skipped LB MRAM burner build"
    fi
}

function generate_provision_tools()
{
    # icv-provision manifest
    if [[ $BUILD_OPTION == @("ALL") && $PROVISION_SUPPRESS_BUILD == @("OFF") ]]
    then
        release_print "** [SETOOLS Release] build icv provision"
        cd factory-tools/icv-prov

        make clean
        make ${PARALLEL_TASKS} -i
        if [[ $? -ne 0 ]]; then
            exit 1
        fi

        cd ../..
        manifest_copy "${setools_icvprov_manifest[@]}"
    else
        release_print "[INFO] Skipped ICV Provision build"
    fi
}

function generate_bootstubs_a32()
{
    # bootstubs manifest A32
    #if [[ $BUILD_OPTION == @("ALL") && $BOOTSTUB_SUPPRESS_BUILD == @("OFF") ]]
    if [[ $BOOTSTUB_SUPPRESS_BUILD == @("OFF") && $BUILD_OPTION != @("B1") ]]
    then
        release_print "** [SETOOLS Release] build bootstubs"
        cd ../bootstubs/a32_stub

        make clean
        make ${PARALLEL_TASKS} A32_CORE=0
        if [[ $? -ne 0 ]]
        then
            exit 1
        fi
        cd ../../setools
        manifest_copy "${setools_a32_stub_manifest[@]}"
    else
        release_print "[INFO] Skipped boot stubs for A32"
    fi
}

function generate_bootstubs_m55()
{
    # bootstubs manifest M55
    #if [[ $BUILD_OPTION == @("ALL") && $BOOTSTUB_SUPPRESS_BUILD == @("OFF") ]]
    if [[ $BOOTSTUB_SUPPRESS_BUILD == @("OFF") ]]
    then
        release_print "** [SETOOLS Release] build modem bootstub"

        cd ../bootstubs/m55_stub

        make clean
        make ${PARALLEL_TASKS}
        if [[ $? -ne 0 ]]
        then
            exit 1
        fi

        cd ../../setools
    
        # Debug stubs is reduced for B1 (SPARK) device
        if [[ $BUILD_OPTION == @("B1") ]]
        then
            manifest_copy "${setools_m55_b1_stub_manifest[@]}"
        else
            manifest_copy "${setools_m55_stub_manifest[@]}"
        fi
    else
        release_print "[INFO] Skipped boot stubs for M55"
    fi
}

function generate_seram()
{
    # seram-bl manifest for different builds (REVs and Platforms)
    cd ../seram-bl

    spell_check

    # B1 Target - experimental
    # @note: You have to target B1, it is not part of 'ALL' (yet)
    if [[ $BUILD_OPTION == @("B1") && $DEBUG_SUPPRESS_BUILD == @("OFF") ]]
    then
        release_print "** [SETOOLS Release] seram-bl Build for SPARK, FPGA, Release $RELEASE_BUILD_PARAM"
        make clean
        make ${PARALLEL_TASKS} DEVICE_TYPE=SPARK PLATFORM_TYPE=FPGA RELEASE_BUILD=$RELEASE_BUILD_PARAM
        if [[ $? -ne 0 ]]
        then
            exit 1
        fi
    else
        release_print "[INFO] Skipped SERAM build for SPARK"
    fi

    # A6 Target - experimental
    if [[ $BUILD_OPTION == @("A6") && $DEBUG_SUPPRESS_BUILD == @("OFF") ]]
    then
        release_print "** [SETOOLS Release] seram-bl Build for REV_A6, Release $RELEASE_BUILD_PARAM"
        make clean
        make ${PARALLEL_TASKS} DEVICE_TYPE=FUSION DEVICE_REVISION=REV_A1 PLL_REVISION=REV_A6 PLATFORM_TYPE=EVALUATION_BOARD RELEASE_BUILD=$RELEASE_BUILD_PARAM
        if [[ $? -ne 0 ]]
        then
            exit 1
        fi
    else
        release_print "[INFO] Skipped SERAM build for REV_A6"
    fi

    # A7 Target - experimental
    if [[ $BUILD_OPTION == @("A7") && $DEBUG_SUPPRESS_BUILD == @("OFF") ]]
    then
        release_print "** [SETOOLS Release] seram-bl Build for REV_A7, Release $RELEASE_BUILD_PARAM"
        make clean
        make ${PARALLEL_TASKS} DEVICE_TYPE=FUSION DEVICE_REVISION=REV_A1 PLL_REVISION=REV_A7 PLATFORM_TYPE=EVALUATION_BOARD RELEASE_BUILD=$RELEASE_BUILD_PARAM
        if [[ $? -ne 0 ]]
        then
            exit 1
        fi
    else
        release_print "[INFO] Skipped SERAM build for REV_A7"
    fi

    if [[ $BUILD_OPTION == @("A0") && $DEBUG_SUPPRESS_BUILD == @("OFF") ]]
    then
        release_print "** [SETOOLS Release] seram-bl Build for REV_A0, Release $RELEASE_BUILD_PARAM"
        make clean
        make ${PARALLEL_TASKS} DEVICE_TYPE=FUSION DEVICE_REVISION=REV_A PLATFORM_TYPE=EVALUATION_BOARD RELEASE_BUILD=$RELEASE_BUILD_PARAM
        if [[ $? -ne 0 ]]
        then
            exit 1
        fi
    else
        release_print "[INFO] Skipped SERAM build for REV_A0"
    fi

    # seram-bl manifest for different builds (REVs and Platforms)
    if [[ $BUILD_OPTION == @("ALL"|"B0") && $DEBUG_SUPPRESS_BUILD == @("OFF") ]]
    then
        release_print "** [SETOOLS Release] seram-bl Build for REV_B0, $PLATFORM_OPTION, Release $RELEASE_BUILD_PARAM"
        make clean
        make ${PARALLEL_TASKS} DEVICE_TYPE=FUSION DEVICE_REVISION=REV_B0 PLATFORM_TYPE=$PLATFORM_OPTION RELEASE_BUILD=$RELEASE_BUILD_PARAM
        if [[ $? -ne 0 ]]
        then
            exit 1
        fi
    else
        release_print "[INFO] Skipped SERAM build for REV_B0"
    fi

    # REV_B0 SIMULATION target
    if [[ $BUILD_OPTION == @("SIMBOLT") && $DEBUG_SUPPRESS_BUILD == @("OFF") ]]
    then
        release_print "** [SETOOLS Release] seram-bl Build for REV_B0, SIMULATION_BOLT, Release $RELEASE_BUILD_PARAM"
        make clean
        make ${PARALLEL_TASKS} DEVICE_TYPE=FUSION DEVICE_REVISION=REV_B0 PLATFORM_TYPE=SIMULATION_BOLT RELEASE_BUILD=$RELEASE_BUILD_PARAM
        if [[ $? -ne 0 ]]
        then
            exit 1
        fi
    fi

    # REV_B0 FPGA target
    if [[ $BUILD_OPTION == @("FPGA") && $DEBUG_SUPPRESS_BUILD == @("OFF") ]]
    then
        release_print "** [SETOOLS Release] seram-bl Build for REV_B0, FPGA, Release $RELEASE_BUILD_PARAM"
        make clean
        make ${PARALLEL_TASKS} DEVICE_TYPE=FUSION DEVICE_REVISION=REV_B0 PLATFORM_TYPE=FPGA RELEASE_BUILD=$RELEASE_BUILD_PARAM
        if [[ $? -ne 0 ]]
        then
            exit 1
        fi
    fi

    if [[ $BUILD_OPTION == @("ALL"|"A1") && $DEBUG_SUPPRESS_BUILD == @("OFF") ]]
    then
       release_print "** [SETOOLS Release] seram-bl Build for REV_A1, $PLATFORM_OPTION, Release $RELEASE_BUILD_PARAM"
       if [[ $PLATFORM_OPTION != "FPGA" ]]
       then
            make clean
            make ${PARALLEL_TASKS} DEVICE_TYPE=FUSION DEVICE_REVISION=REV_A1 PLATFORM_TYPE=$PLATFORM_OPTION RELEASE_BUILD=$RELEASE_BUILD_PARAM
            if [[ $? -ne 0 ]]
            then
                exit 1
            fi
        else
            release_print "[INFO] Skipped SERAM build for REV_A1, No FPGA build"
        fi
    else
        release_print "[INFO] Skipped SERAM build for REV_A1"
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

    if [[ $BUILD_OPTION == @("A0") ]]
    then
        manifest_copy "${setools_seram_rev_a0_manifest[@]}"
    fi

    if [[ $BUILD_OPTION == @("A1"|"A6"|"A7") ]]
    then
        manifest_copy "${setools_seram_rev_a1_manifest[@]}"
    fi

    #
    # The rest of the release manifest 
    #
    release_print "** [SETOOLS Release] copy common items"
    if [[ $BUILD_OPTION == @("B1") ]]
    then
        manifest_copy "${setools_spark_common_manifest[@]}"
    else
        manifest_copy "${setools_common_manifest[@]}"
    fi

    if [[ $BUILD_OPTION == @("B0") ]]
    then
        release_print "** [SETOOLS Release] copy B0 items"
        if [[ $PLATFORM_OPTION == @("FPGA") ]]
        then
            release_print "** [SETOOLS Release] copy FPGA B0 items"
            manifest_copy "${setools_seram_rev_b0_fpga_manifest[@]}"
        fi
        if [[ $PLATFORM_OPTION == @("EVALUATION_BOARD") ]]
        then
            release_print "** [SETOOLS Release] copy EVALUATION BOARD B0 items"
            manifest_copy "${setools_seram_rev_b0_manifest[@]}"
        fi
    fi

    if [[ $BUILD_OPTION == @("SIMBOLT") ]]
    then
        release_print "** [SETOOLS Release] copy SIMBOLT items"
        manifest_copy "${setools_seram_simbolt_manifest[@]}"
    fi

    if [[ $BUILD_OPTION == @("FPGA") ]]
    then
        release_print "** [SETOOLS Release] copy FPGA items"
        manifest_copy "${setools_seram_fpga_manifest[@]}"
    fi

    if [[ $BUILD_OPTION == @("B1") ]]
    then
        manifest_copy "${setools_seram_rev_b1_manifest[@]}"
    fi

#    cd ../
}

# ALIF Package generation
function generate_package()
{
    release_print "[INFO] ALIF Package build (gen-toc)"

    if [[ $BUILD_OPTION == @("B0"|"SIMBOLT") ]]
    then
        release_print "[INFO] gen-toc E7-B0 $PLATFORM_TYPE"
        if [[ $PLATFORM_OPTION == @("FPGA") ]]
        then
            python3 tools-config.py -r B0
            python3 gen-toc.py -f build/config/E7-B0-FPGA-cfg.json
        else
            python3 tools-config.py -r B0
            python3 gen-toc.py -f build/config/E7-B0-cfg.json
        fi
    elif [[ $BUILD_OPTION == @("B1") ]]
    then
        release_print "[INFO] gen-toc B1-A0"
        python3 tools-config.py -p "B1 (AB101F4M51920WH) - 1.8 MRAM / 2.0 SRAM" -r A0
        python3 gen-toc.py -f build/config/B1-A0-cfg.json
    else
        release_print "[INFO] gen-toc <default> cfg"
        # no need to run tools-config as for now Rev A1 is the default
        # (key env is copied from fusion_rev_a1 content)
        python3 generate-packages.py # generates for A1 and B0 currently
        #python3 gen-toc.py
    fi

    # Note: pip install pylink-square (not possible on vncsrv01, but no where else)
    # Create HEX MRAM image from build
    if [[ $HEX_GENERATE == "OFF" ]]
    then
        release_print "[INFO] Skipped HEX file image build"
    else
        python3 write-image.py -m FILE
    fi
}

# ##############################################################################
# Start of the Release builder Execution Path
# STEPS: 
# 1     Check the directory existence
# 2     Generate DOXYGEN release
# 3     MRAM Burners - ULINK
# 4     MRAM Burners - LB
# 5     BOOTSTUBS - A32
# 6     BOOTSTUBS - M55
# 7     SERAM Source builds
# 8     SERAM Manifest Copy
# 9     Generate Package 
# 10    Create TAR / ZIP bundle
# ##############################################################################

profile_start                       # Take the start Time here

clean_build                         # Clean Build

# Sanity check the release directory to start with
release_print "-n" "[SETOOLS Release] release directory: " $release_dir
if [ -d "$release_dir" ] 
then
    release_print " already exists"
else
    release_print " does not exist, will create"
    manifest_release_create         # Create release directory structure
fi

# Generate documents
generate_docs "$current_branch"

generate_mram_burners               # Generate MRAM Burners ULINK

generate_mram_burner_lb             # Generate MRAM Burner  Lauter Bach

generate_bootstubs_a32              # Generate BOOTSTUBS A32

generate_bootstubs_m55              # Generate BOOTSTUBS M55

generate_seram                      # Generate SERAM-BL

generate_seram_manifest_copy        # Generate SERAM-BL Manifest copy

# update AlifTocPackage.bin
release_print "** [SETOOLS Release] generating AlifTocPackage.bin"
cd "$release_dir/"
generate_package

release_print "** [SETOOLS Release] pycache removal from AlifTocPackage.bin"
rm -rf utils/__pycache__            # remove pycache
cd ../

# EXE builder (not for ICV, see APP release for this)
#release_print "** [SETOOLS Release] generating EXECUTABLES"
#executable_create

#ls -l "$release_dir/utils/lzf-lnx"
#chmod +x "$release_dir/utils/lzf-lnx"  # add executable premission to the utility
#ls -l "$release_dir/utils/lzf-lnx"

# Final step create the compressed tar ball 
if [[ $MANIFEST_SUPPRESS == "ON" ]]
then
   release_print "[INFO] Skipped release package create"
else
    # Tack on the Revision
    if [[ $BUILD_OPTION == @("B0") ]]
    then
        release_bundle="$release_dir-$current_branch-REV_B0"
    else
        release_bundle="$release_dir-$current_branch"
    fi
    echo "Bundle: $release_bundle"
    # Tack on the date
    if [[ $TIMESTAMP__OPTION == @("ON") ]]
    then
        now_is_only_thing_that_is_real=$(date +"%m-%d")
        release_bundle="$release_bundle-$now_is_only_thing_that_is_real"
    fi
    release_print "-n" "** [SETOOLS Release] creating release package "
     release_tar="$release_bundle.zip"
    release_print "\"$release_tar\""
    zip -r $release_tar $release_dir/* 
    if [[ $TARBALL_OUTPUT == @("ON") ]]
    then
    #    release_tar="$release_dir-$current_branch.tar"
        release_tar="$release_bundle.tar"
        tar -czf $release_tar $release_dir/*
    fi
fi

release_print ""

profile_stop

printf "\e[32m ** Build Time %02dm%02ds \e[0m\n" $minutes_time $seconds_time

release_print "************ [SETOOLS] ALIF release package complete **************"

# Fin
