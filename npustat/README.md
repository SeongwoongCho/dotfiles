`npustat`
=========

A unified monitoring tool for NVIDIA GPUs and Mobilint NPUs.

Based on [gpustat](https://github.com/wookayin/gpustat) by Jongwook Choi.

Quick Installation
------------------

Install in development mode:

```bash
pip install -e .
```

Requirements
------------

### NVIDIA GPU Support

- Requires `nvidia-ml-py >= 12.535.108`
- NVIDIA Driver **450.00** or higher

### Mobilint NPU Support

- Requires the `mbltml` bindings (`pip install mbltml`, Linux only)
- Mobilint SDK with proper drivers installed

NPU status is read straight from `mbltml`, Mobilint's monitoring library and
the same one `mblt-status` and `mblt-tracker` are built on. No CLI output is
parsed, so vendor changes to `mobilint-cli`'s table layout cannot break it.


Usage
-----

```bash
$ npustat
```

**Example output:**

```
cce2fabef351                        Wed Dec 10 14:35:47 2025  GPU:580.95.05  NPU:Aries:1.13.0(Rev:1)
[G0] NVIDIA RTX 6000 Ada Generation | 32°C,   0 % |    14 / 46068 MB |
[G1] NVIDIA RTX 6000 Ada Generation | 81°C,  97 % | 27004 / 46068 MB | root(26982M)
[N0] Aries(aries0)                  | 46°C,   8 % |   426 / 16384 MB | root(426M)
    └─ Cluster0: G  0.0% c0 67.6% c1  0.0% c2  0.0% c3  0.0%
    └─ Cluster1: G  0.0% c0  0.0% c1  0.0% c2  0.0% c3  0.0%
```

Options
-------

### General Options

| Option | Description |
|--------|-------------|
| `--color` | Force colored output (even when stdout is not a tty) |
| `--no-color` | Suppress colored output |
| `-u`, `--show-user` | Display username of the process owner |
| `-c`, `--show-cmd` | Display the process name |
| `-f`, `--show-full-cmd` | Display full command and cpu stats of running process |
| `-p`, `--show-pid` | Display PID of the process |
| `-F`, `--show-fan` | Display GPU fan speed |
| `-e`, `--show-codec` | Display encoder and/or decoder utilization |
| `-P`, `--show-power` | Display power usage and/or limit |
| `-a`, `--show-all` | Display all properties above |
| `--id` | Target specific GPUs by index (e.g., `--id 0,1,2`) |
| `--no-processes` | Do not display process information |
| `-i`, `--interval`, `--watch` | Run in watch mode with specified interval |
| `--json` | JSON output |
| `--no-header` | Suppress header message |
| `-v`, `--version` | Show version |

### NPU Options

| Option | Description |
|--------|-------------|
| `-n`, `--no-npu` | Hide NPU status (NPU is shown by default) |
| `--npu-only` | Only display NPU status (hide GPU) |
| `--npu-clock` | Display NPU clock frequencies |
| `--npu-extra` | Display chip, firmware, PCIe and power rail details |
| `--no-npu-core-status` | Hide per-cluster, per-core utilization |

### Scheduler Options

| Option | Description |
|--------|-------------|
| `-S`, `--no-scheduler` | Hide the shared compute pool's reservations (shown by default, see below) |
| `-s`, `--scheduler` | Report an unreachable master instead of silently skipping the section |


Display Format
--------------

### GPU Display

```
[G0] GeForce GTX Titan X | 77°C,  96 % | 11848 / 12287 MB | python/52046(11821M)
```

- `[G0]`: GPU index (G = GPU)
- `GeForce GTX Titan X`: GPU name
- `77°C`: Temperature (Celsius)
- `96 %`: GPU Utilization
- `11848 / 12287 MB`: Memory Usage (Used / Total)
- `python/...`: Running processes (owner/cmdline/PID and GPU memory usage)

### NPU Display

```
[N0] Aries(aries0) | 46°C,   8 % |   426 / 16384 MB | root(426M)
    └─ Cluster0: G  0.0% c0 67.6% c1  0.0% c2  0.0% c3  0.0%
    └─ Cluster1: G  0.0% c0  0.0% c1  0.0% c2  0.0% c3  0.0%
```

- `[N0]`: NPU index (N = NPU)
- `Aries(aries0)`: device family and device node
- `46°C`: Temperature (Celsius)
- `8 %`: NPU Utilization
- `426 / 16384 MB`: Memory Usage (Used / Total)
- `root(426M)`: Running processes (owner and NPU memory usage)
- `Cluster0`: per-cluster utilization; `G` is the cluster's global core,
  `c0`–`c3` its individual cores. Hide with `--no-npu-core-status`.

Process owners resolve to `?` when the NPU driver reports host PIDs that the
current PID namespace cannot see (e.g. inside a container). `mblt-status`
reports the same processes as `Not Found` in that situation.

### With Extra Details (`--npu-extra`)

```
[N0] Aries(aries0) | 46°C,   8 % |   426 / 16384 MB | root(426M)
    ├─ Aries2 fw 1.1 (Rev: 0) | crc 0xFB9A5980 | signal Interrupt | PCIe Gen4 x8 | NPU rail 6.95W | total 1.37A 12.18V
```

### With Power Option (`-P`)

```
[G0] NVIDIA RTX 6000 Ada Generation | 32°C,   0 %,   21 / 300 W |    14 / 46068 MB |
[N0] Aries(aries0)                  | 46°C,   8 %,    7.0 /  16.7 W |   426 / 16384 MB |
```

The first power figure is the NPU rail, the second the board total. Only one
extra PMIC rail is sampled by firmware at a time, so the rail figure is shown
only while the NPU rail is the selected one.


### Scheduler Display

```
── scheduler ── 12/16 nodes open · 10 running · 0 queued ── reserved / total ──────
  Total        | CPU   98/1316   7% | MEM  392/3811 GB  10% | GPU  1/30 | NPU  4/22  incl. 4 closed
  Available    | CPU  698/796   88% | MEM 1783/2175 GB  82% | GPU 15/16 | NPU 14/18
  ─────────────┼────────────────────┼───────────────────────┼───────────┼──────────
  server102    | CPU    8/64    12% | MEM   16/ 503 GB   3% | GPU -     | NPU  1/3   1 job
  server150    | CPU    0/96     0% | MEM    0/ 378 GB   0% | GPU  0/2  | NPU  0/1   closed for work hours until 22:00
```

How busy the pool behind `scheduler-cli` is. Every figure is a *reservation*
(what jobs hold), not live utilisation. Shown by default; when the master
cannot be reached the section is silently skipped (`-s` or `--debug` says why).

- `Total`: reserved / total over every host, the same sums as `scheduler-cli usage`.
  Hosts that take no jobs right now are counted too, which the row says
  (`incl. 4 closed`).
- `Available`: unreserved / capacity on hosts that accept a job right now, i.e.
  excluding hosts that are closed, cordoned or not answering (shown dimmed).
- One row per host, ending in its running job count or why it is not open.
- Queued jobs are listed underneath with what they asked for.

When the screen is too small for one row per host (under `watch`, or in
watch mode), the hosts are laid out compactly, side by side, in as many
columns as it takes to fit:

```
── scheduler ── 12/16 nodes open · 16 running · 5 queued ── reserved / total ────────────────────────────────
                CPU       MEM GB    GPU   NPU          │               CPU       MEM GB    GPU   NPU
  Total         174/1316  840/3811  5/30  7/22  incl. 4 closed
  Available     622/796  1335/2175  11/16 11/18
  ─────────────────────────────────────────────────────┼─────────────────────────────────────────────────────
  beomsu          6/20     24/31    -     1/4   1 job  │ server200      64/96    160/251   0/3   -     2 jobs
  server150       0/96      0/378   0/2   0/1   closed │ server61        8/32     64/252   1/2   -     1 job
```

The percentages go (the colour still tells the load), and so does the state
after each host when that is what lets one more column in. Piped elsewhere,
the full table is always printed.

Host capacities are read from the master's `/nodes` JSON; job counts come from
`scheduler-cli ps --json` (0.1.0 or newer) and are left out without it. Answers
are reused for 5 seconds, so `watch -n.5 npustat` does not query the master
twice a second.

| Environment variable | Default | Meaning |
|----------------------|---------|---------|
| `NPUSTAT_SCHEDULER_ENDPOINT` | `https://scheduler.mobilint.com/adm` | The master to ask |
| `NPUSTAT_SCHEDULER_TTL` | `5` | Seconds an answer is reused; `0` disables the cache |


Examples
--------

```bash
# Show GPU and NPU (default)
npustat

# Show GPU only
npustat -n
npustat --no-npu

# Show NPU only
npustat --npu-only

# Show with power consumption
npustat -P

# Show with NPU clock frequencies
npustat --npu-clock

# Show NPU chip, firmware, PCIe and power rail details
npustat --npu-extra

# Show all details
npustat -a

# Hide the shared compute pool's reservations
npustat -S

# Watch mode (update every 1 second)
npustat -i 1

# JSON output
npustat --json
```


Behavior without NPU/GPU
------------------------

### When `mbltml` or a Mobilint driver is not available

- **Default mode (`npustat`)**: Automatically shows GPU only, NPU section is silently skipped.
- **With `--npu-only`**: Shows error message and exits with code 1.
- **With `--debug`**: Shows "NPU query skipped" message with the reason.

```bash
# If mbltml is missing or no NPU is present:
$ npustat              # Shows GPU only (no error)
$ npustat --npu-only   # Error, exits 1
$ npustat --debug      # Shows GPU + debug message about NPU
```

### When NVIDIA driver is not available

- **Default mode**: Shows error and exits (unless `--no-npu` is not set and NPU is available).
- **With `--npu-only`**: Shows NPU only, no GPU error.

```bash
# If NVIDIA driver is not available:
$ npustat              # Error (no GPU)
$ npustat --npu-only   # Shows NPU only (no error)
```


Tips
----

- Use `npustat --debug` if something goes wrong.
- Use `npustat -i` or `npustat --watch` for continuous monitoring.
- Use `npustat -n` or `npustat --no-npu` if you don't have Mobilint NPU installed.
- Running `nvidia-smi daemon` (root privilege required) will make GPU queries faster.
- Set `CUDA_DEVICE_ORDER=PCI_BUS_ID` to ensure CUDA and npustat use the same GPU indices.


License
-------

[MIT License](LICENSE)


Credits
-------

- Original [gpustat](https://github.com/wookayin/gpustat) by Jongwook Choi
- NPU support for Mobilint devices
