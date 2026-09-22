# CHALK OS

A small desktop operating system that lives in a single HTML file. Open
`index.html` in a browser and you get a window manager, a filesystem, a file
manager with an editor, a terminal, a browser, and a handful of apps.

There is no build step, no dependencies and no server. It is one file.

## Running it

Open `index.html` — double-click it, or serve the folder and visit it in a
browser. Both work.

## Making it yours

### Wallpaper and boot screen from a file

Drop a file next to `index.html` and CHALK OS picks it up on startup:

| File | What it does |
| --- | --- |
| `wallpaper.mp4` / `.webm` | Plays on a loop behind the desktop |
| `wallpaper.jpg` / `.jpeg` / `.png` / `.gif` | Still desktop background |
| `boot.mp4` / `.webm` | Plays once while CHALK OS starts |
| `boot.jpg` / `.jpeg` / `.png` / `.gif` | Shows briefly while CHALK OS starts |

Nothing else is needed — commit the file and it is picked up. Anything you
choose inside **Settings** overrides these, so the files are defaults rather
than hard rules.

### Desktop environments

**Settings → Desktop environment** switches the whole shell:

- **macOS** (default) — menu bar on top with working File/Edit/View/Window
  menus that change with the focused app, a dock you can pin to and
  right-click, and traffic lights on the left of each window.
- **Mint** — panel along the bottom, window list, menu button.
- **Hyprland** — tiling. One window fills the screen, two split into a master
  and a stack, and the rest share the right-hand side.

### Video, music and pictures from the repo

Put files in `videos/`, `music/` and `pictures/` and they appear in CHALK OS under
Videos, Music and Pictures — in the Videos, Media and Photos apps.

They are **linked, not copied** — a node points at the path, so a 200 MB video
costs nothing in browser storage and simply streams from the repo.

On GitHub Pages the files are found automatically through GitHub's API. Anywhere
else — including opening `index.html` off your disk — a browser cannot list a
folder, so name them in `media/manifest.js`.

## Apps: the CHALK Store

An app is one `.html` file. Put it in `apps/` and it shows up in the **CHALK
Store**, ready to install into the menu and the Dock. `apps/sticky-notes.html`
and `apps/focus-timer.html` are working examples.

A few tags at the top name it:

```html
<title>My App</title>
<meta name="description" content="What it does">
<meta name="box-icon" content="🧩">
<meta name="box-size" content="640x480">
```

Apps run sandboxed and cannot reach CHALK OS itself. They get `window.box`
instead — `notify`, `saveFile` / `readFile` / `listFiles` (scoped to
`~/Documents/<App name>/`) and `openFile` (only a file the user picks) — plus
`--box-*` CSS variables that follow the desktop theme.

On GitHub Pages the folder is listed automatically. Anywhere else, add each app
to `apps/manifest.js`.

**Playground** is the quickest way to make one: write HTML, CSS and JavaScript in
three tabs with a live preview and a console, then choose **More → Install as
app**. It runs Python too, through Pyodide, which downloads the first time.

## Games

The **Games** app is a launcher for the games you put in `games/`, each one an
`.html` file, plus the built-in Minesweeper. They run sandboxed like Store apps
and keep a best score each.

Add your own by dropping a file in `games/` with the same tags as an app, plus
`<meta name="box-color" content="#3a7bd5">` for its tile. Scores go through
`box.getHighScore()` and `box.submitScore(score)`. Off GitHub Pages, list the
file in `games/manifest.js`.

Games may lock the mouse pointer - `requestPointerLock()` works inside a game,
a Store app and the Playground preview - so moving the mouse aims instead of
moving the cursor. Esc gives the pointer back.

**Game mode**, in Settings, boots CHALK OS straight into one game, maximised and
full screen. Browsers only grant full screen off a click, so the first click
after startup finishes it. Esc leaves full screen; close the game for the
desktop.

## Chat

`chat.html` is a Firebase-backed chat that runs as an app inside CHALK OS. It has
to sit next to `index.html`; if it is missing, the Chat app says so instead of
failing silently. Because it ships with the OS it runs as a first-party app,
unlike HTML you import yourself, which stays sandboxed.

Its Firebase web config is in the file. That is normal — Firebase web API keys
are public identifiers, not secrets; access is controlled by database rules and
domain restrictions.

## Saving your work

Nothing is written to your browser unless you turn on **Settings → Storage →
Save my files**. Turning it off deletes everything CHALK OS has stored. There is
also **Back up to a file**, which exports the whole machine as JSON and works
whether or not saving is on.

Large videos often will not fit in browser storage. CHALK OS tells you when that
happens rather than quietly losing them.

## Seahorse, the browser

Out of the box it reads Wikipedia, Stack Overflow, GitHub READMEs, Wiktionary,
Hacker News and DuckDuckGo answers — directly, with no middleman.

Anything else only opens if the site allows other pages to read it, and almost
none do: a page in a browser cannot fetch other websites for itself, and GitHub
Pages cannot do it on its behalf. Links to files download into Downloads inside
CHALK OS, never onto the computer.

Give the Worker your own origin in `ALLOWED_ORIGINS`, or you are running an
open relay for the whole internet on your quota.

## Widgets

A clock, the weather and a now-playing card can sit on the desktop — right-click
the desktop, or **Settings → Widgets**. Weather comes from Open-Meteo, which
needs no key.

## Keyboard

| Keys | Action |
| --- | --- |
| `Ctrl+Alt+←/→/↑/↓` | Tile the window |
| `Ctrl+Alt+T` / `F` / `B` | Terminal, Files, Browser |
| `Alt+Tab` | Cycle windows |
| `Ctrl+C` / `X` / `V` / `A` | Copy, cut, paste, select all in Files |
| `Delete` | Move to Trash (`Shift+Delete` deletes for good) |
| `Tab` | Complete commands and paths in the terminal |

## Media and links

**Media** plays your music and videos, and links. **Add media**, at the top
right, offers three ways in: paste a link, play a file already in CHALK OS, or
import one from the computer into `~/Music` or `~/Videos`. **Videos** has the
same button.

A link can be a direct link to an audio or video file, or a page on YouTube,
Vimeo, Dailymotion, Twitch, Kick, Streamable, the Internet Archive, Bilibili,
Odysee, TED, TikTok, Facebook, Loom, Rumble (embed links), any PeerTube server
or SoundCloud - each plays in that site's own player. Any other site is tried
too, by showing the page itself, which only works where the site allows it. YouTube plays in
its own player inside Media, and Media's controls drive it. Links you open are
kept under **From the web**.

**Videos** remembers where you stopped a video - one of your files or a direct
link - and picks up there next time, with a **Start over** button. Its tile
shows how far through you are.

## The name

The desktop calls itself **CHALK OS**. **Settings → Appearance → Call it**
switches it to **SEA OS** and back: the boot screen, the menu bar, the Terminal
prompt, the Store and the help all follow. Everything else - the files, the
settings, the apps you installed - stays exactly where it is.

## MP3 Player

A player for one song at a time: the cover turns like a record, the title
slides across when the song changes, and a bar along the bottom says what is
playing next. Click that bar for the whole tracklist, where a menu picks the
playlist - everything you have, one per folder, and one for links - with
shuffle, repeat and a + button for adding more music.

Covers and titles come out of each file's own ID3 tags. Without tags, a picture
named `cover` or `folder` beside the song is used, and failing that the first
letter of its name on a coloured disc.

**Settings → Startup** chooses what opens when CHALK OS starts: the desktop,
a game, or the MP3 Player filling the screen.

## Tide

Most sites refuse to be shown inside another page, so Seahorse can only read a
handful of them on its own. Tide gets round that: a small server on a machine
you own opens the connection, and [Scramjet](https://github.com/MercuryWorkshop/scramjet)
- installed as a service worker beside this page - rewrites what comes back so
the site behaves normally.

Put the server's address and key into **Settings → Tide**, press Test, then
Save. From then on any address typed into Seahorse opens through it. Downloads
land in `~/Downloads` inside CHALK OS, never on the real computer.

It needs two things next to `index.html` on whatever hosts CHALK OS:

* `sw.js` - the service worker
* `tide/` - Scramjet 1.1.0, bare-mux 2.1.9 and libcurl-transport 1.5.2 (about
  2.8 MB, vendored from npm; the same versions Mercury's own scramjet-app pins)

Those versions matter. libcurl-transport 2.x iterates the request headers,
while bare-mux 2.1.9 hands a transport a plain object, so every request fails
with "headers is not iterable". 1.5.2 passes the headers through untouched and
is the version Scramjet 1.1.0 is tested against.

Both have to be on an `https://` address; a page opened from a file on disk
cannot install a service worker.

Video needs a browser that can pass a half-finished download between pages.
Chrome and Edge can; Firefox cannot yet, so pages load there but video says an
error occurred. Settings says so when it applies. Media plays YouTube links
directly, without Tide, either way. Every site visited sees the server machine's
address as the visitor, not yours.

## Spotify

Paste a Spotify playlist, album, song or podcast link into **Add media** and it
opens in Spotify's own player inside Media, and stays in the list. How much of
it plays is Spotify's decision, not ours: whole songs if you are signed in to
Spotify in that browser, thirty-second tastes if you are not. `spotify.link`
short links have to be opened once in a browser first, since the real address
is what CHALK OS reads.

## Locked Notes

A note encrypted with a password of its own - AES-GCM, with the password
stretched by PBKDF2 (310,000 rounds). What lands in the filesystem is
ciphertext, so backups and any copy of CHALK OS someone else gets hold of give
nothing away. The password is never stored: forget it and the note is gone.

It is the right place for a key or a password. Notes are files ending
`.locknote` in `~/Documents`.

## Screen saver

After ten minutes with no mouse or keyboard, CHALK OS shows the boot porthole and
a large clock. It waits while anything is playing, while a game or app has the
mouse, and in full screen. Change the delay, turn it off, or preview it in
**Settings → Appearance → Screen saver**.
