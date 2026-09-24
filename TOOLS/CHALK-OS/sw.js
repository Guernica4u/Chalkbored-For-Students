/* Tide's service worker.
 *
 * Every request a page opened through Tide makes - its scripts, its pictures,
 * the things it asks for later on its own - comes through here. Scramjet 2
 * does the actual work in the page that opened the tide: this worker only
 * hands each request over to that page, which sends it out over the
 * connection to your own machine instead of straight to the site.
 *
 * It sits next to index.html so that it covers the whole of CHALK OS, and it
 * does nothing at all until Tide is set up: anything it does not recognise is
 * passed through untouched.
 */
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

addEventListener("fetch", event => {
  if ($scramjetController.shouldRoute(event)) event.respondWith($scramjetController.route(event));
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
