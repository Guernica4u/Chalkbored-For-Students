/* A fallback, and nothing more.

   CHALK OS asks GitHub what is in the repository's music/, videos/ and
   pictures/ folders - Settings > Storage names the repository - so files put
   there show up without being listed anywhere. This file is only read when
   that cannot be done: no repository named, GitHub unreachable or out of
   answers for the hour, or index.html opened straight off a disk.

   Paths are relative to index.html. Nothing is copied: the files stream from
   where they sit, so size costs you nothing.
*/
window.BOXOS_MEDIA = [
  // "music/a-song.mp3",
  // "videos/a-film.mp4",
];
