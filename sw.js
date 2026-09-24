/* Tide's service worker.
 *
 * Every request a page opened through Tide makes - its scripts, its pictures,
 * the things it asks for later on its own - comes through here.
 *
 * Scramjet 2 (the default) does the actual work in the page that opened the
 * tide: this worker only hands each request over to that page, which sends it
 * out over the connection to your own machine instead of straight to the site.
 * Scramjet 1.1.0, chosen in Settings, registers this worker as sw.js?v=1 and
 * does the work here instead.
 *
 * It sits next to index.html so that it covers the whole of CHALK OS, and it
 * does nothing at all until Tide is set up: anything it does not recognise is
 * passed through untouched.
 */
const SCRAMJET_1 = new URL(location.href).searchParams.get("v") === "1";

if (SCRAMJET_1){
  importScripts("tide/v1/scram/scramjet.all.js");
  const { ScramjetServiceWorker } = $scramjetLoadWorker();
  const scramjet = new ScramjetServiceWorker();
  self.addEventListener("install", () => self.skipWaiting());
  self.addEventListener("activate", event => event.waitUntil(self.clients.claim()));
  self.addEventListener("fetch", event => event.respondWith((async () => {
    try {
      await scramjet.loadConfig();
      if (scramjet.route(event)) return scramjet.fetch(event);
    } catch (err){
      /* not set up yet, or a half-written config - let the request go as it is */
    }
    return fetch(event.request);
  })()));
} else {
importScripts("tide/controller/controller.sw.js");

const TIDE_GO = new URL("tide/go/", self.registration.scope).pathname;

/* A browser stops an idle service worker after a while and starts it again on
   the next request, having forgotten which pages run the tide. Those pages
   are told to introduce themselves again (below), so a request that arrives
   in that moment waits for them instead of failing. */
async function routeWhenReady(event){
  for (let i = 0; i < 50; i++){
    await new Promise(done => setTimeout(done, 100));
    if ($scramjetController.shouldRoute(event)) return $scramjetController.route(event);
  }
  return new Response("The tide lost track of this page. Reload it.", {
    status: 503, headers: { "Content-Type": "text/plain; charset=utf-8" }
  });
}

/* A tide page opened on its own in a new tab or window has nothing running
   the tide behind it and would only show an error, so say so plainly. Links
   that ask for a new tab normally open in place; this catches the rest. */
const ESCAPED = `<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Opened in a new tab</title>
<style>body{margin:0;min-height:100vh;display:grid;place-items:center;background:#0c0d10;color:#e8e8e6;font:15px system-ui,sans-serif;text-align:center;padding:16px}
button{margin-top:16px;padding:10px 24px;background:#6ee7a8;color:#000;border:0;border-radius:4px;font-size:14px;cursor:pointer}p{color:#a6a6a4;max-width:36ch}</style>
<div><h2>This opened in a new tab</h2><p>Pages through the tide only work inside Chalk TV or CHALK OS. Go back to that tab - this one can be closed.</p>
<button onclick="window.close()">Close this tab</button></div>`;

addEventListener("fetch", event => {
  const req = event.request;
  if (req.mode === "navigate" && req.destination === "document" && new URL(req.url).pathname.startsWith(TIDE_GO))
    event.respondWith(new Response(ESCAPED, { headers: { "Content-Type": "text/html; charset=utf-8" } }));
  else if ($scramjetController.shouldRoute(event)) event.respondWith($scramjetController.route(event));
  else if (new URL(event.request.url).pathname.startsWith(TIDE_GO)) event.respondWith(routeWhenReady(event));
});

/* Scramjet only tells the pages this worker controls to introduce themselves
   again. Chalk TV runs the tide from outside this folder, so tell every
   other page of the site as well. */
setTimeout(async () => {
  const mine = new Set((await clients.matchAll({ type: "window" })).map(c => c.id));
  for (const client of await clients.matchAll({ type: "window", includeUncontrolled: true }))
    if (!mine.has(client.id)) client.postMessage({ $controller$swrevive: {} });
}, 100);
}
