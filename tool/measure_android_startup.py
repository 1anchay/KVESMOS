"""Bounded read-only comparison on the explicitly named QA emulator.

Measures Android Activity launch (not Flutter first meaningful paint), five
force-stop launches after one warmup. Never clears storage or changes settings.
"""
import argparse
import json
from pathlib import Path
import re
import statistics
import subprocess
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--adb', type=Path, required=True)
    parser.add_argument('--serial', required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--mode', default='debug x64; API 36; SwiftShader; 720x1600 at 320 dpi; 2 cores/1536MB',
                        help='Actual device/build configuration, recorded with measurements')
    args = parser.parse_args()

    def device(*command):
        return subprocess.check_output(
            [str(args.adb.resolve()), '-s', args.serial, *command],
            text=True, encoding='utf-8', errors='replace')

    assert device('shell', 'getprop', 'ro.kernel.qemu').strip() == '1', 'QA emulator only'
    assert device('shell', 'getprop', 'sys.boot_completed').strip() == '1', 'Wait for boot'
    package = 'dev.orbitwords.orbitwords'
    info = device('shell', 'dumpsys', 'package', package)
    version = re.search(r'versionName=(\S+)', info).group(1)
    samples = []
    for _ in range(6):
        device('shell', 'am', 'force-stop', package)
        time.sleep(1)
        result = device('shell', 'am', 'start', '-W', '-n', package + '/.MainActivity')
        samples.append(int(re.search(r'TotalTime:\s*(\d+)', result).group(1)))
        time.sleep(4)
    memory = device('shell', 'dumpsys', 'meminfo', package)
    pss = re.search(r'TOTAL PSS:\s*(\d+)', memory)
    report = {
        'version': version, 'serial': args.serial,
        'metric': 'Android Activity launch TotalTime; not Flutter first meaningful paint',
        'mode': args.mode,
        'warmupMs': samples[0], 'samplesMs': samples[1:],
        'medianMs': statistics.median(samples[1:]),
        'pssKbAfterLastLaunch': int(pss.group(1)) if pss else None,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report))


if __name__ == '__main__':
    main()
