#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/uart-matrix.XXXXXX")"
trap 'rm -rf "${build_dir}"' EXIT

# name:data_bits:parity_enable:parity_odd:clock_speed:baud_rate
configurations=(
    "8n:8:0:0:100:10"
    "8e:8:1:0:100:10"
    "8o:8:1:1:100:10"
    "7e:7:1:0:160:10"
    "7o:7:1:1:120:10"
    "5n:5:0:0:80:10"
    "1o:1:1:1:40:10"
)

passed=0

for configuration in "${configurations[@]}"; do
    IFS=: read -r name data_bits parity_enable parity_odd clock_speed baud_rate <<< "${configuration}"
    simulation="${build_dir}/${name}.sim"
    log="${build_dir}/${name}.log"

    printf 'Running %-3s: DATA_BITS=%s parity_enable=%s parity_odd=%s clocks_per_bit=%s\n' \
        "${name}" "${data_bits}" "${parity_enable}" "${parity_odd}" "$((clock_speed / baud_rate))"

    iverilog -g2012 -s uart_loopback_tb \
        -P "uart_loopback_tb.DATA_BITS=${data_bits}" \
        -P "uart_loopback_tb.PARITY_ENABLE=${parity_enable}" \
        -P "uart_loopback_tb.PARITY_ODD=${parity_odd}" \
        -P "uart_loopback_tb.CLK_SPEED=${clock_speed}" \
        -P "uart_loopback_tb.BAUD_RATE=${baud_rate}" \
        -P uart_loopback_tb.RANDOM_TESTS=25 \
        -P uart_loopback_tb.RUN_BUSY_TEST=1 \
        -P uart_loopback_tb.DUMP_WAVES=0 \
        -o "${simulation}" \
        "${project_dir}/rtl/uart_tx.sv" \
        "${project_dir}/rtl/uart_rx.sv" \
        "${project_dir}/tb/uart_loopback_tb.sv"

    if ! vvp "${simulation}" >"${log}" 2>&1; then
        printf 'FAIL: simulation process failed for %s\n' "${name}"
        sed -n '1,240p' "${log}"
        exit 1
    fi

    if grep -Eq 'ERROR:|FATAL:' "${log}"; then
        printf 'FAIL: assertion or fatal error in %s\n' "${name}"
        grep -E 'ERROR:|FATAL:' "${log}"
        exit 1
    fi

    printf 'PASS: %s\n' "${name}"
    passed=$((passed + 1))
done

printf 'UART configuration matrix passed: %d/%d configurations\n' "${passed}" "${#configurations[@]}"
