# UART Verification Project

## Goal

Implement and verify a UART controller using SystemVerilog.

## Configuration

- 8N1
- 115200 baud
- No parity
- 1 stop bit

## RTL Modules

### uart_tx.sv

States:
- IDLE
- START
- DATA
- STOP

Internal Logic:
- FSM
- baud_counter
- bit_counter
- shift_register

### uart_rx.sv

States:
- IDLE
- START
- DATA
- STOP

## Verification

- Directed tests
- Self-checking testbench
- Assertions
- Scoreboard
- Coverage (later)

## Open Questions

- Add parity?
- Configurable stop bits?
- Oversampling in RX?