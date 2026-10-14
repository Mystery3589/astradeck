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
