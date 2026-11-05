// One-time Flutter offline worker retirement; preserves IndexedDB and user data.
self.addEventListener('install', function () {
  self.skipWaiting();
});
self.addEventListener('activate', function (event) {
  event.waitUntil((async function () {
    await Promise.all([
      caches.delete('flutter-app-cache'),
      caches.delete('flutter-temp-cache'),
      caches.delete('flutter-app-manifest')
    ]);
    await self.registration.unregister();
    const windows = await self.clients.matchAll({
      type: 'window',
      includeUncontrolled: true
    });
    for (const client of windows) {
      try { await client.navigate(client.url); }
      catch (_) { /* Page closed during migration. */ }
    }
  })());
});
