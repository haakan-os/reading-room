# The Reading Room

A newspaper-inspired KOReader library plugin for Kindle Colorsoft. Version 0.1.2 adds Archive of Our Own integration alongside the formatting fixes from the first on-device photo.

## Changes in 0.1.2

- Added **Discover → Archive of Our Own → Browse AO3**, opening the installed AO3 Downloader menu for search, downloads, downloaded works, work updates, account controls and settings.
- Starting AO3 from an open book returns to KOReader's file browser and invokes its newly loaded AO3 plugin instance.
- Missing or disabled AO3 Downloader shows installation guidance.

Install [AO3 Downloader](https://github.com/IntrovertedMage/AO3Downloader.koplugin/releases) separately: extract its `AO3Downloader.koplugin` folder into the same KOReader `plugins` directory, then restart. The Reading Room does not bundle the downloader. Configure its download folder/account through its own menu. After downloading and opening a work, it can appear in The Reading Room's recent-book history.

## Changes in 0.1.1

- Corrected high-DPI font scaling using a larger calibration sample.
- Current-book title and author are measured before placing progress and buttons; long titles wrap without reserving a large blank gap for short ones.
- Larger recent-book thumbnails, vertically balanced text, and no empty author boxes. The number of recent rows adjusts when the current book needs more space; **View all** still opens the full history.
- Button labels use their rendered height for centering, and button borders paint after text to keep all four edges visible.
- KOReader's dark-mode setting continues to apply.

To update, close KOReader, replace the existing `readingroom.koplugin` directory with the folder from the new ZIP, then restart. Existing home-screen and cover preferences are preserved.

## Install

1. With KOReader already working on your Kindle, close KOReader.
2. Extract `readingroom-0.1.2.zip`. Copy the entire `readingroom.koplugin` directory into the `plugins` directory inside your existing KOReader installation, beside your other `.koplugin` folders.
3. Restart KOReader. Open **Tools → The Reading Room → Open The Reading Room**. Its menu location may vary with your KOReader version.
4. Once you have tried it, enable **Use as library home** in the same menu if desired. This opens the newspaper screen when KOReader's file browser starts. If KOReader is configured to reopen the last book, that startup preference still applies; select File browser as KOReader's startup view to start in The Reading Room.

**Browse files** or the Back key closes the custom screen and reveals the underlying KOReader screen. If you opened The Reading Room while reading, this returns to the book. To uninstall, close KOReader and remove `readingroom.koplugin`; your books and other plugins remain available.

## Included

- **Library:** current/recent books from KOReader history, saved progress, real covers, Resume, book information and collection actions. Titles without saved metadata fall back to filenames. Missing books are skipped. Open-book progress uses the live reader value.
- **Collections:** existing KOReader shelves with native collection management.
- **Discover:** local-library search, Z-library search/recommendations/popular books/My books, and Archive of Our Own via AO3 Downloader.
- **Tools:** BuddySync shelf transfer/settings, KOSync controls for the selected book, and Reading Room preferences.
- A gesture action named **The Reading Room**, usable through KOReader's gesture manager.
- Layout fitted to screen dimensions, portrait and landscape support, explicit e-ink refreshes and monochrome accents when color is disabled.

The main screen uses the newspaper styling. Existing plugin search results, account dialogs, settings and book lists retain their own KOReader styling in this release.

## Integrations

Install and configure integrations separately:

- [BuddySync, included with BuddyPoint](https://github.com/haakan-os/BuddyPoint/tree/main/koreader-plugin/buddysync.koplugin): calls the installed plugin's `sendCurrentBook`, `sendCurrentNotes`, and `syncActiveShelf` actions. Sending a selected book or its notes first opens that book, since BuddySync requires a reader context. The shelf action is delegated unchanged. Use your updated BuddySync with the `ReadHistory.hist` / `item.file` compatibility fix; there is no workaround or bundled BuddySync copy here.
- **KOSync:** KOReader's built-in Progress sync plugin must be enabled. It is available inside an open book, so Tools opens the current/recent book before showing its native sync menu. BuddySync also writes reading progress; choose one plugin for automatic progress updates in their respective settings to avoid competing updates. The Reading Room does not change those settings.
- [Z-library plugin](https://github.com/ZlibraryKO/zlibrary.koplugin): calls the installed search/browse and My books dialogs, retaining the plugin's network, authentication, filters and download handling. This package does not include the plugin or your credentials.
- [AO3 Downloader](https://github.com/IntrovertedMage/AO3Downloader.koplugin): calls `onOpenAO3DownloaderMenu` on the file-manager plugin instance. AO3 search/filter dialogs, EPUB downloads, work updates and account handling remain in the downloader. Its code was reviewed on 2026-10-05; adapter tests simulate its native menu handler, including KOReader's callable handler wrapper. Live AO3 sign-in/downloads have not been tested here.

Installing The Reading Room does not initiate transfers, downloads or sign-ins. Those actions use the installed plugins when you select their controls. Normal book-opening behavior, including automatic sync configured in those plugins, still applies.

## Preview

Open `preview.html` in a browser. It is self-contained and uses sample data. The four screens are generated from the native plugin's display lists; clickable plugin actions show explanations and never connect to services. The preview uses browser fonts and illustrative text-only cover placeholders, so it is not a Kindle screenshot.

## Validation and limits

LuaJIT tests exercise metadata/history handling, missing files/plugins, tab routing, touch-target bounds, screen resizing, resource cleanup, native-dialog delegation, selected-book callback handling and opt-in startup. A separate test ran the updated BuddySync source with a simulated transfer client. Browser checks cover preview navigation, simulated resume, mobile width and JavaScript errors.

Source interfaces were reviewed against KOReader commit `2ce49e115fc1bcc47b473078c549e59b3922105b` and Z-library plugin commit `bc2d851d451bb45b137544312e6cdf34a4e35950`. BuddySync was retrieved from BuddyPoint's updated main branch on 2026-10-05.

**Not yet verified on a physical Colorsoft:** native font/cover rendering, touch gestures, refresh/ghosting behavior, and live plugin authentication or transfers. The tests use KOReader UI doubles rather than a complete KOReader emulator. Launch it manually first before opting into automatic home-screen startup.

## Development

Python 3, `lupa` (LuaJIT backend), and Playwright with Chromium are used only for development, not on the Kindle:

```sh
python3 -m pip install lupa playwright
python3 tests/check.py
python3 scripts/build_preview.py
python3 tests/check_preview.py
python3 scripts/package.py
```

Optionally pass the path to BuddySync's `main.lua` to `tests/check.py` to exercise its real shelf-sync implementation with simulated uploads. Set `CHROMIUM_PATH` if Chromium is not at `/usr/bin/chromium`.

All custom source is in `readingroom.koplugin`. No KOReader core files or third-party plugin files are patched.
