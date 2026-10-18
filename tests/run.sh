#!/bin/sh
# Runs VEYL's mock-Roblox test suites with the Luau CLI.
# Usage: tests/run.sh            (needs `luau` on PATH, or downloads it to tests/.bin)
set -e
T=$(cd "$(dirname "$0")" && pwd)
R=$(dirname "$T")
LUAU=$(command -v luau || true)
if [ -z "$LUAU" ]; then
  LUAU="$T/.bin/luau"
  if [ ! -x "$LUAU" ]; then
    mkdir -p "$T/.bin"
    curl -sSL -o "$T/.bin/luau.zip" https://github.com/luau-lang/luau/releases/latest/download/luau-ubuntu.zip
    unzip -o -q "$T/.bin/luau.zip" -d "$T/.bin"
  fi
fi
python3 "$R/tools/bundle.py" >/dev/null
WORK=$(mktemp -d)
build() { # mode driver script [loader]
  {
    cat "$T/classes.lua" "$T/mock.lua"
    echo 'warn = function(...) print("WARN", ...) end'
    echo 'SHARED = {}; getgenv = function() return SHARED end'
    if [ "$1" = executor ]; then
      echo 'EXECUTOR = true'
      echo 'local __ex = {}; ENABLE_EXECUTOR(__ex)'
      echo 'gethui = __ex.gethui; readfile = __ex.readfile; writefile = __ex.writefile; isfile = __ex.isfile; makefolder = __ex.makefolder; isfolder = __ex.isfolder; setclipboard = __ex.setclipboard; identifyexecutor = __ex.identifyexecutor; Drawing = __ex.Drawing'
    fi
    if [ "$4" = loader ]; then
      echo 'os = MOCK_OS; typeof = MOCK_TYPEOF'
      echo 'local __nativeLoadstring, __env = loadstring, getfenv(1)'
      echo 'loadstring = function(src, name) local f, e = __nativeLoadstring(src, name); if f then setfenv(f, __env) end; return f, e end'
      python3 "$T/sources.py" "$R"
    fi
    echo 'local os = MOCK_OS'
    echo 'local typeof = MOCK_TYPEOF'
    echo 'local function main()'
    cat "$3"
    echo 'end'
    cat "$T/$2"
  } > "$WORK/test.lua"
}
status=0
run() { # name mode driver script [loader]
  build "$2" "$3" "$4" "$5"
  out=$("$LUAU" "$WORK/test.lua" 2>&1 || true)
  result=$(printf '%s\n' "$out" | grep '^RESULT' || echo "RESULT: crashed")
  passes=$(printf '%s\n' "$out" | grep -c '^PASS' || true)
  printf '%-26s %3s passed  %s\n' "$1" "$passes" "$result"
  printf '%s\n' "$out" | grep -E '^(FAIL|!!)' || true
  case "$result" in *"0 failure(s), 0 error(s)"*) ;; *) status=1 ;; esac
}
run "smoke (plain client)" plain smoke.lua "$R/dist/VEYL.lua"
run "smoke (executor APIs)" executor smoke.lua "$R/dist/VEYL.lua"
run "behavior" executor behavior.lua "$R/dist/VEYL.lua"
run "loader" executor loader.lua "$R/loader.lua" loader
rm -rf "$WORK"
exit $status
