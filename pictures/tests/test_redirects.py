"""Only https and the listed hosts, redirects included (P116). Offline."""
import unittest
import urllib.request

import orbit_pictures as P


class Redirects(unittest.TestCase):
    def follow(self, url):
        req = urllib.request.Request("https://commons.wikimedia.org/w/api.php")
        return P.SafeRedirect().redirect_request(req, None, 302, "Found", {}, url)

    def test_redirect_to_listed_host(self):
        self.assertIsNotNone(self.follow("https://upload.wikimedia.org/a.png"))

    def test_redirect_elsewhere_refused(self):
        for url in ("https://evil.example/a.png", "http://upload.wikimedia.org/a.png",
                    "https://upload.wikimedia.org.evil.example/a.png", "file:///etc/passwd"):
            with self.assertRaises(OSError, msg=url):
                self.follow(url)

    def test_first_request_checked_too(self):
        with self.assertRaises(OSError):
            P.get("http://commons.wikimedia.org/w/api.php")

    def test_user_agent_has_current_version(self):
        self.assertRegex(P.USER_AGENT, r"^orbitBluetooth/\d+\.\d+\.\d+ ")


if __name__ == "__main__":
    unittest.main()
