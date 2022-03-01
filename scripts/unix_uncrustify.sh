#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(realpath "${SCRIPT_DIR}/..")"

# Exit is for when cd fails for whatever reason
cd "$ROOT_DIR" || exit

function usage {
  echo "\
${BASH_SOURCE[0]} [--check] [--git] [FILEPATHS]

Run the uncrustify tool against repository C++ files.
Assumes a unix environment.

If no explicit filepaths are provided, automatic file discovery will occur:

* If the '--git' option is provided, we use 'git status' to deduce
  added/modified/unstaged files to check/format.

* Otherwise, all h/txx/cxx files under known directories here will be collected
  for checking/formatting.

The --check option may be provided to instead run uncrustify in check-mode,
which doesn't modify files but instead exits with a non-zero code if any
files *would* be changed. Files that would be changed are output to STDERR:
    $ bash unix_uncrustify.sh 1>/dev/null

Options:

  -h, --help    Print this
  --check       Just check file formatting. See the '--check' option for the
                uncrustify tool for more details.
  --git         Discover files based that have been added, modified, or
                no-staged via the 'git status -s' command.

Arguments:

  FILEPATHS     Optionally provided explicit files to be formatted/checked.
"
}

# If we should run uncrustify in to CHECK files instead of modifying them.
CHECK_MODE=0
# If we should collect files from git status added/modified/unstaged
GIT_MODE=0
# Explicitly provided filepaths
EXPLICIT_FILES=()

while [[ $# -gt 0 ]]
do
  key="$1"
  shift  # past key
  case ${key} in
    -h|--help)
      usage
      exit 0
      ;;
    --check)
      CHECK_MODE=1
    ;;
    --git)
      # Collect files modified/added in git status
      GIT_MODE=1
    ;;
    *)  # Anything else (wildcard)
      # Assuming a provided filepath
      echo "Adding \"$key\""
      EXPLICIT_FILES[${#EXPLICIT_FILES[@]}]="$key"
      #EXPLICIT_FILES+=("${key}")
    ;;
  esac
done

if [[ "${#EXPLICIT_FILES[@]}" -eq 0 ]]
then
  # If there were no files specifically provided, discover files instead.
  if [[ "${GIT_MODE}" -eq 1 ]]
  then
    mapfile -d "" CPP_FILES < <(git status -s | grep -v "^D " | grep -E "\.(h|cxx|cpp)$" | cut -c 4- | tr '\n' '\0')
  else
    # Directories relative to the root directory to search for C++ files for
    # uncrustification.
    CPP_SOURCE_DIRS=(
      "python"
      "ros"
    )

    # NOTE: This subtractive grep usage to filter out certain places we chose not to
    # enforce style requirements on.
    mapfile -d "" CPP_FILES \
      < <(find "${CPP_SOURCE_DIRS[@]}" \
          -type f -regextype egrep -iregex ".*\.(h|cxx|cpp|txx)" -print0 \
          | grep -zv "^vital/kwiversys" )
  fi
else
  CPP_FILES=("${EXPLICIT_FILES[@]}")
fi

## Debug file selection
#echo "CPP FILES: (${#CPP_FILES[@]})"
#for F in "${CPP_FILES[@]}"
#do
#  echo "- '$F'"
#done
#exit

# This call may be adapted to only "check" for files that **would** be modified
# by replacing the ``--no-backup --replace`` options with ``--check``.
if [[ "${CHECK_MODE}" -eq 1 ]]
then
  MODE_ARGS="--check"
else
  MODE_ARGS="--no-backup --replace"
fi
# Use of `-lCPP` is important. Otherwise not all files are treated the same.
# shellcheck disable=SC2086
uncrustify -c "$ROOT_DIR"/uncrustify.cfg -lCPP ${MODE_ARGS} "${CPP_FILES[@]}"
