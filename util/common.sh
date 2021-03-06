#####################################################################
# Common BASH helpers, including a mini flag-parsing library.
#####################################################################

# check if function exists
fn_exists(){ declare -f $1 >/dev/null; }

#####################################################################
# Parse flags passed to it. Flags must be pre-defined using 
# `define_flag` before calling this.
# 
# Typical usage:
# 
#   # define some flags
#   define_flags 'host' 'localhost' 'Hostname to connect to' 'h'
#   define_flags 'port' 4000 'Port to connect to' 'p'
#   
#   parse_flags $@
#   
#   echo "connecting to $FLAGS_host:$FLAGS_port"
#   echo "remaining args -> $FLAGS_remaining"
#   
#   ----
#   > ./script --help
#   usage:
#     --help  print this help message
#     --host=localhost  Hostname to connect to
#     --port=4000  Port to connect to
#   
#   > ./script --host=google.com -- -extra
#   connecting to google.com:4000
#   remaining args -> -extra
#
#####################################################################
parse_flags() {  
  while (( "$#" )); do
    flag=
    case $1 in
      --)
        shift
        break
        ;;
      --*=*)
        a=${1##--}
        flag=${a%%=*};
        val=${a##*=}
        ;;
      --*)
        flag=${1/--/}
        val=$2
        ;;
      # -*)
      #   echo "short: ${1/-/}"
      #   ;;
      # *)
      #   echo "pos: $1"
      #   ;;
    esac
    echo ">> $flag -> $val" >&2
    if [[ $flag ]]; then
      if fn_exists "__handle_flag_$flag"; then
        eval "__handle_flag_$flag $val"
      else
        echo ">> invalid flag: $flag";
        exit 1
      fi
    fi
    shift
  done
  
  # return the remaining flags to the caller
  FLAGS_remaining=$@
}

###################################################################
# Define a new flag, initialize variable with default value.
# Note: works like gflags/shflags (but not perfectly compatible)
# 
# Usage:
#
#   define_flag <long_name> <default_value> <description> [<short_name>]
# 
# Defines a flag `--long_name` (and optionally a 1-character 'short' 
# flag, such as '-l').
# 
# The variable `FLAGS_${long_name}` will be used to store the value.
# If this variable was already set in the environment, it will keep 
# that value (so these can be specified via environment variables); 
# if not set already, it will be initialized to the 'default' value.
# Finally, when `parse_flags` is called, it will override the value 
# if the flag is present.
#
# As with gflags, a built-in `--help` or `-h` flag is created which
# prints a message with all of the flags and their descriptions.
#
# example usage:
#   
#   # create flag '--partition'
#   define_flag 'partition' 'sampa' "Slurm partition to use" 'p'
#   
#   # which can be specified in any of these ways:
#   > ./script -p grappa
#   > ./script --partition=grappa
#   > ./script --partition grappa
#   > FLAGS_partition=grappa ./script
#
###################################################################
define_flag() {
  long_name=$1
  default=$2
  desc=$3
  short_name=$4
  
  FLAGS_help_msg="$FLAGS_help_msg
  --$long_name=$default  $desc" 
  
  eval "FLAGS_${long_name}=$default"
  
  eval "__handle_flag_${long_name}() { FLAGS_${long_name}=\$1; declare -x FLAGS_${long_name}; }"
  if [ -n "$short_name" ]; then
    eval "__handle_flag_${short_name}() { FLAGS_${long_name}=\$1; }"
  fi
}

__handle_flag_help() {
  echo "usage:
  --help,-h  print this help message$FLAGS_help_msg" >&2
  exit 1
}
__handle_flag_h() { __handle_flag_help; }
