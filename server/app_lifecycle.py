import os
import sys
import shutil
import subprocess
import webbrowser
import psutil

# Catalog of native desktop applications with their binary names per OS
# Format: app_key -> { 'names': [binary_names], 'mac_names': [...], 'url': fallback_url }
APP_CATALOG = {
    'obs': {
        'linux': ['obs', 'obs-studio'],
        'windows': ['obs64.exe', 'obs32.exe', 'obs.exe'],
        'darwin': ['OBS'],
        'url': 'https://obsproject.com',
        'is_singleton': True,
    },
    'obs studio': {
        'linux': ['obs', 'obs-studio'],
        'windows': ['obs64.exe', 'obs32.exe', 'obs.exe'],
        'darwin': ['OBS'],
        'url': 'https://obsproject.com',
        'is_singleton': True,
    },
    'discord': {
        'linux': ['discord', 'Discord', 'DiscordCanary'],
        'windows': ['Discord.exe', 'Update.exe'],
        'darwin': ['Discord'],
        'url': 'https://discord.com/app',
        'is_singleton': True,
    },
    'spotify': {
        'linux': ['spotify'],
        'windows': ['Spotify.exe'],
        'darwin': ['Spotify'],
        'url': 'https://open.spotify.com',
        'is_singleton': True,
    },
    'steam': {
        'linux': ['steam'],
        'windows': ['steam.exe'],
        'darwin': ['Steam'],
        'url': 'https://store.steampowered.com',
        'is_singleton': True,
    },
    'chrome': {
        'linux': ['google-chrome-stable', 'google-chrome', 'chromium', 'chromium-browser'],
        'windows': ['chrome.exe'],
        'darwin': ['Google Chrome'],
        'url': 'https://google.com',
        'is_singleton': False, # Browser can open multiple windows
    },
    'vs code': {
        'linux': ['code', 'codium'],
        'windows': ['Code.exe'],
        'darwin': ['Visual Studio Code'],
        'url': 'https://vscode.dev',
        'is_singleton': False,
    },
    'calculator': {
        'linux': ['gnome-calculator', 'kcalc', 'galculator', 'xcalc'],
        'windows': ['calc.exe'],
        'darwin': ['Calculator'],
        'url': 'https://www.google.com/search?q=calculator',
        'is_singleton': False,
    },
    # Apps that are primarily web-based or commonly lack desktop binaries
    'youtube': {
        'linux': ['youtube-music'],
        'windows': ['YouTubeMusic.exe'],
        'darwin': ['YouTube Music'],
        'url': 'https://youtube.com',
        'is_singleton': False,
    },
    'instagram': {
        'linux': [],
        'windows': ['Instagram.exe'],
        'darwin': [],
        'url': 'https://instagram.com',
        'is_singleton': False,
    },
    'x': {
        'linux': [],
        'windows': [],
        'darwin': [],
        'url': 'https://x.com',
        'is_singleton': False,
    },
    'x / twitter': {
        'linux': [],
        'windows': [],
        'darwin': [],
        'url': 'https://x.com',
        'is_singleton': False,
    },
    'twitter': {
        'linux': [],
        'windows': [],
        'darwin': [],
        'url': 'https://x.com',
        'is_singleton': False,
    },
    'twitch': {
        'linux': [],
        'windows': ['Twitch.exe'],
        'darwin': ['Twitch'],
        'url': 'https://twitch.tv',
        'is_singleton': False,
    },
    'whatsapp': {
        'linux': ['whatsapp-for-linux', 'zapzap'],
        'windows': ['WhatsApp.exe'],
        'darwin': ['WhatsApp'],
        'url': 'https://web.whatsapp.com',
        'is_singleton': True,
    },
    'notion': {
        'linux': ['notion-app', 'notion-snap'],
        'windows': ['Notion.exe'],
        'darwin': ['Notion'],
        'url': 'https://notion.so',
        'is_singleton': True,
    },
    'github': {
        'linux': ['github-desktop'],
        'windows': ['GitHubDesktop.exe'],
        'darwin': ['GitHub Desktop'],
        'url': 'https://github.com',
        'is_singleton': False,
    },
}

class AppLifecycleManager:
    @staticmethod
    def get_os_key():
        if sys.platform.startswith('linux'):
            return 'linux'
        elif sys.platform == 'win32' or sys.platform == 'cygwin':
            return 'windows'
        elif sys.platform == 'darwin':
            return 'darwin'
        return 'linux'

    @classmethod
    def is_process_running(cls, binary_names):
        """Check if any of the given binary names are currently running in psutil."""
        if not binary_names:
            return False
        
        target_names = {name.lower() for name in binary_names}
        for proc in psutil.process_iter(['name', 'cmdline']):
            try:
                pname = (proc.info['name'] or '').lower()
                if pname in target_names:
                    return True
                
                # Check command line arguments for matches (e.g. electron apps)
                cmdline = proc.info.get('cmdline') or []
                for arg in cmdline:
                    arg_lower = arg.lower()
                    for t in target_names:
                        if t in arg_lower and ('bin' in arg_lower or '.exe' in arg_lower or '.app' in arg_lower):
                            return True
            except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                continue
        return False

    @classmethod
    def find_executable(cls, binary_names):
        """Find if any executable binary is installed on PATH or standard application folders."""
        os_key = cls.get_os_key()

        for name in binary_names:
            # Check PATH
            found = shutil.which(name)
            if found:
                return found

            # Windows Program Files check
            if os_key == 'windows':
                for env_var in ['ProgramFiles', 'ProgramFiles(x86)', 'LocalAppData']:
                    base = os.environ.get(env_var, '')
                    if base:
                        cand = os.path.join(base, name)
                        if os.path.isfile(cand):
                            return cand

            # macOS /Applications check
            if os_key == 'darwin':
                app_path = f"/Applications/{name}.app"
                if os.path.exists(app_path):
                    return app_path

        return None

    @classmethod
    def launch(cls, target, is_explicit_url=False):
        """
        Smart Application Launcher:
        - If target is a URL: always open in browser (and always reopens on click).
        - If target is an App:
          1. Check if native app is installed.
          2. If native app is installed:
             - If it's a singleton (e.g. OBS, Discord, Spotify) and already running -> DO NOTHING (prevent duplicates).
             - If not running -> launch native process.
          3. If native app is NOT installed:
             - Fall back to the app's web URL in the browser (always reopens on click).
        """
        target_lower = target.strip().lower()

        # Direct URL check
        if is_explicit_url or target.startswith('http://') or target.startswith('https://'):
            print(f"[AppLifecycle] Opening browser URL: {target}")
            cls.open_in_browser(target)
            return {'status': 'opened_browser_url', 'target': target, 'message': 'Opened URL in default browser'}

        # Lookup in App Catalog
        entry = APP_CATALOG.get(target_lower)
        os_key = cls.get_os_key()

        if entry:
            binaries = entry.get(os_key, [])
            is_singleton = entry.get('is_singleton', False)
            fallback_url = entry.get('url')

            # 1. Check if process is already running (singleton check)
            if is_singleton and cls.is_process_running(binaries):
                print(f"[AppLifecycle] Application '{target}' is already running. Preventing duplicate instance.")
                return {
                    'status': 'already_running',
                    'target': target,
                    'message': f"'{target}' is already running. Duplicate instance prevented."
                }

            # 2. Check if native executable exists
            executable = cls.find_executable(binaries)
            if executable:
                print(f"[AppLifecycle] Launching native application: {executable}")
                cls.spawn_native(executable)
                return {
                    'status': 'launched_native',
                    'target': target,
                    'executable': executable,
                    'message': f"Launched native {target}"
                }

            # 3. Native app not found -> fallback to browser URL
            if fallback_url:
                print(f"[AppLifecycle] Native '{target}' not found. Falling back to browser URL: {fallback_url}")
                cls.open_in_browser(fallback_url)
                return {
                    'status': 'fallback_to_browser',
                    'target': target,
                    'url': fallback_url,
                    'message': f"Native app not found. Opened {fallback_url} in browser."
                }

        # Unknown app name: check if binary exists directly on PATH
        generic_bin = shutil.which(target)
        if generic_bin:
            if cls.is_process_running([target]):
                print(f"[AppLifecycle] Process '{target}' already running.")
                return {'status': 'already_running', 'target': target, 'message': 'Process is already running.'}
            cls.spawn_native(generic_bin)
            return {'status': 'launched_native', 'target': target, 'executable': generic_bin}

        # If completely unknown and looks like a name, open search in browser
        search_url = f"https://www.google.com/search?q={target}"
        cls.open_in_browser(search_url)
        return {'status': 'fallback_to_browser', 'target': target, 'url': search_url, 'message': 'Opened in browser'}

    @classmethod
    def open_in_browser(cls, url):
        """Opens URL in user's default browser. Always opens when called."""
        try:
            os_key = cls.get_os_key()
            if os_key == 'linux':
                subprocess.Popen(['xdg-open', url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            elif os_key == 'darwin':
                subprocess.Popen(['open', url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            elif os_key == 'windows':
                os.startfile(url)
            else:
                webbrowser.open_new_tab(url)
        except Exception as e:
            print(f"[AppLifecycle] Failed to open with OS tool, trying webbrowser module: {e}")
            webbrowser.open_new_tab(url)

    @classmethod
    def spawn_native(cls, executable):
        """Spawns native desktop process detached from server lifecycle."""
        os_key = cls.get_os_key()
        try:
            if os_key == 'darwin' and executable.endswith('.app'):
                subprocess.Popen(['open', executable], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            else:
                subprocess.Popen(
                    [executable],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    start_new_session=True
                )
        except Exception as e:
            print(f"[AppLifecycle] Error spawning process {executable}: {e}")
