"""Native QA capture companion. Start before the dedicated integration test.

python tool/qa_languages_companion.py --sdk .tools/android-sdk --serial emulator-5554
Confirms the widget pin dialog ONLY on an emulator. Does not install/clear apps.
Output: test-output/v011-native. Screen recording contains no audio.
"""
import argparse
import json
import re
import subprocess
import time
import xml.etree.ElementTree as ET
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--sdk', type=Path, required=True)
parser.add_argument('--serial', required=True)
parser.add_argument('--output', type=Path, default=Path('test-output/v011-native'))
args = parser.parse_args()
adb = args.sdk / 'platform-tools' / ('adb.exe' if __import__('os').name == 'nt' else 'adb')
command = [str(adb.resolve()), '-s', args.serial]


def dev(*values):
    return subprocess.check_output(command + list(values), timeout=20)


assert args.serial.startswith('emulator-')
assert dev('shell', 'getprop', 'ro.kernel.qemu').strip() == b'1'
args.output.mkdir(parents=True, exist_ok=True)


def nodes():
    dev('shell', 'uiautomator', 'dump', '/data/local/tmp/kvesmos-v011-ui.xml')
    return list(ET.fromstring(dev('exec-out', 'cat', '/data/local/tmp/kvesmos-v011-ui.xml')).iter('node'))


def screenshot(name):
    (args.output / name).write_bytes(dev('exec-out', 'screencap', '-p'))


log = subprocess.Popen(command + ['logcat', '-T', '1', '-s', 'KVESMOS_QA:I'], stdout=subprocess.PIPE)
record = None
try:
    for raw in log.stdout:
        line = raw.decode('utf-8', 'replace')
        if 'V011_PIN_WIDGET' in line:
            time.sleep(2)
            current = nodes()
            screenshot('widget-pin.png')
            for node in current:
                if node.get('text') in ['Add to home screen', 'Add', 'Добавить на главный экран', 'Добавить']:
                    x1, y1, x2, y2 = map(int, re.findall(r'\d+', node.get('bounds')))
                    dev('shell', 'input', 'tap', str((x1+x2)//2), str((y1+y2)//2))
                    break
            time.sleep(1)
            dev('shell', 'am', 'start', '-n', 'dev.orbitwords.orbitwords/.MainActivity')
        if 'V011_ES_START' in line:
            record = subprocess.Popen(command + ['shell', 'screenrecord', '--bit-rate', '1500000', '--time-limit', '180', '/sdcard/kvesmos-v011-spanish.mp4'])
        if 'V011_WIDGET_' in line:
            language = line.strip().split('V011_WIDGET_')[-1].lower()
            dev('shell', 'input', 'keyevent', 'KEYCODE_HOME')
            time.sleep(1)
            current = nodes()
            if not any(n.get('resource-id', '').startswith('dev.orbitwords.orbitwords:id/widget_') for n in current):
                bounds = next(n.get('bounds') for n in current if n.get('bounds'))
                _, _, width, height = map(int, re.findall(r'\d+', bounds))
                dev('shell', 'input', 'swipe', str(width*9//10), str(height//2), str(width//10), str(height//2), '300')
                time.sleep(1)
                current = nodes()
            screenshot('widget-' + language + '.png')
            (args.output / ('widget-' + language + '.json')).write_text(json.dumps([n.attrib for n in current], ensure_ascii=False), encoding='utf-8')
            dev('shell', 'am', 'start', '-n', 'dev.orbitwords.orbitwords/.MainActivity')
        if 'V011_ES_DONE' in line and record:
            pid = dev('shell', 'pidof', 'screenrecord').decode().strip()
            if pid:
                dev('shell', 'kill', '-2', pid)
            record.wait(timeout=20)
            dev('pull', '/sdcard/kvesmos-v011-spanish.mp4', str(args.output / 'spanish-cycle.mp4'))
            record = None
        if 'V011_CYCLE_DONE' in line:
            break
finally:
    log.terminate()
    if record:
        record.terminate()
