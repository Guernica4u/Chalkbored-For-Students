/* Files that ship with the repository.
 *
 * On GitHub Pages SEA OS asks GitHub what is in videos/ and music/ and this
 * file is not needed. Everywhere else - opening index.html straight off your
 * disk, or any other host - a browser cannot list a folder, so name the files
 * here and they will appear in Videos and Music inside SEA OS.
 *
 * Paths are relative to index.html. Nothing is copied: the files stream from
 * where they sit, so size costs you nothing.
 */
window.BOXOS_MEDIA = [
  "music/test-tone.wav"
  // "videos/test.mp4",
];
