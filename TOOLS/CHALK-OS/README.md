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

### Video, music and pictures from a repository

Put files in `music/`, `videos/` or `pictures/` in a GitHub repository and they
appear in Media and the Gallery. CHALK OS asks GitHub's API what is in those
folders, so nothing has to be listed by hand, and that works from any address -
not only the repository's own Pages site. Name the repository in **Settings →
Storage** as `user/repository`; on a Pages site it works it out itself, and
anywhere else it defaults to CHALK OS's own, `Guernica4u/CHALK-OS`.

Files are mounted as links rather than copied, so a 200 MB video costs nothing
in storage and streams from where it sits. Read from somewhere other than the
Pages site, the files come from that Pages site.

GitHub allows 60 API calls an hour per network, so each folder listing is kept
for six hours, and a stale listing is used rather than none when calls run out.
`media/manifest.js` and `games/manifest.js` still exist as a fallback for when
there is no repository, GitHub cannot be reached, or `index.html` is opened
straight off a disk.

## Apps: the CHALK Store, in Settings

The Store is a page of **Settings → Apps** rather than an app of its own. An
app is one `.html` file. Put it in `apps/` and it shows up there, ready to install into the menu and the Dock. `apps/sticky-notes.html`
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

The **Games** app is a launcher. Games come from **Add a game** inside CHALK OS,
from `games/manifest.js`, and from `.html` files in the repository's `games/`
folder. Games run sandboxed like Store apps and keep a best score each.

Add your own by dropping a file in `games/` with the same tags as an app, plus
`<meta name="box-color" content="#3a7bd5">` for its tile. Scores go through
`box.getHighScore()` and `box.submitScore(score)`. Off GitHub Pages, list the
file in `games/manifest.js`.

Games may lock the mouse pointer - `requestPointerLock()` works inside a game,
a Store app and the Playground preview - so moving the mouse aims instead of
moving the cursor. Esc gives the pointer back.

**Game mode**: right-click a game, in Games or in the Dock, and choose Game
mode. That game fills the whole screen and nothing else runs - anything playing
stops, and the other windows, the desktop and the wallpaper are put away rather
than drawn. Esc belongs to the game there, so hold Esc to leave full screen;
**Leave**, in the bar that drops from the top edge, brings the desktop back.
**Settings → Startup** can boot straight into a game in Game mode.

**Movie mode** is the same for something to watch or listen to: right-click it
in Media, the Gallery or Files. The controls and the pointer fade while the
mouse is still, and Esc leaves.

Game windows are solid rather than Liquid Glass. Blurring what lies behind a
window is redone for every frame drawn inside it, which is what made games slow
to answer keys and clicks.

### Unity, emulators and games on other sites

Games can be pages that live somewhere else - a Unity build, an emulator,
Eaglercraft. Add them to `games/manifest.js` by name and address:

```js
{ name: "Car Maintenance", url: "https://chalkbored.win/Car%20maintenance/",
  icon: "🚗", color: "#34495e", desc: "A Unity game", size: "1100x680" }
```

They open in a window exactly as they are, keeping their own address - which
is what lets a Unity game load its data files and save progress, and
Eaglercraft keep its worlds.

## Chat

**Chat** is live rooms and channels, from `chat.html` beside `index.html` (or
the repository's copy, when CHALK OS is served from somewhere without one). Sign
up with a name and a password - no email. It takes the desktop's colours, light
or dark and your accent, and new messages arrive as notifications and a count on
the Dock while it is not in front. Opened on its own, `chat.html` works as a
standalone page in the same look.

It runs on Supabase. The project URL and publishable key at the top of
`chat.html` are meant to be public; what anyone can do is decided by the
database's row-level security rules.

## Settings

Settings keeps a button for every page down its left side: **Appearance**,
**Wallpaper**, **Desktop**, **Widgets**, **Panel & clock**, **ChalkBrowser**,
the **CHALK Store**, **Startup**, **Storage** and **About** - and
**Developer**, once Developer mode is switched on in Storage, which holds Tide
and the repository's workings. A narrow Settings window keeps the buttons as
icons.

**Developer → Performance meter** puts a strip in the corner: frames a second,
the slowest frame, how long keys and clicks wait, and how busy the page is. It
watches a game's own page too when that game is in front, and stays up in Game
mode.

## Saving your work

Nothing is written to your browser unless you turn on **Settings → Storage →
Save my files**. Turning it off deletes everything CHALK OS has stored. There is
also **Back up to a file**, which exports the whole machine as JSON and works
whether or not saving is on.

Files live in the browser's private file system (OPFS), which holds gigabytes,
so imported songs and videos survive a reload. Only the list of what is where
goes into `localStorage`, where it is small and saves instantly; a big file is
written to disk once, when it arrives, and the list after it. Browsers without
OPFS for pages - Firefox private windows, `index.html` opened from disk - fall
back to keeping everything in `localStorage`, about 5 MB, and say which files
did not fit.

**Settings → Storage → Keep files in** makes that choice yours: **File storage**
(the default) or **localStorage**, which keeps everything in one plain place at
the cost of the 5 MB limit. Switching moves what you have, and lets go of the
old copy only once the new one is written.

## Seahorse, the browser

Out of the box it reads Wikipedia, Stack Overflow, GitHub READMEs, Wiktionary,
Hacker News and DuckDuckGo answers — directly, with no middleman.

**Tabs** work the way you expect: Ctrl+T, Ctrl+W, Ctrl+Tab and Ctrl+1–9, drag
to reorder, middle-click to close, right-click for duplicate and close-others,
and Ctrl+Shift+T to bring one back. A new window opens with last time's tabs.

**Bookmarks**: the ☆ in the address bar (or Ctrl+D) keeps a page, and a
bookmarks bar sits underneath (Ctrl+Shift+B). **History** is kept in this
browser, with a searchable page (Ctrl+H) and suggestions as you type in the
address bar. Settings → ChalkBrowser turns history off or clears it.

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

**Media** is the music player: your songs, and links from the web. A song's
name, artist, album and cover come out of the file's own ID3 tags, and the
cover turns while it plays. The **Gallery** - the picture button at the top of
Media opens it - holds videos and pictures together, with a slideshow and
where-you-stopped for videos.

**Add media**, in both, offers three ways in: paste links, play a file already
in CHALK OS, or import one from the computer into `~/Music`, `~/Videos` or
`~/Pictures`.

**Playlists of links.** Pills above Media's list pick what it shows: Everything,
your Links, or one of your playlists. **+ Playlist** makes one out of nothing
but links - name it and paste them in. Right-click any link to add it to a
playlist or start one with it; inside a playlist, right-click to move a link up
or down or take it out. A link is kept once and can sit in any number of
playlists, so deleting a playlist never loses a link.

Getting things in is meant to be quick:

* **Paste links** takes any number, one a line (Ctrl+Enter adds them).
* **Ctrl+V** in any of the three players adds whatever link you copied.
* **Drag and drop** files off your desktop, or a link from another tab, onto a
  player or its Dock icon.
* **Media keys** on the keyboard play, pause and skip, and Windows shows the song
  and its cover in its own media pop-up.

A link can be a direct link to an audio or video file, or a page on YouTube,
Vimeo, Dailymotion, Twitch, Kick, Streamable, the Internet Archive, Bilibili,
Odysee, TED, TikTok, Facebook, Loom, Rumble (embed links), any PeerTube server
or SoundCloud - each plays in that site's own player. Any other site is tried
too, by showing the page itself, which only works where the site allows it. YouTube plays in
its own player inside Media, and Media's controls drive it. Links you open are
kept under **From the web**.

The Gallery remembers where you stopped a video and picks up there next time,
with a **Start over** button, and its tile shows how far through you are. Links
all stay in Media, whether they are music or video.

## The name

The desktop calls itself **CHALK OS**: a chalk-stick logo, a chalkboard boot
screen where the logo draws itself, and **ChalkBrowser** for the web. New
machines start on the **Paper** wallpaper.

**Settings → Appearance → Call it** switches it back to **SEA OS** - the
sailboat logo, the porthole boot screen and **Seahorse** - and back again.
The menu bar, the Terminal prompt, the Store, the favicon and the help all
follow. Everything else - your files, settings and installed apps - stays
exactly where it is.

## MP3 Player

A **visualizer** draws the music: bars behind the song in Media, a ring round
the cover in the MP3 Player. It works for your own songs and the repository's;
a song from a site that will not let other pages listen still plays, just
without it. View → Hide the visualizer turns it off.

The disc button at the top of **Media** turns it into the MP3 Player, and
**☰ Media** turns it back; it opens next time the way you left it. A player
for one song at a time: the cover turns like a record, the title
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

## Screen saver

After ten minutes with no mouse or keyboard, CHALK OS shows the boot porthole and
a large clock. It waits while anything is playing, while a game or app has the
mouse, and in full screen. Change the delay, turn it off, or preview it in
**Settings → Appearance → Screen saver**.
