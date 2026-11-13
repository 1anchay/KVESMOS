"""Capture the Android integration demo on the dedicated 1.1 emulator."""
import argparse
from pathlib import Path
import re
import subprocess
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--adb', type=Path, required=True)
parser.add_argument('--serial', default='emulator-5556')
parser.add_argument('--out', type=Path, default=Path('test-output/v11-native'))
args = parser.parse_args()
adb = [str(args.adb.resolve()), '-s', args.serial]

def device(*command):
    return subprocess.check_output(adb + list(command), timeout=25)

assert device('shell', 'getprop', 'ro.kernel.qemu').strip() == b'1'
assert device('shell', 'getprop', 'ro.boot.qemu.avd_name').strip() == b'KVESMOS11_QA'
args.out.mkdir(parents=True, exist_ok=True)
logcat = subprocess.Popen(adb + ['logcat', '-T', '1', '-s', 'KVESMOS11:I'], stdout=subprocess.PIPE)
video = None
try:
    for raw in logcat.stdout:
        line = raw.decode('utf-8', errors='replace').strip()
        if 'KVESMOS11: ' not in line:
            continue
        message = line.split('KVESMOS11: ', 1)[1]
        print(message, flush=True)
        if message.startswith('CAPTURE:'):
            name = message.split(':', 1)[1]
            assert re.fullmatch('[a-z0-9-]+', name)
            time.sleep(.25)
            (args.out / f'{name}.png').write_bytes(device('exec-out', 'screencap', '-p'))
        elif message.startswith('VIDEO_START:'):
            video = subprocess.Popen(adb + ['shell', 'screenrecord', '--bit-rate', '1500000',
                                            '--time-limit', '180', '/sdcard/kvesmos11.mp4'])
        elif message.startswith('VIDEO_DONE:') and video is not None:
            language = message.split(':', 1)[1]
            assert language in {'en', 'zh'}
            pid = subprocess.run(adb + ['shell', 'pidof', 'screenrecord'], capture_output=True).stdout.decode().strip()
            if pid.isdigit():
                device('shell', 'kill', '-2', pid)
            video.wait(timeout=25)
            device('pull', '/sdcard/kvesmos11.mp4', str(args.out / f'cycle-{language}.mp4'))
            video = None
        elif message == 'DONE':
            break
finally:
    logcat.terminate()
    if video is not None:
        video.terminate()
