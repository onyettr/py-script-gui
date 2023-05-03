#!/bin/bash
# @brief Build all source code components of repo including PLATFORM variants 

if [ "`uname -s`" == "CYGWIN_NT-10.0" ]; then
  PARALLEL_TASKS="-j `nproc`"
fi

#
# Trap handler: any errors generated will force execution of the following
# negates the use of set -e and make -i
#
trap error_handler ERR

function error_handler(){
  save_error=$?

  echo -n "[Buildall] Error - $save_error"
  echo " Running '$BASH_COMMAND' on line ${BASH_LINENO[0]}"

  exit $save_errorcode
}

echo "** Building SETOOLS"

echo "** Building SETOOLS MRAM_BURNER"
cd mram_burner

make clean
make ${PARALLEL_TASKS} -i

cd ..

echo "** Building SETOOLS LB_MRAM_BURNER"
cd lb_mram_burner

make clean
make ${PARALLEL_TASKS} -i

cd ..

echo "** Building SETOOLS ICV_PROVISION"
cd factory-tools/icv-prov

make clean
make ${PARALLEL_TASKS} -i

cd ../..

cp mram_burner/build/mram_burner.axf bin/mram_burner.axf


echo "************ Build complete **************"
