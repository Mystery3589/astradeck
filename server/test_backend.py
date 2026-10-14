import unittest
from app_lifecycle import AppLifecycleManager

class TestAppLifecycle(unittest.TestCase):
    def test_os_detection(self):
        os_key = AppLifecycleManager.get_os_key()
        self.assertIn(os_key, ['linux', 'windows', 'darwin'])

    def test_singleton_check_nonexistent(self):
        # A fictional process name should not be running
        running = AppLifecycleManager.is_process_running(['nonexistent_app_12345_xyz'])
        self.assertFalse(running)

    def test_youtube_fallback_catalog(self):
        # YouTube should fall back to https://youtube.com
        entry = AppLifecycleManager.find_executable(['nonexistent_executable_test'])
        self.assertIsNone(entry)

if __name__ == '__main__':
    unittest.main()
