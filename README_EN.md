# ZYNQ7020 Signal Processing System

This project targets the ZYNQ7020 CLG400-1 and contains board acquisition, playback, PL stream processing, AXI DMA, and a bare metal PS application. The Vivado Block Design and board links have been verified on the target hardware.

## Modular algorithm slot

The main data path contains a stable `slot` wrapper. The algorithm implementation lives in `ACM2108use.srcs/sources_1/modules/user.v`. Replace the logic inside `user` while keeping its module name and ports. The Block Design, DMA, clock, reset, and address map remain unchanged.

The contract provides:

1. A 32 bit AXI4 Stream input and output with `tvalid`, `tready`, and `tlast`.
2. Eight 32 bit configuration words named `cfg0` through `cfg7`.
3. One 32 bit `status` result.
4. A software controlled reset and bypass path.

The default implementation is a lossless pass through.

Run the complete hardware build after replacing the algorithm:

```powershell
vivado -mode batch -source build.tcl
```

This command validates the Block Design, runs synthesis and implementation, writes the bitstream, and updates `structure.xsa`.

## PS interface

The matching C API is in `vitisV2/SignalAPP_V1_2/src/hal/slot.h`.

```c
slot_t alg;

slot_init(&alg, SLOT_BASE);
slot_set(&alg, 0, 1000U);
slot_reset(&alg);
slot_run(&alg);

u32 state = slot_status(&alg);
```

The slot base address is `0x40030000`. It starts in bypass mode after reset.

## Signal application

`SignalAPP_V1_2` is the current verified application. It provides 35 MSPS ADC0 acquisition, a 511 tap low pass filter, 7 times decimation, a 16384 point FFT, periodic signal analysis from 5 kHz to 800 kHz, detection of up to three harmonic components, peak to peak voltage, true RMS, THD, waveform display, and spectrum display.

Rebuild the platform and application with Vitis Command Line Tool 2025.2:

```powershell
vitis -s tools/build_signalapp_v1_2.py
```

The script creates the `Signal_V1_2` standalone platform from `structure.xsa`, builds the BSP and FSBL, then creates and builds `SignalAPP_V1_2`. Generated files remain under the ignored `build/vitis` directory.

## Toolchain

1. Vivado 2025.1 for hardware design, synthesis, implementation, bitstream, and XSA export.
2. Vitis Command Line Tool 2025.2 for platform, BSP, FSBL, and application builds.
3. Target part `xc7z020clg400-1`.

## Repository layout

| Path | Content |
| --- | --- |
| `ACM2108use.xpr` | Vivado project |
| `ACM2108use.srcs/sources_1/bd/system/system.bd` | Main Block Design |
| `ACM2108use.srcs/sources_1/modules/slot.v` | Stable algorithm wrapper |
| `ACM2108use.srcs/sources_1/modules/user.v` | Replaceable algorithm implementation |
| `vitisV2/SignalAPP_V1_2/src` | Verified periodic signal application |
| `vitisV2/SignalAPP_V1_2/tests` | Host regression tests |
| `vitisV2/SignalAPP_V1_2/src/hal/slot.h` | PS control API |
| `tools/build_signalapp_v1_2.py` | Platform and application rebuild script |
| `build.tcl` | Reproducible hardware build and XSA export |
| `structure.xsa` | Hardware platform with bitstream |

The internal directory name `ACM2108use` is retained from board validation to keep Vivado paths and IP configuration stable. It is only an internal project identifier and does not name the GitHub repository.

## Open the project

```powershell
vivado ACM2108use.xpr
```

Use the root `structure.xsa` to create a standalone platform. The application sources are under `vitisV2/SignalAPP_V1_2/src`.

## Verification

| Check | Result |
| --- | --- |
| AXI4 Stream pass through, backpressure, and `tlast` simulation | Passed |
| Vivado 2025.1 synthesis, implementation, DRC, and bitstream | Passed with 0 errors and 0 critical warnings |
| Implemented timing | WNS 0.525 ns and TNS 0 ns |
| `structure.xsa` | Updated with bitstream and `alg_slot` |
| Vitis 2025.2 `Signal_V1_2` platform, BSP, and FSBL | Rebuilt successfully from the current XSA |
| Vitis 2025.2 `SignalAPP_V1_2` | Built successfully with `slot.c` |
| Signal application host regression tests | All 6 tests passed |

## License

Released under the [MIT License](LICENSE). Generated AMD sources and third party components remain subject to their embedded notices.
