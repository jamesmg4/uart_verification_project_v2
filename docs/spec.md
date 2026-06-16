## TX Start Behavior

The transmitter only accepts `tx_start` when `tx_busy` is low.

If `tx_start` is asserted while `tx_busy` is high, the request is ignored.

Future versions may add a FIFO so bytes can be queued while the transmitter is busy.