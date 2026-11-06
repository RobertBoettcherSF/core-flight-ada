#!/bin/sh
set -e
cd "$(dirname "$0")/.."
ROOT=$PWD
T=$ROOT/toolchain/usr
LD=$ROOT/toolchain/wasm-ld
CLANG=/tmp/wasi-sdk-24.0-x86_64-linux/bin/clang
export LD_LIBRARY_PATH="$ROOT/toolchain/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
rm -rf obj/wasm
mkdir -p obj/wasm/src obj/wasm/src/browser dist

# Working copy with Assertion_Policy Ignore (WASM RTS cannot resume after assert).
for F in src/*.ad[sb] src/browser/*.adb src/browser/*.c src/browser/gnat.adc; do
  [ -e "$F" ] || continue
  case "$F" in
    src/*) dest=obj/wasm/$F ;;
  esac
  mkdir -p "$(dirname "$dest")"
  if echo "$F" | grep -q '\.ad[sb]$'; then
    sed 's/pragma Assertion_Policy (Check);/pragma Assertion_Policy (Ignore);/g' "$F" > "$dest"
  else
    cp "$F" "$dest"
  fi
done
# Soft LCH/assert stubs (should not be called if Ignore works)
cat > obj/wasm/src/browser/last_chance.c << 'C'
void __gnat_last_chance_handler (char *file, int line) {
  (void)file; (void)line; __builtin_trap();
}
void system__assertions__raise_assert_failure (void *msg, void *file, int line) {
  (void)msg; (void)file; (void)line; __builtin_trap();
}
C

CC="$T/bin/llvm-gcc"
FLAGS="-c --target=wasm32 -O2 -gnat2012 -gnatp -gnatwa --RTS=$T/lib/rts-native -I$ROOT/obj/wasm/src -I$ROOT/obj/wasm/src/browser"

cd obj/wasm
for F in \
  cfa.adb cfa-time.adb cfa-events.adb cfa-bus.adb cfa-schedule.adb \
  cfa-executive.adb cfa-cmd.adb cfa-sample.adb cfa-tlm.adb \
  cfa-tables.adb cfa-boot.adb cfa-visual.adb cfa-api.adb
do
  echo "compile $F"
  $CC $FLAGS "src/$F"
done
echo "compile browser platform"
$CC $FLAGS "src/browser/cfa-platform.adb"
echo "compile last_chance stub"
$CLANG -c --target=wasm32 -O2 src/browser/last_chance.c -o last_chance.o

mkdir -p rts && (cd rts && ar x "$T/lib/rts-native/adalib/libgnat.a")
for M in s-memcop.o s-memmov.o s-memset.o; do cp rts/$M .; done

$LD --no-entry --strip-all \
  --export=cfa_init --export=cfa_tick --export=cfa_accept_command \
  --export=cfa_mission_ms --export=cfa_tick_count --export=cfa_run_level \
  --export=cfa_noop_count --export=cfa_sample_count \
  --export=cfa_app_count --export=cfa_app_kind --export=cfa_app_runs \
  --export=cfa_event_count --export=cfa_event_sev --export=cfa_event_app \
  --export=cfa_event_text_len --export=cfa_event_text_byte \
  --export=cfa_version_len --export=cfa_version_byte \
  --export=cfa_viz_start --export=cfa_viz_tick --export=cfa_viz_frame \
  --export=cfa_viz_width --export=cfa_viz_height --export=cfa_viz_scene \
  --export=cfa_viz_scene_count \
  --export=cfa_table_count --export=cfa_table_name_len --export=cfa_table_name_byte \
  --export=cfa_table_rows --export=cfa_table_cols \
  --export=cfa_table_col_name_len --export=cfa_table_col_name_byte \
  --export=cfa_table_cell \
  --initial-memory=33554432 \
  -o cfa.wasm \
  cfa.o cfa-time.o cfa-events.o cfa-bus.o cfa-schedule.o cfa-executive.o \
  cfa-cmd.o cfa-sample.o cfa-tlm.o cfa-tables.o cfa-boot.o cfa-visual.o cfa-api.o cfa-platform.o \
  s-memcop.o s-memmov.o s-memset.o last_chance.o

echo "WASM bytes: $(wc -c < cfa.wasm)"
cd "$ROOT"
python3 "$ROOT/tools/embed-wasm.py"
