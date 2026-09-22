/* Tide's service worker.
 *
 * Every request a page opened through Tide makes - its scripts, its pictures,
 * the things it asks for later on its own - comes through here and goes out
 * over the connection to your own machine instead of straight to the site.
 * That is what makes pages that build themselves in the browser work.
 *
 * It sits next to index.html so that it covers the whole of CHALK OS, and it
 * does nothing at all until Tide is set up: anything it does not recognise is
 * passed through untouched.
 */
importScripts("tide/scram/scramjet.all.js");

const { ScramjetServiceWorker } = $scramjetLoadWorker();
const scramjet = new ScramjetServiceWorker();

async function handleRequest(event){
  try {
    await scramjet.loadConfig();
    if (scramjet.route(event)) return scramjet.fetch(event);
  } catch (err){
    /* not set up yet, or a half-written config - let the request go as it is */
  }
  return fetch(event.request);
}

self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", event => event.waitUntil(self.clients.claim()));
self.addEventListener("fetch", event => event.respondWith(handleRequest(event)));
