# UART Verification Project

## Overview
This is my UART verification project where I will make a UART transmitter/reciever in verilog. After doing some digital design courses at school, I wanted to start with something managable for my first system verilog solo project. 

The UART format I chose to simulate is a simple 8N1 framing configuration.
TODO: add picture of configuration

In this configuration, the frame starts with a single start bit which transitions to 8 data bits, then finally goes into a stop bit. More specifics on how the protocol is implemented is in the UART Frame Format section.
## Repo Structure
rtl/ has the design of the tx and rx in system verilog

tb/ has the testbenches of tx, rx, and them both integrated

docs/ has some notes that I have marked down about specific module behavior and lessons learned
## UART Frame Format
Here are some quick things about the UART Frame I have implemented:
* TX is held at an idle high, and when pulled to low the tranmission will start
* The first bit of the frame is a start bit. This bit will always will need to be read as low for the transmission to continue
* The next 8 bits are data bits. The least significant bits will come first, and read on every BAUD tick
* The last bit is the stop bit which transitions back to high.

## TX
### Design
There are 4 states of the transmission module:
* IDLE
* START
* DATA
* STOP


The TX module has a BAUD counter for the system to know when there should be a BAUD tick. Whenever the BAUD counter gets to the set number, it will acitivate a BAUD tick so that the transmission goes to the next state or data bit.

A couple signals determine the state of the tranmission. "tx_start" signals from the controller it wants to send some data. This sends the tx signal line low, and transitions the "tx_busy" state to true. In this implementation, a "tx_busy" state is used to let the controller know that there is already a tranmission going on. 

"tx_data" is an 8 bit register that is loaded in parallel to the tx module so that it can send the data to the receiver. This module loads all TX data at the start of the transmission

### Verfication


## RX
### Design

There are 4 states of the transmission module:
* IDLE
* START
* DATA
* STOP

When the recevier detects the transmission line goes low, the IDLE state goes to START. Once in the START state, the receiver checks the transmission line after half the BAUD time to make sure the line still low. This verifies that the line didn't just flicker low, and actually wants to transmit data.

The RX module has a BAUD counter for the system to know when there should be a BAUD tick. Whenever the BAUD counter gets to the set number, it will acitivate a BAUD tick so that the transmission goes to the next state or data bit. The BAUD counter in this module is implemented so that the reciver will read the data line between the BAUD ticks of the transceiver.

"rx_valid" is an output signal that goes high when transmission is complete.
### Verfication

## Loopback Testbench

## Results
add waveforms of images of passed test cases
## Planned Improvements
- Parity bit
- Framing-error detection
- Oversampling receiver
- Configurable stop bits
- Configurable data widths
- FIFO buffering
- FPGA hardware test
