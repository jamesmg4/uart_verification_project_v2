# UART Verification Project

## Overview

I built this UART transmitter, receiver, and verification environment in SystemVerilog as my first independent RTL project after taking digital design courses. I started with 8N1 framing, then added configurable data width and optional even or odd parity. The design is verified in simulation with directed tests, randomized loopback transfers, error injection, and a configuration matrix.

## Repository Structure

- `rtl/uart_tx.sv` and `rtl/uart_rx.sv` contain the transmitter and receiver.
- `tb/uart_tx_tb.sv` and `tb/uart_rx_tb.sv` test the modules individually.
- `tb/uart_loopback_tb.sv` connects TX to RX for end-to-end tests.
- `scripts/run_uart_matrix.sh` runs the automated configuration matrix through `make test-matrix`.
- `rtl/subModules/` and `tb/subModules_tb/` contain earlier counter and shift-register exercises.

## UART Frame Format

The serial line is high when idle. A frame contains one low start bit, `DATA_BITS` data bits sent least-significant bit first, an optional parity bit, and one high stop bit. The receiver checks the start bit near its midpoint, then samples subsequent bits at the configured bit interval.

| Parameter | Purpose | Default |
| --- | --- | ---: |
| `CLK_SPEED` | Input clock frequency | `100` |
| `BAUD_RATE` | UART baud rate | `10` |
| `DATA_BITS` | Data bits per frame | `8` |
| `PARITY_ENABLE` | Include a parity bit | `0` |
| `PARITY_ODD` | Select odd parity; `0` selects even parity | `0` |

The implementation uses integer division for `CLK_SPEED / BAUD_RATE`, so choose an appropriate integer number of clocks per bit. The transmitter and receiver must use the same parameters.

## Transmitter

The TX state machine has five states: `IDLE`, `START`, `DATA`, `PARITY`, and `STOP`. Its baud counter sets the duration of each bit, while a bit counter tracks progress through the data field.

When `tx_start` is accepted in `IDLE`, TX captures `tx_data` and calculates its parity bit. This means changing the input data during a frame does not change the transmitted value. `tx_busy` is high throughout the active frame. A `tx_start` request while busy is ignored because this design has no request queue or FIFO; simulation reports that interface misuse.

The standalone TX testbench checks serial bits, parity, requests while busy, and reset during transmission. Simulation-only assertions check idle-line behavior and counter ranges.

## Receiver

The RX state machine uses the same five frame phases. It checks that a detected low start bit is still low near the midpoint, then samples data bits, optional parity, and the stop bit.

`rx_data` holds the received data. `rx_valid` pulses for one clock after a frame with a valid stop bit. `parity_error` pulses when an enabled parity check fails, and `framing_error` pulses when the stop bit is low. `rx_busy` is high while a frame is being received. A parity error can coincide with `rx_valid` if the stop bit is valid.

The standalone RX testbench checks received data, corrupted parity, invalid stop bits, and reset during reception. Simulation-only assertions check the `rx_valid` pulse width and counter ranges.

## Loopback Verification

The loopback testbench connects the TX output directly to the RX input and checks the received data and error signals. Its tests include:

- Known patterns: `00`, `FF`, `55`, `AA`, and `92` (truncated to the configured data width).
- Randomized transfers.
- A request made while TX is busy, which must be ignored.
- Changing `tx_data` during a frame to verify that TX captured the original value.
- Reset during a transfer, followed by a successful transfer after recovery.

The separate RX testbench injects parity and framing errors. The configuration matrix runs all loopback tests, including the busy-request test, with 25 randomized transfers per configuration. TX reports an ignored busy request as a warning because the test intentionally sends one.

## Planned Improvements

- Synchronize the external RX input and add oversampling.
- Support configurable stop-bit counts.
- Add FIFO buffering and hardware flow control.
- Add functional coverage and FPGA hardware testing.
