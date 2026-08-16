// Setline no longer ships a web app, so there is no shell worth caching. Earlier
// visitors may still have the previous service worker installed, which would keep
// serving them pages that no longer exist. This replacement exists solely to
// evict those caches and unregister itself.
self.addEventListener("install", () => {
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    (async () => {
      const names = await caches.keys();
      await Promise.all(names.map((name) => caches.delete(name)));
      await self.registration.unregister();
      const clients = await self.clients.matchAll({ type: "window" });
      for (const client of clients) client.navigate(client.url);
    })(),
  );
});
