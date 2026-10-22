import os
import sys
import re
import glob
import shutil
import subprocess
import webbrowser
import psutil
from typing import Optional, Tuple, Dict, Any, List


def get_display_env() -> dict:
    """
    Returns an environment dict with DISPLAY, WAYLAND_DISPLAY, DBUS_SESSION_BUS_ADDRESS,
    and XDG_RUNTIME_DIR populated. Reads them from the current process env first, then
    falls back to querying loginctl / pgrep for the user session so apps can launch
    properly even when started from a systemd service with no display vars.
    """
    env = os.environ.copy()

    # Already have a display — nothing to do
    if env.get('DISPLAY') or env.get('WAYLAND_DISPLAY'):
        return env

    uid = os.getuid()

    # Try to read env from a running graphical process (plasmashell, gnome-shell, Xorg, etc.)
    for candidate in ['plasmashell', 'gnome-shell', 'kwin_wayland', 'kwin_x11', 'Xorg', 'Xwayland', 'sway', 'mutter']:
        try:
            result = subprocess.run(['pgrep', '-x', candidate], capture_output=True, text=True, timeout=2)
            pid = result.stdout.strip().split('\n')[0]
            if pid:
                with open(f'/proc/{pid}/environ', 'rb') as f:
                    raw = f.read()
                for item in raw.split(b'\x00'):
                    try:
                        k, v = item.decode().split('=', 1)
                        if k in ('DISPLAY', 'WAYLAND_DISPLAY', 'DBUS_SESSION_BUS_ADDRESS', 'XDG_RUNTIME_DIR', 'XDG_SESSION_TYPE'):
                            env[k] = v
                    except Exception:
                        pass
                if env.get('DISPLAY') or env.get('WAYLAND_DISPLAY'):
                    break
        except Exception:
            pass

    # Fallback defaults
    if not env.get('DISPLAY'):
        env.setdefault('DISPLAY', ':0')
    if not env.get('XDG_RUNTIME_DIR'):
        env.setdefault('XDG_RUNTIME_DIR', f'/run/user/{uid}')
    if not env.get('DBUS_SESSION_BUS_ADDRESS'):
        env.setdefault('DBUS_SESSION_BUS_ADDRESS', f'unix:path=/run/user/{uid}/bus')

    return env







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
        Universal Dynamic Application Discovery (Linux, Windows, macOS):
        Determines whether the requested application is installed on the host system
        WITHOUT ANY hardcoded catalogs or static lists.
        
        Resolution Process:
        1. Queries host system registered desktop applications (.desktop / .app / Start Menu).
        2. Queries system PATH via shutil.which (supports commands and scripts with args).
        
        Returns:
          (True, app_info) if installed on host.
          (False, fallback_info) if NOT installed on host (fallback_url: google search).
        """
        query_clean = app_query.strip().lower()
        os_key = cls.get_os_key()
        fallback_url = f"https://www.google.com/search?q={app_query.strip()}"

        # ── 1. Linux Dynamic Desktop Applications Lookup ──────────────────────
        if os_key == 'linux':
            desktop_apps = cls.get_desktop_applications()

            # Exact match on raw_id or name (e.g. "com.obsproject.studio", "chromium", "discord")
            matched_entry = desktop_apps.get(query_clean)

            # Word boundary / substring match in desktop entries
            if not matched_entry:
                q_words = set(re.findall(r'\w+', query_clean))
                for k, v in desktop_apps.items():
                    name_lower = v['name'].lower()
                    raw_id_lower = v['raw_id'].lower()
                    generic_lower = (v.get('generic_name') or '').lower()

                    # Full word match (e.g. "obs" matches "OBS Studio")
                    entry_words = set(re.findall(r'\w+', name_lower)) | set(re.findall(r'\w+', raw_id_lower))
                    if q_words and q_words.issubset(entry_words):
                        matched_entry = v
                        break

                    # Substring match (e.g. "chrom" matches "Chromium")
                    if query_clean in name_lower or query_clean in raw_id_lower or (generic_lower and query_clean in generic_lower):
                        matched_entry = v
                        break

            if matched_entry:
                exec_cmd = matched_entry['exec']
                first_token = exec_cmd.split()[0] if exec_cmd else ''
                resolved_bin = shutil.which(first_token) or first_token
                raw_id = matched_entry.get('raw_id')
                return True, {
                    'name': matched_entry['name'],
                    'executable': resolved_bin,
                    'exec_cmd': exec_cmd,
                    'desktop_id': raw_id,
                    'binary_names': [first_token, os.path.basename(resolved_bin), raw_id, query_clean],
                    'fallback_url': fallback_url,
                    'source': 'desktop_file',
                }

        # ── 2. macOS Dynamic Application Inspection ───────────────────────────
        elif os_key == 'darwin':
            for app_dir in ['/Applications', os.path.expanduser('~/Applications'), '/System/Applications']:
                if not os.path.isdir(app_dir):
                    continue
                for item in os.listdir(app_dir):
                    if item.endswith('.app'):
                        stem = item[:-4].lower()
                        if query_clean in stem or stem in query_clean:
                            full_app = os.path.join(app_dir, item)
                            return True, {
                                'name': item[:-4],
                                'executable': full_app,
                                'desktop_id': None,
                                'binary_names': [item[:-4], stem],
                                'fallback_url': fallback_url,
                                'source': 'macos_app_bundle',
                            }

        # ── 3. Windows Dynamic Application Inspection ─────────────────────────
        elif os_key == 'windows':
            # Check Start Menu Programs
            start_dirs = [
                os.path.expandvars(r'%ProgramData%\Microsoft\Windows\Start Menu\Programs'),
                os.path.expandvars(r'%AppData%\Microsoft\Windows\Start Menu\Programs'),
            ]
            for s_dir in start_dirs:
                if os.path.isdir(s_dir):
                    for root, _, files in os.walk(s_dir):
                        for f in files:
                            stem = os.path.splitext(f)[0].lower()
                            if query_clean in stem:
                                full_p = os.path.join(root, f)
                                return True, {
                                    'name': stem,
                                    'executable': full_p,
                                    'desktop_id': None,
                                    'binary_names': [stem, f"{stem}.exe"],
                                    'fallback_url': fallback_url,
                                    'source': 'windows_start_menu',
                                }

            # Check ProgramFiles / LocalAppData
            for env_var in ['ProgramFiles', 'ProgramFiles(x86)', 'LocalAppData']:
                base = os.environ.get(env_var, '')
                if base:
                    for ext in ['', '.exe']:
                        cand = os.path.join(base, f"{app_query}{ext}")
                        if os.path.isfile(cand):
                            return True, {
                                'name': app_query,
                                'executable': cand,
                                'desktop_id': None,
                                'binary_names': [os.path.basename(cand)],
                                'fallback_url': fallback_url,
                                'source': 'windows_program_file',
                            }

        # ── 4. System PATH Executable Discovery (Direct Commands & Binaries) ──
        tokens = app_query.strip().split()
        if tokens:
            bin_path = shutil.which(tokens[0])
            if bin_path:
                return True, {
                    'name': tokens[0],
                    'executable': bin_path,
                    'exec_cmd': app_query.strip(),
                    'desktop_id': tokens[0],
                    'binary_names': [tokens[0], os.path.basename(bin_path)],
                    'fallback_url': fallback_url,
                    'source': 'path_command',
                }

        # ── 5. App is NOT Installed Locally ───────────────────────────────────
        return False, {
            'name': app_query.strip(),
            'fallback_url': fallback_url,
            'source': 'not_installed',
        }

    # =========================================================================
    # OPENERS: Native App Opener & Web Opener
    # =========================================================================
    @classmethod
    def open_app(cls, app_info: Dict[str, Any]) -> Dict[str, Any]:
        """
        Native App Opener:
        - If the application is ALREADY OPEN / running:
          "the application installed opened nothing happened if clicked"
          -> Returns 'already_running' and does NOT spawn another instance.
        - If not running:
          Spawns the native desktop process detached with graphical session environment.
        """
        name = app_info.get('name', 'Application')
        binaries = app_info.get('binary_names', [])
        executable = app_info.get('executable', '')
        exec_cmd = app_info.get('exec_cmd')
        desktop_id = app_info.get('desktop_id')

        # Check if application is already running on the PC
        if cls.is_process_running(binaries):
            print(f"[AppLifecycle -> AppOpener] Application '{name}' is already running. Nothing happened.")
            return {
                'status': 'already_running',
                'app': name,
                'action': 'nothing_happened',
                'message': f"'{name}' is already running. Nothing happened."
            }

        target_to_launch = exec_cmd if exec_cmd else executable
        print(f"[AppLifecycle -> AppOpener] Launching native application '{name}' via desktop_id={desktop_id or 'N/A'}, exec={target_to_launch}")
        cls.spawn_native(target_to_launch, desktop_id=desktop_id)
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
        - Opens URL in default browser with full session display environment.
        """
        print(f"[AppLifecycle -> WebOpener] Opening browser URL: {url} (App: {app_name or 'URL'})")
        env = get_display_env()
        try:
            os_key = cls.get_os_key()
            if os_key == 'linux':
                subprocess.Popen(
                    ['xdg-open', url],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    start_new_session=True,
                    env=env,
                )
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
    # MULTI-PURPOSE APPLICATION & TARGET LAUNCH TUNNEL
    # =========================================================================
    @classmethod
    def tunnel_app_opener(cls, target: str, is_explicit_url: bool = False) -> Dict[str, Any]:
        """
        Industry-grade Multi-Purpose Target Launcher:
        Stage 1: Explicit web URL (http://, https://)
        Stage 2: Bare domain without scheme (e.g. "youtube.com", "www.reddit.com", "github.com/myrepo")
        Stage 3: Custom URI scheme (e.g. "steam://...", "spotify:...", "discord://...", "mailto:...")
        Stage 4: File or Directory path (e.g. "/path/to/folder", "~/Downloads", "C:\\...")
        Stage 5: Direct .desktop file (Linux)
        Stage 6: Installed desktop application query (Catalog + System .desktop + Path)
        Stage 7: Direct CLI / executable command with arguments (e.g. "code .", "pavucontrol")
        Stage 8: Web fallback (Google search or catalog fallback URL)
        """
        trimmed = target.strip()
        if not trimmed:
            return {'status': 'error', 'message': 'Empty launch target'}

        # ── Stage 1: Explicit web URL ─────────────────────────────────────────
        if is_explicit_url or trimmed.startswith(('http://', 'https://')):
            return cls.open_web(trimmed)

        # ── Stage 2: Bare domain name ─────────────────────────────────────────
        domain_pattern = re.compile(
            r'^(www\.[a-zA-Z0-9-]+\.[a-zA-Z]{2,}|[a-zA-Z0-9-]+\.(com|org|net|io|dev|app|ai|co|edu|gov|tv|me|info|biz)(\/.*)?)$',
            re.IGNORECASE
        )
        if domain_pattern.match(trimmed):
            return cls.open_web(f"https://{trimmed}")

        # ── Stage 3: Custom URI protocol schemes ──────────────────────────────
        if re.match(r'^[a-zA-Z][a-zA-Z0-9+.-]+://', trimmed) or re.match(r'^(spotify|mailto|steam|calc|discord|slack):', trimmed, re.IGNORECASE):
            print(f"[AppLifecycle -> UriOpener] Opening custom URI scheme: {trimmed}")
            env = get_display_env()
            os_key = cls.get_os_key()
            if os_key == 'linux':
                subprocess.Popen(['xdg-open', trimmed], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=env, start_new_session=True)
            elif os_key == 'darwin':
                subprocess.Popen(['open', trimmed], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            elif os_key == 'windows':
                os.startfile(trimmed)
            return {'status': 'opened_uri', 'uri': trimmed, 'message': f"Opened URI {trimmed}"}

        # ── Stage 4: Local File or Directory Path ─────────────────────────────
        if trimmed.startswith(('/', '~/', './', '../', 'file://')) or (len(trimmed) > 2 and trimmed[1] == ':' and trimmed[2] in ('\\', '/')):
            clean_path = trimmed.replace('file://', '')
            expanded = os.path.expanduser(clean_path)
            if os.path.exists(expanded):
                print(f"[AppLifecycle -> FileOpener] Opening local path: {expanded}")
                env = get_display_env()
                os_key = cls.get_os_key()
                if os_key == 'linux':
                    subprocess.Popen(['xdg-open', expanded], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=env, start_new_session=True)
                elif os_key == 'darwin':
                    subprocess.Popen(['open', expanded], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                elif os_key == 'windows':
                    os.startfile(expanded)
                return {'status': 'opened_file', 'path': expanded, 'message': f"Opened {expanded}"}

        # ── Stage 5: Direct .desktop file name ────────────────────────────────
        if trimmed.endswith('.desktop'):
            desktop_id = trimmed[:-8] if trimmed.endswith('.desktop') else trimmed
            env = get_display_env()
            if shutil.which('gtk-launch'):
                subprocess.Popen(['gtk-launch', desktop_id], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=env, start_new_session=True)
                return {'status': 'launched_desktop', 'desktop_id': desktop_id, 'message': f"Launched {trimmed}"}

        # ── Stage 6: Installed Desktop Application lookup ─────────────────────
        is_installed, app_info = cls.is_app_installed(trimmed)
        if is_installed and app_info:
            return cls.open_app(app_info)

        # ── Stage 7: Direct CLI / executable command with arguments ───────────
        tokens = trimmed.split()
        if tokens and shutil.which(tokens[0]):
            print(f"[AppLifecycle -> CommandOpener] Executing system command: {trimmed}")
            env = get_display_env()
            subprocess.Popen(tokens, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=env, start_new_session=True)
            return {'status': 'executed_command', 'command': trimmed, 'message': f"Executed {trimmed}"}

        # ── Stage 8: Web fallback ─────────────────────────────────────────────
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
    def spawn_native(cls, command_or_exec: str, desktop_id: Optional[str] = None):
        """
        Spawns a native desktop GUI application detached from the server lifecycle.

        Strategy (Linux):
          1. gtk-launch <desktop_id>  — uses the .desktop file, inherits the
             session's DISPLAY/Wayland env. Asynchronously spawned with Popen so it
             never blocks the server.
          2. gio open <desktop_id>.desktop — alternative .desktop launcher.
          3. Raw subprocess with full display environment (DISPLAY, WAYLAND_DISPLAY,
             XDG_RUNTIME_DIR, DBUS_SESSION_BUS_ADDRESS) injected.
        """
        os_key = cls.get_os_key()
        env = get_display_env()

        try:
            # ── macOS ─────────────────────────────────────────────────────────
            if os_key == 'darwin':
                tokens = command_or_exec.split() if isinstance(command_or_exec, str) else list(command_or_exec)
                if tokens and tokens[0].endswith('.app'):
                    subprocess.Popen(['open', tokens[0]], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                else:
                    subprocess.Popen(['open', '-a', command_or_exec], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                return

            # ── Windows ───────────────────────────────────────────────────────
            if os_key == 'windows':
                tokens = command_or_exec.split() if isinstance(command_or_exec, str) else list(command_or_exec)
                subprocess.Popen(tokens, shell=True, env=env)
                return

            # ── Linux Strategy 1: gtk-launch <desktop_id> (Non-blocking) ─────
            if desktop_id and shutil.which('gtk-launch'):
                try:
                    subprocess.Popen(
                        ['gtk-launch', desktop_id],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                        start_new_session=True,
                        env=env,
                    )
                    print(f"[AppLifecycle -> spawn_native] gtk-launch {desktop_id}: launched (async)")
                    return
                except Exception as e:
                    print(f"[AppLifecycle -> spawn_native] gtk-launch failed: {e}")

            # ── Linux Strategy 2: gio open <desktop_id>.desktop ──────────────
            if desktop_id and shutil.which('gio'):
                desktop_dirs = [
                    '/usr/share/applications',
                    os.path.expanduser('~/.local/share/applications'),
                    '/var/lib/flatpak/exports/share/applications',
                    os.path.expanduser('~/.local/share/flatpak/exports/share/applications'),
                ]
                for d in desktop_dirs:
                    p = os.path.join(d, f'{desktop_id}.desktop')
                    if os.path.exists(p):
                        try:
                            subprocess.Popen(
                                ['gio', 'open', p],
                                stdout=subprocess.DEVNULL,
                                stderr=subprocess.DEVNULL,
                                start_new_session=True,
                                env=env,
                            )
                            print(f"[AppLifecycle -> spawn_native] gio open {p}: launched")
                            return
                        except Exception as e:
                            print(f"[AppLifecycle -> spawn_native] gio open failed: {e}")
                        break

            # ── Linux Strategy 3: Raw subprocess with injected display env ────
            tokens = command_or_exec.split() if isinstance(command_or_exec, str) else list(command_or_exec)
            if not tokens:
                return
            print(f"[AppLifecycle -> spawn_native] Raw spawn: {tokens[0]} (DISPLAY={env.get('DISPLAY','')}, WAYLAND={env.get('WAYLAND_DISPLAY','')})")
            subprocess.Popen(
                tokens,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
                env=env,
            )
        except Exception as e:
            print(f"[AppLifecycle] Error spawning process '{command_or_exec}': {e}")

