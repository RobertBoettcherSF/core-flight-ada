# Core Flight Ada

Core Flight Ada (CFA) is an independent Ada analogue of a cFS-style flight
executive: a cyclic tick, a software bus, events, time, tables, a sample
application, a browser splash and console, and a native Linux program.

It is not a NASA product, not a fork of [nasa/cFS](https://github.com/nasa/cFS),
and not a certified flight load.

## Try the page

Version **0.10.0**. Open the splash and console here:

[https://raw.githack.com/RobertBoettcherSF/core-flight-ada/main/dist/index.html?v=10](https://raw.githack.com/RobertBoettcherSF/core-flight-ada/main/dist/index.html?v=10)

JavaScript only draws the frames, handles menus and splash timing, and
downloads a feedback file. The flight loop and splash math run in Ada
compiled to WebAssembly.

## Native Linux program

```bash
gprbuild -p -P cfa.gpr
./bin/cfa_native
```

Commands on stdin: `noop`, `sample`, `status`, `help`, `quit`. See `NATIVE.md`.

## SPARK

The core packages enable SPARK. An honest proved-versus-unproved write-up
is in `SPARK-REPORT.md`. That report is not a certification claim.
