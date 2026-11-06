# Core Flight Ada — native Linux program

Same Ada core as the browser page (`Cfa.*`), with the `src/native` Platform body.

## Build

From the project root:

```bash
gprbuild -p -P cfa.gpr
```

This builds both:

- `bin/cfa_driver` — regression smoke test (Items 2–8)
- `bin/cfa_native` — interactive native console (Item 9)

## Run

```bash
./bin/cfa_native
```

Type commands on stdin (one per line):

| Command | Effect |
|---------|--------|
| `noop` | Accept NOOP, tick once, print noop counter |
| `sample` | Accept sample command, tick once, print sample counter |
| `status` | Print housekeeping (mission time, tick, counters, short event tail) |
| `help` | List commands |
| `quit` | Exit |

Unknown lines are rejected without crashing. Between commands the program advances `Cfa.Tick`, yields (~20 ms), and prints housekeeping about twice per second.

Example:

```bash
printf 'status\nnoop\nstatus\nquit\n' | ./bin/cfa_native
```

Version stamp matches the browser (`Cfa.Api.Version_String`).
