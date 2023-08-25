#!/usr/bin/env python3


import asyncio
import contextlib
import math
import time

import aiohttp.web

from pymodbus.client.serial import AsyncModbusSerialClient as ModbusClient
from pymodbus.register_read_message import ReadInputRegistersResponse


# =====
class _InvalidModbusResponse(Exception):
    pass


@contextlib.asynccontextmanager
async def _connected(device_path: str) -> ModbusClient:
    async with ModbusClient(
        method="rtu",
        port=device_path,
        baudrate=9600,
        stopbit=1,
        bytesize=8,
        parity="N",
        timeout=1,
    ) as modbus:
        yield modbus


async def _read_stats(modbus: ModbusClient, addr: int, slave: int) -> dict[str, float]:
    resp = await modbus.read_input_registers(addr, 10, slave)
    if not isinstance(resp, ReadInputRegistersResponse):
        raise _InvalidModbusResponse(f"{type(resp).__name__}: {resp}")
    power_real = (resp.registers[3] | resp.registers[4] << 16) * 0.1
    power_factor = resp.registers[8] * 0.01
    power_angle = math.acos(power_factor)
    if power_factor > 0:
        power_full = power_real / power_factor
        power_reactive = power_full * math.sin(power_angle)
    else:
        power_full = power_reactive = 0.0
    return {
        "voltage": round(resp.registers[0] * 0.1, 3),
        "current": round((resp.registers[1] | resp.registers[2] << 16) * 0.001, 3),
        "freq": round(resp.registers[7] * 0.1, 3),
        "power_real": round(power_real, 3),
        "power_factor": round(power_factor, 3),
        "power_angle": round(power_angle, 3),
        "power_full": round(power_full, 3),
        "power_reactive": round(power_reactive, 3),
    }


# =====
_lock = asyncio.Lock()


async def _stats_handler(_: aiohttp.web.Request) -> aiohttp.web.Response:
    async with _lock:
        async with _connected("/dev/ttyUSB0") as modbus:
            stats: dict = {"ts": time.time(), "phases": {}}
            for (phase, slave) in [("L1", 1), ("L2", 2), ("L3", 3)]:
                try:
                    stats["phases"][phase] = await _read_stats(modbus, 0, slave)
                    asyncio.sleep(0.05)
                except Exception as err:
                    print(f"{phase} error: {type(err).__name__}: {err}")
                    stats["phases"][phase] = None
            return aiohttp.web.json_response(stats)


def main() -> None:
    app = aiohttp.web.Application()
    app.add_routes([aiohttp.web.get("/stats", _stats_handler)])
    aiohttp.web.run_app(app, host="0.0.0.0", port=80)


if __name__ == "__main__":
    main()
