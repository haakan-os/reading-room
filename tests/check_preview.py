from pathlib import Path
import os
from playwright.sync_api import sync_playwright

root = Path(__file__).resolve().parents[1]
with sync_playwright() as p:
    browser = p.chromium.launch(executable_path=os.environ.get("CHROMIUM_PATH", "/usr/bin/chromium"), headless=True, args=["--no-sandbox"])
    page = browser.new_page(viewport={"width": 1080, "height": 1060}, device_scale_factor=1)
    errors = []
    page.on("pageerror", lambda error: errors.append(str(error)))
    page.set_content((root / "preview.html").read_text())
    page.locator("#screen").screenshot(path=str(root / "preview-library.png"))
    for title in ["Collections", "Discover", "Tools"]:
        page.get_by_role("button", name=title, exact=True).first.click()
        assert page.locator('nav button[aria-current=true]').inner_text() == title
        page.locator("#screen").screenshot(path=str(root / f"preview-{title.lower()}.png"))
    page.get_by_role("button", name="Discover", exact=True).first.click()
    page.get_by_role("button", name="Browse AO3 →", exact=True).click()
    assert "AO3 Downloader" in page.locator("#toast").inner_text()
    page.get_by_role("button", name="Library", exact=True).first.click()
    page.get_by_role("button", name="Continue reading →", exact=True).click()
    assert "saved position" in page.locator("#toast").inner_text()
    page.set_viewport_size({"width": 390, "height": 900})
    assert page.evaluate("document.documentElement.scrollWidth <= window.innerWidth")
    assert not errors, errors
    browser.close()
print("PASS preview navigation, simulated resume/AO3, mobile width and browser errors")
