import os
import sys
import subprocess
import shutil

class CrossPlatformControls:
    @staticmethod
    def get_os():
        if sys.platform.startswith('linux'):
            return 'linux'
        elif sys.platform == 'win32' or sys.platform == 'cygwin':
            return 'windows'
        elif sys.platform == 'darwin':
            return 'darwin'
        return 'linux'

    # --- Unified Hardware Control Entrypoint (Function 1) ---
    @classmethod
    def handle_hardware_control(cls, target: str, command: str, value=None):
        """
        Unified hardware control for sound, mic, and brightness.
        target: 'volume' | 'sound' | 'mic' | 'brightness'
        command: 'set' | 'adjust' | 'toggle_mute' | 'get'
        """
        t = (target or 'volume').lower()
        c = (command or 'adjust').lower()

        if t in ('volume', 'sound'):
            if c == 'set':
                cls.set_volume(value if value is not None else 50)
            elif c == 'toggle_mute':
                cls.toggle_mute()
            else:
                cls.adjust_volume(value if value is not None else 5)
        elif t in ('mic', 'microphone'):
            if c == 'set':
                cls.set_mic_volume(value if value is not None else 75)
            elif c == 'toggle_mute':
                cls.toggle_mic_mute()
            else:
                cls.toggle_mic_mute()
        elif t in ('brightness', 'display'):
            if c == 'set':
                cls.set_brightness(value if value is not None else 80)
            else:
                cls.adjust_brightness(value if value is not None else 10)

        vol, brightness = cls.get_current_state()
        return {
            'status': 'ok',
            'target': t,
            'command': c,
            'volume': vol,
            'brightness': brightness
        }

    # --- System Volume ---
    @classmethod
    def set_volume(cls, percent):
        val = max(0, min(100, int(percent)))
        os_name = cls.get_os()

        if os_name == 'linux':
            if shutil.which('pactl'):
                subprocess.run(['pactl', 'set-sink-volume', '@DEFAULT_SINK@', f'{val}%'], check=False)
            elif shutil.which('amixer'):
                subprocess.run(['amixer', '-D', 'pulse', 'sset', 'Master', f'{val}%'], check=False)

        elif os_name == 'darwin':
            # macOS AppleScript volume 0 to 100
            subprocess.run(['osascript', '-e', f'set volume output volume {val}'], check=False)

        elif os_name == 'windows':
            # PowerShell audio automation
            ps_script = f"$obj = New-Object -ComObject WScript.Shell; [Math]::Round({val})"
            subprocess.run(['powershell', '-Command', ps_script], check=False)

        return {'volume': val}

    @classmethod
    def adjust_volume(cls, delta):
        os_name = cls.get_os()
        sign = '+' if delta >= 0 else '-'
        abs_delta = abs(int(delta))

        if os_name == 'linux':
            if shutil.which('pactl'):
                subprocess.run(['pactl', 'set-sink-volume', '@DEFAULT_SINK@', f'{sign}{abs_delta}%'], check=False)
        elif os_name == 'darwin':
            # adjust volume by delta
            script = f'set cur to output volume of (get volume settings)\nset volume output volume (cur + {delta})'
            subprocess.run(['osascript', '-e', script], check=False)
        return {'delta': delta}

    @classmethod
    def toggle_mute(cls):
        os_name = cls.get_os()
        if os_name == 'linux':
            if shutil.which('pactl'):
                subprocess.run(['pactl', 'set-sink-mute', '@DEFAULT_SINK@', 'toggle'], check=False)
        elif os_name == 'darwin':
            script = 'set cur to output muted of (get volume settings)\nset volume output muted (not cur)'
            subprocess.run(['osascript', '-e', script], check=False)
        return {'status': 'toggled_mute'}

    # --- Microphone Mute ---
    @classmethod
    def toggle_mic_mute(cls):
        os_name = cls.get_os()
        if os_name == 'linux':
            if shutil.which('pactl'):
                subprocess.run(['pactl', 'set-source-mute', '@DEFAULT_SOURCE@', 'toggle'], check=False)
        elif os_name == 'darwin':
            script = 'set cur to input volume of (get volume settings)\nif cur > 0 then\nset volume input volume 0\nelse\nset volume input volume 75\nend if'
            subprocess.run(['osascript', '-e', script], check=False)
        return {'status': 'toggled_mic_mute'}

    @classmethod
    def set_mic_volume(cls, percent):
        """Set microphone/input source volume (0–100)."""
        val = max(0, min(100, int(percent)))
        os_name = cls.get_os()
        if os_name == 'linux':
            if shutil.which('pactl'):
                subprocess.run(
                    ['pactl', 'set-source-volume', '@DEFAULT_SOURCE@', f'{val}%'],
                    check=False,
                )
        elif os_name == 'darwin':
            subprocess.run(
                ['osascript', '-e', f'set volume input volume {val}'],
                check=False,
            )
        elif os_name == 'windows':
            # Windows: use SoundVolumeView or nircmd if available
            if shutil.which('nircmd'):
                subprocess.run(['nircmd', 'mutesysvolume', '0'], check=False)
                subprocess.run(['nircmd', 'setsysvolume', str(int(val * 655.35)), '1'], check=False)
        return {'mic_volume': val}

    # --- Screen Brightness ---
    @classmethod
    def set_brightness(cls, percent):
        val = max(1, min(100, int(percent)))
        os_name = cls.get_os()

        if os_name == 'linux':
            if shutil.which('brightnessctl'):
                subprocess.run(['brightnessctl', 'set', f'{val}%'], check=False)
        elif os_name == 'darwin':
            if shutil.which('brightness'):
                subprocess.run(['brightness', str(val / 100.0)], check=False)
        elif os_name == 'windows':
            ps = f"(Get-WmiObject -Namespace root/WMI -Class WmiMonitorBrightnessMethods).WmiSetBrightness(1,{val})"
            subprocess.run(['powershell', '-Command', ps], check=False)
        return {'brightness': val}


    @classmethod
    def adjust_brightness(cls, delta):
        os_name = cls.get_os()
        sign = '+' if delta >= 0 else '-'
        abs_delta = abs(int(delta))

        if os_name == 'linux' and shutil.which('brightnessctl'):
            subprocess.run(['brightnessctl', 'set', f'{abs_delta}%{sign}'], check=False)
        return {'delta': delta}

    # --- Media Playback Controls ---
    @classmethod
    def media_control(cls, command):
        """Controls media playback: play_pause / toggle, next, previous."""
        os_name = cls.get_os()
        cmd = str(command).lower()

        if os_name == 'linux':
            if shutil.which('playerctl'):
                action = 'play-pause' if cmd in ('play_pause', 'toggle', 'play', 'pause') else ('next' if cmd == 'next' else 'previous')
                subprocess.run(['playerctl', action], check=False)
        elif os_name == 'darwin':
            action = 'playpause' if cmd in ('play_pause', 'toggle') else ('next track' if cmd == 'next' else 'previous track')
            subprocess.run(['osascript', '-e', f'tell application "Music" to {action}'], check=False)
        elif os_name == 'windows':
            vk = '0xB3' if cmd in ('play_pause', 'toggle') else ('0xB0' if cmd == 'next' else '0xB1')
            subprocess.run(['powershell', '-Command', f"$w = New-Object -ComObject WScript.Shell; $w.SendKeys([char]{vk})"], check=False)
        return {'status': 'media_dispatched', 'command': cmd}

    # --- Query current system state for sync ---
    @classmethod
    def get_current_state(cls):
        """Returns (volume_percent, brightness_percent) as best-effort integers."""
        os_name = cls.get_os()
        volume = 50
        brightness = 80

        try:
            if os_name == 'linux':
                if shutil.which('pactl'):
                    result = subprocess.run(
                        ['pactl', 'get-sink-volume', '@DEFAULT_SINK@'],
                        capture_output=True, text=True, check=False
                    )
                    for part in result.stdout.split():
                        if part.endswith('%'):
                            volume = int(part.rstrip('%'))
                            break
                if shutil.which('brightnessctl'):
                    result = subprocess.run(
                        ['brightnessctl', 'get'],
                        capture_output=True, text=True, check=False
                    )
                    max_result = subprocess.run(
                        ['brightnessctl', 'max'],
                        capture_output=True, text=True, check=False
                    )
                    cur = int(result.stdout.strip() or '0')
                    max_b = int(max_result.stdout.strip() or '1')
                    if max_b > 0:
                        brightness = round(cur * 100 / max_b)
            elif os_name == 'darwin':
                result = subprocess.run(
                    ['osascript', '-e', 'output volume of (get volume settings)'],
                    capture_output=True, text=True, check=False
                )
                volume = int(result.stdout.strip() or '50')
        except Exception:
            pass

        return volume, brightness

