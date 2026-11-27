"""Record a continuous Android First Flight test, including emulator audio."""

import argparse
from pathlib import Path
import subprocess

import imageio_ffmpeg


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--adb', type=Path, required=True)
    parser.add_argument('--serial', default='emulator-5556')
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--start-tag', default='FIRST_FLIGHT_START')
    parser.add_argument('--end-tag', default='FIRST_FLIGHT_END')
    parser.add_argument('--name', default='KVESMOS-First-Flight')
    parser.add_argument('--audio-gain-db', type=float, default=24, help='Gain for the quiet QA emulator audio')
    args = parser.parse_args()
    adb = [str(args.adb.resolve()), '-s', args.serial]
    avd = subprocess.check_output(adb + ['shell', 'getprop', 'ro.boot.qemu.avd_name'])
    if avd.strip() != b'KVESMOS11_QA':
        raise RuntimeError('Capture is restricted to the QA emulator')
    args.out.mkdir(parents=True, exist_ok=True)
    if Path(args.name).name != args.name or not args.name.strip():
        raise ValueError('Capture name must be a file name without a directory')
    # Preserve the original raw file name for the default First Flight workflow.
    raw_name = 'first-flight' if args.name == 'KVESMOS-First-Flight' else args.name
    staging = args.out.resolve() / f'{raw_name}.webm'
    log = subprocess.Popen(adb + ['logcat', '-T', '1', '-s', 'KVESMOS11:I'], stdout=subprocess.PIPE, text=True)
    recording = False
    try:
        for line in log.stdout:
            message = line.partition('KVESMOS11: ')[2].strip()
            if not recording and message == args.start_tag:
                subprocess.run(adb + ['emu', 'screenrecord', 'start', '--time-limit', '720', '--fps', '24', str(staging)], check=True)
                recording = True
            if recording and message == args.end_tag:
                subprocess.run(adb + ['emu', 'screenrecord', 'stop'], check=True)
                recording = False
                break
    finally:
        log.terminate()
        if recording:
            subprocess.run(adb + ['emu', 'screenrecord', 'stop'], check=False)
    subprocess.run([
        imageio_ffmpeg.get_ffmpeg_exe(), '-hide_banner', '-loglevel', 'error', '-y',
        '-i', str(staging), '-c:v', 'libx264', '-preset', 'fast', '-crf', '20',
        '-pix_fmt', 'yuv420p', '-af', f'volume={args.audio_gain_db}dB,alimiter=limit=0.89:level=0',
        '-c:a', 'aac', '-movflags', '+faststart',
        str(args.out / f'{args.name}.mp4'),
    ], check=True)


if __name__ == '__main__':
    main()
