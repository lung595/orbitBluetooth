import json
import os
import tempfile
import unittest
from unittest import mock

import orbit_pictures as P


def model(name, widths=(256, 512, 1024), host="media.sketchfab.com", user="Ada"):
    return {
        "name": name,
        "viewerUrl": "https://sketchfab.com/3d-models/x",
        "user": {"displayName": user},
        "thumbnails": {"images": [{"url": "https://%s/%d.jpg" % (host, w), "width": w} for w in widths]},
    }


class MatchTest(unittest.TestCase):
    def test_title_must_contain_the_model(self):
        self.assertTrue(P.matches("Sony WH-1000XM6 Headphones", "WH-1000XM6"))
        self.assertTrue(P.matches("Sony XM6 headphones 1000xm6", "WH-1000XM6"))
        self.assertFalse(P.matches("Sony WH-1000XM5", "WH-1000XM6"))
        self.assertFalse(P.matches("Headphones", "WH-1000XM6"))

    def test_suffix_in_brackets_is_ignored(self):
        self.assertTrue(P.matches("Galaxy Buds2 Pro", "Galaxy Buds2 Pro (A1B2)"))

    def test_too_short_names_never_match(self):
        self.assertEqual(P.needles("XM"), [])
        self.assertFalse(P.matches("anything xm", "XM"))

    def test_slug(self):
        self.assertEqual(P.slug("WH-1000XM6"), "wh1000xm6")
        self.assertEqual(P.slug("Galaxy Buds2 Pro (A1B2)"), "galaxybuds2pro")


class PickTest(unittest.TestCase):
    def test_smallest_sharp_enough_image(self):
        url, credit = P.pick_sketchfab([model("Sony WH-1000XM6")], "WH-1000XM6", "CC BY")
        self.assertTrue(url.endswith("/512.jpg"))
        self.assertEqual(credit["author"], "Ada")
        self.assertEqual(credit["license"], "CC BY")

    def test_largest_when_all_are_small(self):
        url, _ = P.pick_sketchfab([model("WH-1000XM6", widths=(100, 200))], "WH-1000XM6", "CC0")
        self.assertTrue(url.endswith("/200.jpg"))

    def test_other_hosts_and_wrong_models_are_skipped(self):
        results = [model("WH-1000XM6", host="evil.example.com"), model("WH-1000XM5"), model("WH-1000XM6 v2")]
        url, credit = P.pick_sketchfab(results, "WH-1000XM6", "CC BY")
        self.assertEqual(credit["title"], "WH-1000XM6 v2")
        self.assertIsNone(P.pick_sketchfab(results[:2], "WH-1000XM6", "CC BY"))

    def test_http_is_refused(self):
        m = model("WH-1000XM6")
        m["thumbnails"]["images"] = [{"url": "http://media.sketchfab.com/a.jpg", "width": 512}]
        self.assertIsNone(P.pick_sketchfab([m], "WH-1000XM6", "CC BY"))


def page(title, index=1, license="CC BY-SA 4.0", artist='<a href="x">Bob</a>', url="https://upload.wikimedia.org/t/512.jpg"):
    return {"title": title, "index": index, "imageinfo": [{
        "thumburl": url, "thumbwidth": 512, "descriptionurl": "https://commons.wikimedia.org/wiki/" + title,
        "extmetadata": {"LicenseShortName": {"value": license}, "Artist": {"value": artist}}}]}


class CommonsTest(unittest.TestCase):
    def test_credit_and_license(self):
        url, credit = P.pick_commons([page("File:Sony WH-1000XM4.jpg")], "WH-1000XM4")
        self.assertEqual(credit["author"], "Bob")
        self.assertEqual(credit["license"], "CC BY-SA 4.0")
        self.assertEqual(credit["source"], "Wikimedia Commons")
        self.assertEqual(credit["title"], "Sony WH-1000XM4")

    def test_search_order_wins(self):
        pages = [page("File:B WH-1000XM4.jpg", index=2), page("File:A WH-1000XM4.jpg", index=1)]
        self.assertEqual(P.pick_commons(pages, "WH-1000XM4")[1]["title"], "A WH-1000XM4")

    def test_only_free_licenses_and_right_models(self):
        pages = [page("File:WH-1000XM4.jpg", license="All rights reserved"),
                 page("File:WH-1000XM4 b.jpg", license="CC BY-NC 4.0"),
                 page("File:WH-1000XM4 c.jpg", license="CC BY-ND 2.0"),
                 page("File:WH-1000XM3.jpg"),
                 page("File:WH-1000XM4 d.jpg", license="Public domain")]
        self.assertEqual(P.pick_commons(pages, "WH-1000XM4")[1]["title"], "WH-1000XM4 d")

    def test_other_host_refused(self):
        self.assertIsNone(P.pick_commons([page("File:WH-1000XM4.jpg", url="https://evil.example/a.jpg")], "WH-1000XM4"))

    def test_fallback_to_sketchfab_when_commons_has_nothing(self):
        def fake_get(url):
            if url.startswith(P.COMMONS_API):
                return b'{"batchcomplete": ""}'
            if url.startswith(P.SKETCHFAB_API):
                return json.dumps({"results": [model("TV Samsung QN90")]}).encode()
            return b"x"

        with tempfile.TemporaryDirectory() as d, mock.patch.object(P, "get", fake_get):
            self.assertEqual(P.find("QN90", d)["credit"]["source"], "Sketchfab")


class FindTest(unittest.TestCase):
    def test_search_sends_only_the_name_and_caches(self):
        calls = []

        def fake_get(url):
            calls.append(url)
            if url.startswith(P.COMMONS_API):
                return b"{}"
            if url.startswith(P.SKETCHFAB_API):
                return json.dumps({"results": [model("Sony WH-1000XM6")]}).encode()
            return b"jpegdata"

        with tempfile.TemporaryDirectory() as d, mock.patch.object(P, "get", fake_get):
            first = P.find("WH-1000XM6", d)
            with open(first["image"], "rb") as f:
                self.assertEqual(f.read(), b"jpegdata")
            self.assertEqual(first["credit"]["source"], "Sketchfab")
            n = len(calls)
            second = P.find("WH-1000XM6", d)
            self.assertEqual(second["image"], first["image"])
            self.assertEqual(len(calls), n, "second lookup must not use the network")
        self.assertIn("gsrsearch=WH-1000XM6+filetype%3Abitmap", calls[0])
        self.assertIn("q=WH-1000XM6", calls[1])

    def test_cache_is_private(self):
        # Even a cache folder an older version made world-readable is closed
        def fake_get(url):
            if url.startswith(P.COMMONS_API):
                return b"{}"
            if url.startswith(P.SKETCHFAB_API):
                return json.dumps({"results": [model("Sony WH-1000XM6")]}).encode()
            return b"jpegdata"

        with tempfile.TemporaryDirectory() as d, mock.patch.object(P, "get", fake_get):
            folder = os.path.join(d, "pictures")
            os.makedirs(folder, mode=0o755)
            os.chmod(folder, 0o755)
            found = P.find("WH-1000XM6", folder)
            self.assertEqual(os.stat(folder).st_mode & 0o777, 0o700)
            self.assertEqual(os.stat(found["image"]).st_mode & 0o777, 0o600)
            meta = found["image"][:-4] + ".json"
            self.assertEqual(os.stat(meta).st_mode & 0o777, 0o600)

    def test_nothing_found_is_remembered(self):
        calls = []

        def fake_get(url):
            calls.append(url)
            return b'{"results": []}'

        with tempfile.TemporaryDirectory() as d, mock.patch.object(P, "get", fake_get):
            self.assertIsNone(P.find("Unknown Gadget 9", d)["image"])
            n = len(calls)
            self.assertIsNone(P.find("Unknown Gadget 9", d)["image"])
            self.assertEqual(len(calls), n)

    def test_offline_is_not_remembered(self):
        def offline(url):
            raise OSError("offline")

        with tempfile.TemporaryDirectory() as d, mock.patch.object(P, "get", offline):
            self.assertIsNone(P.find("WH-1000XM6", d)["image"])
            self.assertEqual(os.listdir(d), [])


if __name__ == "__main__":
    unittest.main()
