/* Extra games for the Games app. Optional: Minesweeper and the chalkbored.win
   games are built in, and Games > Add a game adds more from inside the OS.

   Three kinds of line can go in here:

   1. An .html game in this folder:
        "games/my-game.html",
      On GitHub Pages these are found on their own and do not need listing.

   2. A Flash file in this folder - it plays in the built-in Flash Player:
        "games/my-flash-game.swf",
      Also found on its own on Pages. A .swf on another site usually will not
      load, because most sites do not let other pages read their files - put
      a copy here instead, or link to a page that plays it (below).

   3. A game that is a page somewhere else - a Unity build, an emulator, a
      page that plays a .swf. It opens in a window exactly as it is:
        { name: "My Game", url: "https://example.com/game/", icon: "🎯",
          color: "#3a7bd5", desc: "What you do", size: "960x640" },
      Only name and url are needed. These always need listing here, even on
      Pages, since GitHub cannot see another site.
*/
window.BOXOS_GAMES = [
  /* Learn Archery, Car Maintenance and Chalk Console are built into
     index.html now, so they show up even without this file. */

  /* Listed as a page rather than left to be found, so it opens with a proper
     address of its own: Eaglercraft keeps its worlds in the browser's
     storage, which the locked-down frame used for found games does not allow. */
  { name: "Eaglercraft", url: "games/eaglercraft.html", icon: "⛏️", color: "#5b8731",
    desc: "Minecraft 1.8 in the browser - worlds are kept in this browser", size: "1100x700" }
];

