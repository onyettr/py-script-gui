#!/bin/bash
# Sample bash scripts - argc/argv handling 

# bash debugging
# -v verbose mode prints piut everything
# -x  
# set -x

echo "$0 starting.."
echo "argc = $#" 

VERSION_STRING="0.1.0"

VERSBOSE_MODE=0
QUIET_MODE=0
INFO_LEVEL=0

# help screen 
help_screen() {
  echo "$0: example cli bash script [-h|i|f|o|q|v|V]"
  echo "options:"
  echo "I | --info          Info level [0|1|2]]"
  echo "h | --help          Help screen        "
  echo "f | --inputfile     <file name>        "
  echo "o | --outputfile    <file name>        "
  echo "q | --quiet         quiet mode         "
  echo "v | --verbose       enable verbose mode"
  echo "V | --Version       version string     "
}

# command line processing
while [[ $# -gt 0 ]]
do
  case "$1" in
    -h|--help) 
      help_screen
      exit 0;;
    -q|--quiet)
      QUIET_MODE=1
      ;;
    -i|--info)
      INFO_LEVEL="$2"
      shift;; 
    -f|--inputfile)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        INPUT_FILENAME=$2
      else
        echo "[ERROR] no $1 <filename> supplied" >&2
        exit 1
      fi
      shift;;
    -o|--outputfile)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        OUTPUT_FILENAME=$2
      else
        echo "[ERROR] no $1 <filename< supplied" >&2
        exit 1
      fi
      shift;;
    -v|--verbose)
      VERSBOSE_MODE=1
      ;;
    -V|--version)
      echo $VERSION_STRING
      exit 0;;
     *) 
      echo "[ERROR] $1 is not a valid option" 
      exit 1;;
  esac
  shift   
done

function generate_seram()
{
    make clean
    make ${PARALLEL_TASKS} DEVICE_TYPE=SPARK PLATFORM_TYPE=FPGA RELEASE_BUILD=$RELEASE_BUILD_PARAM
    if [[ $? -ne 0 ]]
    then
        exit 1
    fi
}

echo "Verbose Mode       $VERSBOSE_MODE  "
echo "Quiet Mode         $QUIET_MODE     "
echo "Information level  $INFO_LEVEL     "
echo "Input Filename     $INPUT_FILENAME "
echo "Output Filename    $OUTPUT_FILENAME"

generate_seram