#!/usr/bin/env bash

# Developer information
readonly AUTHOR="Corvus"
readonly GITHUB="https://github.com/Yamen1294"

print_banner() {
    printf '\n'
    printf '%s' "$C_CYN"
    cat <<'EOF'
   _____
  / ____|
 | |     ___  _ ____   _____ _   _
 | |    / _ \| '__\ \ / / _ \ | | |
 | |___| (_) | |   \ V /  __/ |_| |
  \_____\___/|_|    \_/ \___|\__, |
                              __/ |
                             |___/
EOF
    printf '%s' "$C_RST"
    printf '  Made by %s%s%s\n' "$C_BLD" "$AUTHOR" "$C_RST"
    printf '  GitHub: %s%s%s\n' "$C_CYN" "$GITHUB" "$C_RST"
    printf '  Version: %s\n\n' "$SCRIPT_VERSION"
    printf '  Staus:   %s\n\n' "$SCRIPT_STATUS"
}


set -Eeuo pipefail

readonly SCRIPT_NAME="${0##*/}"
readonly SCRIPT_VERSION="1.1.0"
readonly SCRIPT_STATUS="DEMO-Version"
ASSUME_YES=0
DO_COUNT=0
SUDO=()


# Output helpers

if [[ -t 1 ]]; then
  readonly C_RED=$'\e[31m' C_GRN=$'\e[32m' C_YLW=$'\e[33m'
  readonly C_CYN=$'\e[36m' C_BLD=$'\e[1m' C_RST=$'\e[0m'
else
  readonly C_RED='' C_GRN='' C_YLW='' C_CYN='' C_BLD='' C_RST=''
fi

info() { printf '%s[*]%s %s\n' "$C_CYN" "$C_RST" "$*"; }
ok() { printf '%s[+]%s %s\n' "$C_GRN" "$C_RST" "$*"; }
warn() { printf '%s[!]%s %s\n' "$C_YLW" "$C_RST" "$*" >&2; }
die() {
  printf '%s[x]%s %s\n' "$C_RED" "$C_RST" "$*" >&2
  exit 1
}
header() { printf '\n%s== %s ==%s\n' "$C_BLD" "$*" "$C_RST"; }

trap 'printf "\n"; warn "Interrupted."; exit 130' INT

usage() {
  cat <<EOF
${C_BLD}${SCRIPT_NAME} ${SCRIPT_VERSION}${C_RST} — package & dependency manager for Void Linux

${C_BLD}USAGE${C_RST}
  ${SCRIPT_NAME}                        Interactive menu
  ${SCRIPT_NAME} list [PACKAGE]         List installed packages and their dependencies,
                                  or show the full dependency report of PACKAGE
  ${SCRIPT_NAME} remove PACKAGE         Remove PACKAGE and its unneeded dependencies
  ${SCRIPT_NAME} -count                 Show the installed and orphan package counts

${C_BLD}OPTIONS${C_RST}
  -count, --count  Show installed and orphan package counts
  -y, --yes        Do not ask for confirmation
  -h, --help       Show this help
  -V, --version    Show version
EOF
}


# Generic helpers

require_cmds() {
  local c
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 ||
      die "Required command not found: ${c} (is this a Void Linux system?)"
  done
}

setup_privileges() {
  SUDO=()
  if ((EUID != 0)); then
    if command -v sudo >/dev/null 2>&1; then
      SUDO=(sudo)
    elif command -v doas >/dev/null 2>&1; then
      SUDO=(doas)
    else
      die "Root privileges required. Run as root or install sudo/doas."
    fi
  fi
}

confirm() {
  ((ASSUME_YES)) && return 0
  local reply
  read -r -p "$1 [y/N] " reply
  [[ $reply =~ ^[Yy]([Ee][Ss])?$ ]]
}

page() {
  if [[ -t 1 ]] && command -v less >/dev/null 2>&1; then
    less -R -F -X
  else
    cat
  fi
}

# Reads lines from stdin and prints them as a bullet list.
print_list() {
  local line n=0
  while IFS= read -r line; do
    if [[ -n $line ]]; then
      printf '  - %s\n' "$line"
      n=$((n + 1))
    fi
  done
  if ((n == 0)); then
    printf '  (none)\n'
  else
    printf '  %sTotal: %d%s\n' "$C_BLD" "$n" "$C_RST"
  fi
}

# Prints the number of non-empty lines in a string (0 for an empty string).
count_lines() {
  local -a lines
  if [[ -z $1 ]]; then
    printf '0\n'
  else
    mapfile -t lines <<<"$1"
    printf '%d\n' "${#lines[@]}"
  fi
}


# XBPS query helpers

# Normalises a dependency pattern ("foo>=1.2_1", "foo-1.2_1", "foo") to "foo".
dep_name() {
  local d=${1%%[<>=]*}
  if [[ $d =~ ^(.+)-[0-9][^-]*_[0-9]+$ ]]; then
    d=${BASH_REMATCH[1]}
  fi
  printf '%s\n' "$d"
}

list_installed() {
  xbps-query -l | awk '{print $2}' | sed -E 's/-[^-]+$//' | sort -u
}

# Packages installed explicitly (not pulled in as dependencies).
list_manual() {
  xbps-query -m 2>/dev/null | sed -E 's/-[0-9][^-]*_[0-9]+$//' | sort -u || true
}

# Orphans: installed as dependencies but no longer needed by anything.
list_orphans() {
  xbps-query -O 2>/dev/null | sed -E 's/-[0-9][^-]*_[0-9]+$//' | sort -u || true
}

is_installed() {
  xbps-query "$1" >/dev/null 2>&1
}

assert_installed() {
  is_installed "$1" && return 0
  warn "Package '$1' is not installed."
  local matches
  matches=$(list_installed | grep -iF -- "$1" | head -n 10 || true)
  if [[ -n $matches ]]; then
    warn "Similar installed packages:"
    print_list <<<"$matches" >&2
  fi
  exit 1
}

direct_deps() {
  local dep
  while IFS= read -r dep; do
    if [[ -n $dep ]]; then
      dep_name "$dep"
    fi
  done < <(xbps-query -x "$1" 2>/dev/null || true) | sort -u
}

# Full transitive dependency set (breadth-first, cycle-safe).
all_deps() {
  local root=$1 cur dep
  local -A seen=()
  local -a queue=("$root")

  while ((${#queue[@]})); do
    cur=${queue[0]}
    queue=("${queue[@]:1}")
    while IFS= read -r dep; do
      if [[ -z $dep || $dep == "$root" || -n ${seen[$dep]:-} ]]; then
        continue
      fi
      seen[$dep]=1
      queue+=("$dep")
    done < <(direct_deps "$cur")
  done

  if ((${#seen[@]})); then
    printf '%s\n' "${!seen[@]}" | sort
  fi
  return 0
}

reverse_deps() {
  { xbps-query -X "$1" 2>/dev/null || true; } | sed -E 's/-[^-]+$//' | sort -u
}

# Option 1: list

show_package() {
  local pkg=$1 manual reason direct all rev
  local n_direct n_all n_rev
  assert_installed "$pkg"

  manual=$(list_manual)
  if grep -qxF -- "$pkg" <<<"$manual"; then
    reason="manually installed"
  else
    reason="automatic (installed as a dependency)"
  fi

  direct=$(direct_deps "$pkg")
  all=$(all_deps "$pkg")
  rev=$(reverse_deps "$pkg")
  n_direct=$(count_lines "$direct")
  n_all=$(count_lines "$all")
  n_rev=$(count_lines "$rev")

  printf '%sPackage:%s %s\n' "$C_BLD" "$C_RST" "$pkg"
  printf '%sReason :%s %s\n' "$C_BLD" "$C_RST" "$reason"
  printf '%sCounts :%s %d direct, %d total (recursive), %d required by\n' \
    "$C_BLD" "$C_RST" "$n_direct" "$n_all" "$n_rev"

  header "Direct dependencies (${n_direct})"
  print_list <<<"$direct"

  header "All dependencies, recursive (${n_all})"
  print_list <<<"$all"

  header "Required by, reverse dependencies (${n_rev})"
  print_list <<<"$rev"
}

show_all() {
  local name total manual_n auto_n
  local -a deps

  total=$(count_lines "$(list_installed)")
  manual_n=$(count_lines "$(list_manual)")
  auto_n=$((total - manual_n))

  printf '%sInstalled packages  : %s%s\n' "$C_BLD" "$total" "$C_RST"
  printf '  manually installed : %s\n' "$manual_n"
  printf '  as dependencies    : %s\n\n' "$auto_n"

  while IFS= read -r name; do
    mapfile -t deps < <(direct_deps "$name")
    printf '%s%s%s  (%d deps)\n' "$C_BLD" "$name" "$C_RST" "${#deps[@]}"
    if ((${#deps[@]})); then
      printf '    deps: %s\n' "${deps[*]}"
    fi
  done < <(list_installed)
}

cmd_list() {
  local pkg=${1:-}
  if [[ -n $pkg ]]; then
    { show_package "$pkg"; } | page || true
  else
    info "Collecting package data (this can take a few seconds)..."
    { show_all; } | page || true
  fi
}


# Count: installed and orphan packages

cmd_count() {
  local total orphans
  total=$(count_lines "$(list_installed)")
  orphans=$(count_lines "$(list_orphans)")

  printf '%sInstalled packages : %s%s\n' "$C_BLD" "$total" "$C_RST"
  printf '%sOrphan packages    : %s%s\n' "$C_BLD" "$orphans" "$C_RST"
}


# Option 2: remove

cmd_remove() {
  local pkg=${1:-} revdeps
  [[ -n $pkg ]] || die "No package specified."
  assert_installed "$pkg"

  revdeps=$(reverse_deps "$pkg")
  if [[ -n $revdeps ]]; then
    warn "These installed packages depend on '${pkg}':"
    print_list <<<"$revdeps" >&2
    die "Refusing to remove '${pkg}'. Remove the dependent packages first."
  fi

  local dry planned before after
  setup_privileges

  header "Dry run: packages that would be removed"
  dry=$("${SUDO[@]}" xbps-remove -nR "$pkg" 2>&1) || {
    printf '%s\n' "$dry" >&2
    die "Dry run failed; nothing was removed."
  }
  printf '%s\n' "$dry"

  # Best-effort count of the packages listed in the dry-run output.
  planned=$(awk '$2 == "remove" || $1 ~ /^[^[:space:]]+-[0-9][^[:space:]]*_[0-9]+$/ { n++ } END { print n + 0 }' <<<"$dry")
  if ((planned > 0)); then
    printf '\n%sPackages to be removed: %d%s\n' "$C_BLD" "$planned" "$C_RST"
  fi

  echo
  confirm "Remove '${pkg}' and its unneeded dependencies?" || {
    info "Aborted."
    return 0
  }

  before=$(count_lines "$(list_installed)")
  "${SUDO[@]}" xbps-remove -Ry "$pkg" || die "Removal failed."
  after=$(count_lines "$(list_installed)")

  ok "Removed '${pkg}' and its unneeded dependencies."
  printf '    Packages removed   : %d\n' "$((before - after))"
  printf '    Packages remaining : %d\n' "$after"
}


# Interactive menu

pause() {
  local _
  read -r -p $'\nPress Enter to continue...' _
}

main_menu() {
  local choice pkg
  while true; do
    printf '\n%s=== voidpkg — Void Linux package manager ===%s\n' "$C_BLD" "$C_RST"
    printf '  1) List installed packages and their dependencies\n'
    printf '  2) Remove a package and its dependencies\n'
    printf '  q) Quit\n\n'
    read -r -p "Select an option [1/2/q]: " choice

    case $choice in
    1)
      read -r -p "Package name (empty = list all): " pkg
      (cmd_list "$pkg") || true
      pause
      ;;
    2)
      read -r -p "Package to remove: " pkg
      (cmd_remove "$pkg") || true
      pause
      ;;
    q | Q) exit 0 ;;
    *) warn "Invalid choice: '${choice}'" ;;
    esac
  done
}

# Entry point

main() {
  print_banner
  local -a args=()

  while (($#)); do
    case $1 in
    -count | --count) DO_COUNT=1 ;;
    -y | --yes) ASSUME_YES=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    -V | --version)
      printf '%s %s\n' "$SCRIPT_NAME" "$SCRIPT_VERSION"
      exit 0
      ;;
    -*) die "Unknown option: $1 (see --help)" ;;
    *) args+=("$1") ;;
    esac
    shift
  done

  require_cmds xbps-query xbps-remove awk sed sort

  if ((DO_COUNT)); then
    cmd_count
    exit 0
  fi

  case ${args[0]:-} in
  "") main_menu ;;
  list | ls) cmd_list "${args[1]:-}" ;;
  remove | rm) cmd_remove "${args[1]:-}" ;;
  *) die "Unknown command: ${args[0]} (see --help)" ;;
  esac
}

main "$@"
