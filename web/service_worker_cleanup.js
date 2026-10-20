(function () {
      if (!('serviceWorker' in navigator)) return;
      Promise.resolve()
        .then(function () { return navigator.serviceWorker.getRegistrations(); })
        .then(function (registrations) {
          return Promise.all(registrations.map(function (registration) {
            return registration.unregister();
          }));
        })
        .then(function () {
          if (!window.caches) return [];
          return caches.keys().then(function (keys) {
            return Promise.all(keys.map(function (key) { return caches.delete(key); }));
          });
        })
        .then(function () {
          if (navigator.serviceWorker.controller &&
              !sessionStorage.getItem('uchetsd_sw_cache_cleared')) {
            sessionStorage.setItem('uchetsd_sw_cache_cleared', '1');
            window.location.reload();
          }
        })
        .catch(function (error) {
          console.warn('Service worker cleanup failed:', error);
        });
    })();
