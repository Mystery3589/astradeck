import os
import sys
import glob
import shutil
import subprocess
import webbrowser
import psutil
from typing import Optional, Tuple, Dict, Any, List

# Catalog of native desktop applications with their binary names per OS (Linux, Windows, macOS)
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
        'linux': ['discord', 'Discord', 'DiscordCanary', 'vesktop', 'webcord'],
        'windows': ['Discord.exe', 'Update.exe'],
        'darwin': ['Discord'],
        'url': 'https://discord.com/app',
        'is_singleton': True,
    },
    'spotify': {
        'linux': ['spotify-launcher', 'spotify', 'ncspot'],
        'windows': ['Spotify.exe', 'spotify.exe'],
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
    'firefox': {
        'linux': ['firefox', 'firefox-bin'],
        'windows': ['firefox.exe'],
        'darwin': ['Firefox'],
        'url': 'https://mozilla.org',
        'is_singleton': False,
    },
    'brave': {
        'linux': ['brave', 'brave-browser'],
        'windows': ['brave.exe'],
        'darwin': ['Brave Browser'],
        'url': 'https://brave.com',
        'is_singleton': False,
    },
    'browser': {
        'linux': ['firefox', 'google-chrome-stable', 'chromium', 'brave'],
        'windows': ['chrome.exe', 'firefox.exe', 'msedge.exe'],
        'darwin': ['Safari', 'Google Chrome'],
        'url': 'https://google.com',
        'is_singleton': False,
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

    _desktop_apps_cache = None

    @classmethod
    def get_desktop_applications(cls) -> Dict[str, Dict[str, str]]:
        """
        Indexes installed Linux desktop applications from standard XDG .desktop files.
        Returns a dict mapping normalized name/filename to {'name': ..., 'exec': ..., 'path': ...}
        """
        if cls._desktop_apps_cache is not None:
            return cls._desktop_apps_cache

        apps: Dict[str, Dict[str, str]] = {}
        if cls.get_os_key() != 'linux':
            cls._desktop_apps_cache = apps
            return apps

        dirs = [
            '/usr/share/applications',
            os.path.expanduser('~/.local/share/applications'),
            '/var/lib/flatpak/exports/share/applications',
            os.path.expanduser('~/.local/share/flatpak/exports/share/applications')
        ]

        for d in dirs:
            if not os.path.isdir(d):
                continue
            for f in glob.glob(os.path.join(d, '*.desktop')):
                try:
                    with open(f, 'r', errors='ignore') as fp:
                        content = fp.read()
                        name, exec_cmd = '', ''
                        for line in content.splitlines():
                            if line.startswith('Name=') and not name:
                                name = line[5:].strip()
                            elif line.startswith('Exec=') and not exec_cmd:
                                raw_exec = line[5:].strip()
                                parts = [p for p in raw_exec.split() if not (p.startswith('%') and len(p) == 2)]
                                exec_cmd = ' '.join(parts)
                        if name and exec_cmd:
                            base = os.path.basename(f)
                            raw_id = base[:-8] if base.endswith('.desktop') else base
                            entry = {'name': name, 'exec': exec_cmd, 'path': f, 'raw_id': raw_id}
                            apps[raw_id.lower()] = entry
                            apps[name.lower()] = entry
                except Exception:
                    pass

        cls._desktop_apps_cache = apps
        return apps

    # =========================================================================
    # CORE TUNNEL CHECKER: Determines if application is installed
    # =========================================================================
    @classmethod
    def is_app_installed(cls, app_query: str) -> Tuple[bool, Optional[Dict[str, Any]]]:
        """
        Multi-Platform Tunnel Checker (Linux, Windows, macOS):
        Determines whether the requested application is installed on the host system.
        Inspects:
        1. Catalog mappings & multi-binary lookup (including spotify-launcher, vesktop, etc.)
        2. System .desktop files (scans all registered desktop applications on Linux)
        3. Direct PATH binary discovery via shutil.which
        4. Standard OS application locations (macOS /Applications, Windows Program Files)
        Returns: (True, app_info_dict) if installed, (False, fallback_info_dict) otherwise.
        """
        query_clean = app_query.strip().lower()
        os_key = cls.get_os_key()

        # 1. Check Catalog Entry
        catalog_entry = APP_CATALOG.get(query_clean)
        if not catalog_entry:
            for k, entry in APP_CATALOG.items():
                if k in query_clean or query_clean in k:
                    catalog_entry = entry
                    break

        binaries_to_check: List[str] = []
        fallback_url: Optional[str] = None
        display_name: str = app_query

        if catalog_entry:
            binaries_to_check.extend(catalog_entry.get(os_key, []))
            fallback_url = catalog_entry.get('url')
            display_name = catalog_entry.get('display_name', app_query)

        # 2. Check binaries from catalog in PATH / Program Files / Applications
        executable = cls.find_executable(binaries_to_check)
        if executable:
            return True, {
                'name': display_name,
                'executable': executable,
                'binary_names': binaries_to_check + [os.path.basename(executable)],
                'fallback_url': fallback_url,
                'source': 'catalog_binary',
            }

        # 3. Multi-Platform System Registry / Desktop Search
        if os_key == 'linux':
            desktop_apps = cls.get_desktop_applications()
            matched_entry = desktop_apps.get(query_clean)
            if not matched_entry:
                for k, v in desktop_apps.items():
                    if query_clean in k or query_clean in v['name'].lower():
                        matched_entry = v
                        break

            if matched_entry:
                exec_cmd = matched_entry['exec']
                first_token = exec_cmd.split()[0] if exec_cmd else ''
                resolved_bin = shutil.which(first_token) or first_token
                return True, {
                    'name': matched_entry['name'],
                    'executable': resolved_bin,
                    'exec_cmd': exec_cmd,
                    'binary_names': [first_token, os.path.basename(resolved_bin), matched_entry['raw_id']] + binaries_to_check,
                    'fallback_url': fallback_url,
                    'source': 'desktop_file',
                }
        elif os_key == 'darwin':
            # macOS: Check /Applications and ~/Applications
            for app_dir in ['/Applications', os.path.expanduser('~/Applications')]:
                for cand in [f"{app_query}.app", f"{display_name}.app"]:
                    p = os.path.join(app_dir, cand)
                    if os.path.exists(p):
                        return True, {
                            'name': display_name,
                            'executable': p,
                            'binary_names': [app_query, display_name],
                            'fallback_url': fallback_url,
                            'source': 'macos_app_bundle',
                        }
        elif os_key == 'windows':
            # Windows: Check common AppData / LocalAppData / ProgramFiles
            for env_var in ['ProgramFiles', 'ProgramFiles(x86)', 'LocalAppData', 'AppData']:
                base = os.environ.get(env_var, '')
                if base:
                    for ext in ['', '.exe']:
                        cand = os.path.join(base, f"{app_query}{ext}")
                        if os.path.isfile(cand):
                            return True, {
                                'name': display_name,
                                'executable': cand,
                                'binary_names': [os.path.basename(cand)],
                                'fallback_url': fallback_url,
                                'source': 'windows_program_file',
                            }

        # 4. Direct generic check on PATH for the query itself
        direct_bin = shutil.which(app_query)
        if direct_bin:
            return True, {
                'name': app_query,
                'executable': direct_bin,
                'binary_names': [app_query, os.path.basename(direct_bin)] + binaries_to_check,
                'fallback_url': fallback_url,
                'source': 'path_binary',
            }

        # App is not installed locally
        return False, {
            'name': display_name,
            'fallback_url': fallback_url or f"https://www.google.com/search?q={app_query}",
            'source': 'not_installed',
        }

    # =========================================================================
    # OPENERS: Native App Opener & Web Opener
    # =========================================================================
    @classmethod
    def open_app(cls, app_info: Dict[str, Any]) -> Dict[str, Any]:
        """
        Native App Opener:
        - Singleton Check: If already running -> DO NOTHING (prevents duplicates).
        - If not running -> Spawns native desktop process detached with desktop environment.
        """
        name = app_info.get('name', 'Application')
        binaries = app_info.get('binary_names', [])
        executable = app_info.get('executable', '')
        exec_cmd = app_info.get('exec_cmd')

        # Singleton check: If already running, do nothing!
        if cls.is_process_running(binaries):
            print(f"[AppLifecycle -> AppOpener] Native application '{name}' is already running. Duplicate prevented.")
            return {
                'status': 'already_running',
                'app': name,
                'action': 'prevented_duplicate',
                'message': f"'{name}' is already running. Duplicate prevented."
            }

        target_to_launch = exec_cmd if exec_cmd else executable
        print(f"[AppLifecycle -> AppOpener] Launching native application '{name}' with: {target_to_launch}")
        cls.spawn_native(target_to_launch)
        return {
            'status': 'launched_native',
            'app': name,
            'executable': executable,
            'message': f"Launched native {name}"
        }

    @classmethod
    def open_web(cls, url: str, app_name: Optional[str] = None) -> Dict[str, Any]:
        """
        Web Opener (Cross-Platform):
        - Reopens target URL in default browser every single time clicked.
        """
        print(f"[AppLifecycle -> WebOpener] Opening browser URL: {url} (App: {app_name or 'URL'})")
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
            print(f"[AppLifecycle -> WebOpener] Fallback to webbrowser module: {e}")
            webbrowser.open_new_tab(url)

        return {
            'status': 'opened_browser_url',
            'url': url,
            'app': app_name,
            'message': f"Opened {url} in default browser."
        }

    # =========================================================================
    # TUNNEL: All app launch requests tunnel through here
    # =========================================================================
    @classmethod
    def tunnel_app_opener(cls, target: str, is_explicit_url: bool = False) -> Dict[str, Any]:
        """
        App Opener Tunnel:
        1. Checks if target is a web URL -> Redirects to Web Opener (opens every click).
        2. Tunnels through is_app_installed():
           - If INSTALLED -> Redirects to App Opener (strictly opens once, ignores if running).
           - If NOT INSTALLED -> Redirects to Web Opener (opens web fallback every click).
        """
        trimmed = target.strip()

        # Step 1: Explicit web URL check
        if is_explicit_url or trimmed.startswith('http://') or trimmed.startswith('https://'):
            return cls.open_web(trimmed)

        # Step 2: Tunnel through installation verification
        is_installed, app_info = cls.is_app_installed(trimmed)

        if is_installed and app_info:
            # Redirect to Native App Opener
            return cls.open_app(app_info)
        else:
            # Redirect to Web Opener
            fallback_url = (app_info or {}).get('fallback_url') or f"https://www.google.com/search?q={trimmed}"
            app_name = (app_info or {}).get('name') or trimmed
            return cls.open_web(fallback_url, app_name=app_name)

    @classmethod
    def launch(cls, target: str, is_explicit_url: bool = False) -> Dict[str, Any]:
        """Backward-compatible entrypoint routed directly through tunnel."""
        return cls.tunnel_app_opener(target, is_explicit_url=is_explicit_url)

    @classmethod
    def open_in_browser(cls, url: str):
        """Backward-compatible browser opener."""
        return cls.open_web(url)

    @classmethod
    def spawn_native(cls, command_or_exec: str):
        """Spawns native desktop process detached from server lifecycle (Cross-Platform)."""
        os_key = cls.get_os_key()
        try:
            tokens = command_or_exec.split() if isinstance(command_or_exec, str) else list(command_or_exec)
            if not tokens:
                return

            if os_key == 'darwin' and tokens[0].endswith('.app'):
                subprocess.Popen(['open', tokens[0]], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            elif os_key == 'windows':
                subprocess.Popen(tokens, shell=True, env=os.environ.copy())
            else:
                subprocess.Popen(
                    tokens,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    start_new_session=True,
                    env=os.environ.copy()
                )
        except Exception as e:
            print(f"[AppLifecycle] Error spawning process {command_or_exec}: {e}")
