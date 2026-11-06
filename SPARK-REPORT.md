# Core Flight Ada — SPARK / GNATprove report (Item 10)

Date: 2026-11-06 (Europe/Berlin)  
Tool: GNATprove **FSF 16.1.0** (Alire GNAT-FSF-builds  
`gnatprove-x86_64-linux-16.1.0-1`), with Alt-Ergo 2.6.1 / cvc5 1.3.2 / Z3 4.15.4.  
Installed under `toolchain/gnatprove-x86_64-linux-16.1.0-1/` (not from apt;  
`command -v gnatprove` was empty before this install).

## How to reproduce

```bash
export PATH="$PWD/toolchain/gnatprove-x86_64-linux-16.1.0-1/bin:$PATH"
gnatprove -P cfa.gpr -U -j0 --level=2 --timeout=45 --report=all -k
# Summary: obj/gnatprove/gnatprove.out
gprbuild -p -P cfa.gpr   # still required; assertions stay Check on native
```

## SPARK_Mode policy

| Unit | Mode | Reason |
|------|------|--------|
| Cfa.Types, Bus, Events, Time, Schedule, Executive, Cmd, Sample, Tlm, Tables, Boot | **On** | Core flight logic |
| Cfa (spec On; Tick **Off**; body Auto) | Mixed | `Tick` samples `Platform.Clock` |
| Cfa.Platform | **Off** | Ada.Real_Time clock/delay, Text_IO / browser clock |
| Cfa.Api | **Off** | C Export / WASM glue, Interfaces, System.Address |
| Cfa.Visual | **Off** | `System.Address` frame pointer for WASM blit |
| cfa_driver, cfa_native | Off (ordinary mains) | Call the core; not proved |

No `pragma Annotate (GNATprove, Intentional, …)` anywhere.

## Aggregate results (level=2, timeout=45s, `-U`)

From `obj/gnatprove/gnatprove.out`:

| Category | Total | Flow | Provers | Unproved |
|----------|------:|-----:|--------:|---------:|
| Initialization | 92 | 92 | — | 0 |
| Run-time checks | 94 | — | 92 | **2** |
| Assertions | 58 | — | 44 | **14** |
| Functional contracts | 40 | — | 34 | **6** |
| Termination | 44 | 44 | — | 0 |
| **All** | **328** | **136 (41%)** | **170 (52%)** | **22 (7%)** |

Proved by provers + flow: **306 / 328 (93%)**. Unproved left **unproved** (not justified).

## By unit (honest)

### Fully proved (flow + all checks)

- **Cfa.Types** — package
- **Cfa.Cmd** — all subprograms
- **Cfa.Events** — Count, Entry_At, Write (all checks)
- **Cfa.Time** — Mission_Time_Ms, Monotonic_Tick, Advance
- **Cfa.Sample** — Bind, Reset_Counters, Start_Subscriptions, Run_Slice, getters
- **Cfa.Bus** — Publish, Receive, Enqueue/Dequeue, Overflow_Count, Pending, …  
  (see partials below for Subscribe / Last_Overflow)

### Partial / unproved checks remain

| Subprogram | Proved / total checks | Notes |
|------------|----------------------:|-------|
| Cfa.Boot.Start_First_Slice | 1 / 6 | Asserts after Register/Start |
| Cfa.Bus.Last_Overflow | 0 / 1 | Post on Event_Shape when Valid |
| Cfa.Bus.Subscribe | 3 / 4 | Post `Has_Subscription` |
| Cfa.Executive.Start | 1 / 3 | Failure-branch post |
| Cfa.Executive.Restart | 4 / 5 | Sample.Reset coupling |
| Cfa.Executive.Run_Slice | 1 / 3 | Pre of Sample/Tlm.Run_Slice |
| Cfa.Schedule.Bind | 7 / 8 | One remaining assert/post |
| Cfa.Tables.Install_Defaults | 6 / 7 | Elaboration / default write asserts |
| Cfa.Tlm.Bind | 1 / 2 | Post Is_Bound |
| Cfa.Tlm.Run_Slice | 42 / 49 | HK encode path asserts / indices |

### Intentionally not analyzed as SPARK

- **Cfa.Tick** — Off (Platform.Clock)
- **Cfa.Current_Tick** — skipped with Auto body that withs Platform (logic is `Time.Monotonic_Tick`, which is proved)
- **Cfa.Platform / Api / Visual** — Off with written reasons
- **Mains** — ordinary Ada

## Deviations (Item 10)

- `Cfa.Types.Milliseconds` moved out of Platform so SPARK units can use the type while Platform stays Off.
- Expression functions + private state for Sample / Events.Count / Executive getters / Time getters (SPARK visibility, not a design rewrite).
- `Cfa.Tick` SPARK_Mode Off; package body `Auto` because of Platform.
- GNATprove binary vendored under `toolchain/` (FSF 16.1.0), not distro-packaged.
- Native assertions remain `Assertion_Policy (Check)`; WASM path still uses Ignore as in Item 7.

## Native build check

`gprbuild -p -P cfa.gpr` → `Cfa_Driver: OK`; `cfa_native` still builds.

This report is **not** a claim of flight certification or NASA affiliation.
