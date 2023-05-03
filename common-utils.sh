#!/bin/bash
# Secure Enclave Services Release packager - common-utils.sh
#

# what are we running on
# @brief determine os being run on
function what_os()
{
    case "${kernel_name}" in
        Linux*)     os=Linux;;
        Darwin*)    os=Mac;;
        CYGWIN*)    os=Cygwin;;
        MINGW*)     os=MinGw;;
        *)          os=unknown
    esac
    echo ${os}
}

# return true if inc_string is part of src_string
function includes()
{
  src_string="$1"
  inc_string="$2"

  case "$src_string" in
    *"$inc_string"*) return 1 ;;
    *) return 0 ;;
  esac
}

#  support function to see if an external programme exists
function test_exists()
{
    command -v "$1" >/dev/null
}

# release_print - print woth colours
function release_print()
{
  # Potential other colours
  # red     '\e[0;31m'
  # green   '\e[0;32m'
  # yellow  '\e[0;33m'
  # blue    '\e[0;34m'
  # magenta '\e[0;35m'
  # cyan    '\e[0;36m'
  # white   '\e[0;37m'
  # black   '\e[0;47m'
  # RESET   '\e[0m'
 
  if [[ "$1" == "-n" ]]
  then
    echo -en "\e[32m $2 \e[0m"
  else
    echo -e "\e[32m $1 \e[0m"
  fi
}

# release_error - function to print error in colour
function release_error()
{
  # red     '\e[0;31m'
  if [[ "$1" == "-n" ]]
  then
    echo -en "\e[31m $2 \e[0m"
  else
    echo -e "\e[31m $1 \e[0m"
  fi
}

# Time stamp - get initial start time
function profile_start()
{
    start_time=$(date +%s)
    SECONDS=0
}

# Time stamp - get end value and print stats
function profile_stop()
{
    # Complete build time statistics
    # - can use SECONDS now built into bash?
    end_time=$(date +%s)
    #echo $start_time $end_time

    delta_time=$((end_time-start_time))
    seconds_time=$((SECONDS % 60))
    minutes_time=$(((SECONDS / 60) % 60))
    #hours_time=$((SECONDS / 3600))         # I hope not!

    printf "\e[32m ** Build Time %02dm%02ds \e[0m\n" $minutes_time $seconds_time
}
