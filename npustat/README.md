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

- Requires `mobilint-cli` to be installed and accessible in PATH
- Mobilint SDK with proper drivers installed


Usage
-----

```bash
$ npustat
```

**Example output:**

```
cce2fabef351                        Wed Dec 10 14:35:47 2025  GPU:580.95.05  NPU:Aries2:1.9.0
[G0] NVIDIA RTX 6000 Ada Generation | 32°C,   0 % |    14 / 46068 MB |
[G1] NVIDIA RTX 6000 Ada Generation | 81°C,  97 % | 27004 / 46068 MB | root(26982M)
[N0] Aries2(aries0)                 | 38°C,   0 % |     0 / 16384 MB |
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
| `--no-npu-core-status` | Hide per-core status for NPU |


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
[N0] Aries2(aries0) | 38°C,   0 % |     0 / 16384 MB |
```

- `[N0]`: NPU index (N = NPU)
- `Aries2(aries0)`: NPU name
- `38°C`: Temperature (Celsius)
- `0 %`: NPU Utilization
- `0 / 16384 MB`: Memory Usage (Used / Total)

### With Power Option (`-P`)

```
[G0] NVIDIA RTX 6000 Ada Generation | 32°C,   0 %,   21 / 300 W |    14 / 46068 MB |
[N0] Aries2(aries0)                 | 38°C,   0 %,    3.9 /  12.7 W |     0 / 16384 MB |
```


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

# Show all details
npustat -a

# Watch mode (update every 1 second)
npustat -i 1

# JSON output
npustat --json
```


Behavior without NPU/GPU
------------------------

### When `mobilint-cli` is not installed

- **Default mode (`npustat`)**: Automatically shows GPU only, NPU section is silently skipped.
- **With `--npu-only`**: Shows error message and exits with code 1.
- **With `--debug`**: Shows "NPU query skipped" message with the reason.

```bash
# If mobilint-cli is not installed:
$ npustat              # Shows GPU only (no error)
$ npustat --npu-only   # Error: mobilint-cli not found
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
