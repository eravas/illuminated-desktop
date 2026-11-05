"""dev/cloud-setup.sh must build the same runtime as dev/Dockerfile."""
import re
import unittest
from pathlib import Path

DEV = Path(__file__).resolve().parents[1] / 'dev'


class CloudRuntime(unittest.TestCase):
    def test_same_archive_and_packages(self):
        docker = (DEV / 'Dockerfile').read_text()
        cloud = (DEV / 'cloud-setup.sh').read_text()
        self.assertEqual(re.search(r'ARG ARCH_DATE=(\S+)', docker)[1], re.search(r'^ARCH_DATE=(\S+)', cloud, re.M)[1])
        docker_packages = re.search(r'pacman -Syu --noconfirm ([^;]+);', docker)[1].split()
        cloud_packages = re.search(r'^PACKAGES="([^"]+)"', cloud, re.M)[1].split()
        self.assertEqual(sorted(docker_packages), sorted(cloud_packages))


if __name__ == '__main__':
    unittest.main()
