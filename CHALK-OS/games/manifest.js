/* Games that are pages somewhere else - a Unity build, an emulator,
   Eaglercraft. Everything here is optional.

   The .html games in this folder are found on their own: CHALK OS asks GitHub
   what is in the repository, so they need no listing. Games you add with
   Games > Add a game are kept inside CHALK OS and need no listing either.
   What does belong here is a game that lives at an address of its own, or one
   in this folder that should open as a page rather than in a sandbox:

     { name: "My Game", url: "https://example.com/game/", icon: "🎯",
       color: "#3a7bd5", desc: "What you do", size: "960x640" },
*/
window.BOXOS_GAMES = [
  /* Listed as a page rather than left to be found, so it opens with a proper
     address of its own: Eaglercraft keeps its worlds in the browser's
     storage, which the locked-down frame used for found games does not allow. */
  { name: "Eaglercraft", url: "games/eaglercraft.html", icon: "⛏️", color: "#5b8731",
    desc: "Minecraft 1.8 in the browser - worlds are kept in this browser", size: "1100x700" }
];
