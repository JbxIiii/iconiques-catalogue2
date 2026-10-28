/* ICONIQUES S — garde le site consultable avec une connexion faible ou coupée.
   Pages et catalogue : toujours la version en ligne si possible, sinon la dernière enregistrée.
   Images et polices : affichées tout de suite depuis l'appareil, puis mises à jour en arrière-plan.
   Changer VERSION pour vider les anciennes copies après une grosse mise à jour. */
var VERSION = 'iconiques-v3';
var CORE = ['/', '/catalogue.json', '/manifest.webmanifest', '/icon-192.png', '/icon-512.png', '/favicon.ico', '/fonts/jost-latin.woff2'];

self.addEventListener('install', function (e) {
    e.waitUntil(caches.open(VERSION).then(function (c) { return c.addAll(CORE); }).then(function () { return self.skipWaiting(); }));
});

self.addEventListener('activate', function (e) {
    e.waitUntil(caches.keys().then(function (keys) {
        return Promise.all(keys.filter(function (k) { return k !== VERSION; }).map(function (k) { return caches.delete(k); }));
    }).then(function () { return self.clients.claim(); }));
});

function networkFirst(req) {
    return fetch(req).then(function (res) {
        if (res.ok) { var copy = res.clone(); caches.open(VERSION).then(function (c) { c.put(req, copy); }); }
        return res;
    }).catch(function () {
        return caches.match(req, { ignoreSearch: req.mode === 'navigate' }).then(function (hit) {
            return hit || (req.mode === 'navigate' ? caches.match('/') : Response.error());
        });
    });
}

function staleWhileRevalidate(req) {
    return caches.open(VERSION).then(function (c) {
        return c.match(req).then(function (hit) {
            var fresh = fetch(req).then(function (res) {
                if (res.ok || res.type === 'opaque') c.put(req, res.clone());
                return res;
            }).catch(function () { return hit; });
            return hit || fresh;
        });
    });
}

self.addEventListener('fetch', function (e) {
    var req = e.request;
    if (req.method !== 'GET') return;
    var url = new URL(req.url);
    var fonts = url.hostname === 'fonts.googleapis.com' || url.hostname === 'fonts.gstatic.com';
    if (url.origin !== self.location.origin && !fonts) return; // statistiques, WhatsApp… : jamais mis en cache
    if (req.mode === 'navigate' || /\.(html|json|webmanifest)$/.test(url.pathname) || url.pathname === '/') {
        e.respondWith(networkFirst(req));
    } else if (fonts || /\.(jpe?g|png|webp|ico|css|js|woff2)$/.test(url.pathname)) {
        e.respondWith(staleWhileRevalidate(req));
    }
});
