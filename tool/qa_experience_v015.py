"""Emulator-only system dialog/screenshot companion for the 0.15 native test.
Does not install/uninstall/clear apps. Videos are silent Android screenrecord.
"""
import argparse
import re
import subprocess
import time
import xml.etree.ElementTree as ET
from pathlib import Path

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--sdk',type=Path,required=True)
p.add_argument('--serial',required=True)
p.add_argument('--output',type=Path,default=Path('test-output/v015-native'))
a=p.parse_args()
cmd=[str((a.sdk/'platform-tools/adb.exe').resolve()),'-s',a.serial]
def dev(*v): return subprocess.check_output(cmd+list(v),timeout=25)
assert a.serial.startswith('emulator-') and dev('shell','getprop','ro.kernel.qemu').strip()==b'1'
a.output.mkdir(parents=True,exist_ok=True)
def nodes():
    dev('shell','uiautomator','dump','/data/local/tmp/kvesmos-v015-ui.xml')
    return list(ET.fromstring(dev('exec-out','cat','/data/local/tmp/kvesmos-v015-ui.xml')).iter('node'))
def capture(name): (a.output/(name+'.png')).write_bytes(dev('exec-out','screencap','-p'))
def tap(node):
    x1,y1,x2,y2=map(int,re.findall(r'\d+',node.get('bounds')))
    dev('shell','input','tap',str((x1+x2)//2),str((y1+y2)//2))
def foreground(): dev('shell','am','start','-n','dev.orbitwords.orbitwords/.MainActivity')
log=subprocess.Popen(cmd+['logcat','-T','1','-s','KVESMOS_QA:I'],stdout=subprocess.PIPE)
record=None
lesson_record=None
try:
    for raw in log.stdout:
        line=raw.decode('utf-8','replace')
        if 'V015_' not in line: continue
        print(line.strip(),flush=True)
        if 'V015_CAPTURE:' in line:
            name=line.split('V015_CAPTURE:')[-1].strip()
            assert re.fullmatch('[a-z0-9-]+',name)
            time.sleep(.35);capture(name)
        if 'V015_PERMISSION_' in line:
            allow='ALLOW' in line
            time.sleep(2)
            ns=nodes();capture('permission-allow' if allow else 'permission-deny')
            target=next(n for n in ns if n.get('resource-id','').endswith('permission_allow_button' if allow else 'permission_deny_button'))
            tap(target)
        if 'V015_PIN_WIDGET' in line:
            time.sleep(2);ns=nodes();capture('widget-pin')
            target=next(n for n in ns if n.get('text') in ['Add to home screen','Add','Добавить на главный экран','Добавить'])
            tap(target);time.sleep(1);foreground()
        if 'V015_FR_CYCLE_START' in line or 'V015_ZH_CYCLE_START' in line:
            video_lang = 'zh' if 'V015_ZH_' in line else 'fr'
            lesson_record=subprocess.Popen(cmd+['shell','screenrecord','--bit-rate','1500000','--time-limit','180','/sdcard/kvesmos-v015-lesson.mp4'])
        if ('V015_FR_CYCLE_DONE' in line or 'V015_ZH_CYCLE_DONE' in line) and lesson_record:
            pid=dev('shell','pidof','screenrecord').decode().strip()
            if pid: dev('shell','kill','-2',pid)
            lesson_record.wait(timeout=20)
            dev('pull','/sdcard/kvesmos-v015-lesson.mp4',str(a.output/f'lesson-cycle-{video_lang}.mp4'));lesson_record=None
        if 'V015_CHEST_START' in line:
            record=subprocess.Popen(cmd+['shell','screenrecord','--bit-rate','1500000','--time-limit','120','/sdcard/kvesmos-v015-chest.mp4'])
        if 'V015_WIDGET_' in line:
            name=line.strip().split('V015_WIDGET_')[-1].lower()
            dev('shell','input','keyevent','KEYCODE_HOME');time.sleep(.8)
            ns=nodes()
            if not any('widget_streak' in n.get('resource-id','') for n in ns):
                bounds=next(n.get('bounds') for n in ns if n.get('bounds'))
                _,_,w,h=map(int,re.findall(r'\d+',bounds))
                dev('shell','input','swipe',str(w*9//10),str(h//2),str(w//10),str(h//2),'250');time.sleep(.6)
            capture('widget-'+name);foreground()
        if 'V015_CHEST_DONE' in line and record:
            pid=dev('shell','pidof','screenrecord').decode().strip()
            if pid: dev('shell','kill','-2',pid)
            record.wait(timeout=20)
            dev('pull','/sdcard/kvesmos-v015-chest.mp4',str(a.output/'chest-cycle.mp4'));record=None
        if 'V015_CYCLE_DONE' in line: break
finally:
    log.terminate()
    if record: record.terminate()
    if lesson_record: lesson_record.terminate()
