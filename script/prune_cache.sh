#! /usr/bin/env bash
#
# prune_cache: remove older cache entries
#
# This script is intended to be run from cron periodically to ensure that the
# file cache does not accumulate too many entries that are unlikely to be
# re-used and yet would persist until the next restart of Virgo.

SHOW_STARTING_SIZE=true
SHOW_ENDING_SIZE=true
NL='
'

RAILS_DIR="$RAILS_ROOT"
[ "$RAILS_DIR" ] || RAILS_DIR='/usr/local/projects/search'
CACHE_DIR="$RAILS_DIR/tmp/cache"
FILE_STORE='file_store'
FILE_STORE_PATH="$CACHE_DIR/$FILE_STORE"

PROG_NAME=`basename "$0" .sh`
TMP_DIR='/var/tmp'
LOG_FILE="$TMP_DIR/virgo_${PROG_NAME}.out"

# Send output to a file if not run from the command line (e.g. from cron).
[ -t 0 ] || exec > "$LOG_FILE" 2>&1

# Change to the cache directory.
cd "$CACHE_DIR" || exit 1

# Cache entry expiration for most items is currently 60 minutes, but to avoid
# deleting files that are just going to be regenerated soon anyway, only delete
# files that haven't been accessed in a longer span of time.
declare -i EXPIRATION_TIME=60
declare -i ACCESS_FACTOR=2
declare -i LAST_ACCESS_TIME=`expr $EXPIRATION_TIME \* $ACCESS_FACTOR`

# =============================================================================
# Functions
# =============================================================================

function Alert { # text
  echo "$@" 1>&2
}

function Help {
  Alert "Usage: $PROG_NAME {--prune|--clear}"
}

function ShowSize { # label
  local LABEL="$1"
  echo -n "$LABEL "
  du -sh "$FILE_STORE_PATH"
  echo ''
}

function Prune { # age
  local -i AGE="$1"
  [ $AGE == 0 ] || AGE=$LAST_ACCESS_TIME
  echo "Pruning cache entries older than $AGE minutes...${NL}"
  [ "$SHOW_STARTING_SIZE" ] && ShowSize 'STARTING SIZE'
  find "$FILE_STORE" -type f -amin "+$AGE" -ls -delete |
  awk '
    {
      entries++;
      bytes += $7;
      print $0;
    }
    END {
      bytes /= 1024; # KB
      bytes /= 1024; # MB
      printf "\n%d entries deleted; %.2f MB reclaimed\n", entries, bytes
    }
  '
  [ "$SHOW_ENDING_SIZE" ] && ShowSize "${NL}ENDING SIZE"
}

function Clear {
  if [ -d "$FILE_STORE_PATH" ] ; then
    echo "Clearing all $FILE_STORE_PATH cache entries...${NL}"
    cd "$FILE_STORE_PATH" && rm -rf *
  else
    Alert "$FILE_STORE_PATH: not a directory"
  fi
}

# =============================================================================
# MAIN PROGRAM
# =============================================================================

# Remove all files, or find and delete files that are unlikely to be reused.
date
case "$1" in
  --prune) Prune ;;
  --clear) Clear ;;
  *)       Help ;;
esac
