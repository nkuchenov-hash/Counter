// One-time legacy Flutter PWA worker retirement.
self.addEventListener('install', function () {
  self.skipWaiting();
});
self.addEventListener('activate', function (event) {
  event.waitUntil((async function () {
    await Promise.all([
      caches.delete('flutter-app-cache'),
      caches.delete('flutter-temp-cache'),
    ]);
    await self.registration.unregister();
    const windows = await self.clients.matchAll({type: 'window', includeUncontrolled: true});
    for (const windowClient of windows) {
      try { await windowClient.navigate(windowClient.url); }
      catch (_) { /* A closed tab can be ignored. */ }
    }
  })());
});
