// Firebase Service Worker

importScripts("https://www.gstatic.com/firebasejs/10.12.5/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.12.5/firebase-messaging-compat.js");

// Firebase yapılandırması
try {
  firebase.initializeApp({
    apiKey: "AIzaSyBZj7uR381bcLdwfcBI_BozGVHhIAEa7xs",
    appId: "1:584140094374:web:3882066aa62b8d9e73ad67",
    messagingSenderId: "584140094374",
    projectId: "guard-12345",
    authDomain: "guard-12345.firebaseapp.com",
    storageBucket: "guard-12345.firebasestorage.app",
    measurementId: "G-MLGTVXJ40N",
  });

  const messaging = firebase.messaging();
  console.log("✅ Firebase Service Worker başlatıldı.");

  // Arka planda bildirim alındığında
  messaging.onBackgroundMessage((payload) => {
    console.log("[firebase-messaging-sw.js] Arka planda bildirim alındı: ", payload);

    // Bildirim başlığı ve seçeneklerini özelleştirin
    const notificationTitle = payload.notification?.title || "Guard Bildirimi";
    const notificationOptions = {
      body: payload.notification?.body || "Yeni bir bildirim var.",
      icon: "/icons/Icon-192.png", // Bildirim simgesi (web/icons/Icon-192.png dosyasını kontrol edin)
      badge: "/icons/Icon-192.png", // Bildirim rozeti (isteğe bağlı)
      data: payload.data, // Bildirime ek veri (isteğe bağlı)
    };

    // Bildirimi göster
    self.registration.showNotification(notificationTitle, notificationOptions);
  });

  // Bildirime tıklandığında
  self.addEventListener("notificationclick", (event) => {
    console.log("[firebase-messaging-sw.js] Bildirime tıklandı: ", event);
    event.notification.close(); // Bildirimi kapat

    // Kullanıcıyı bir URL'ye yönlendirme (örneğin, uygulamanın ana sayfası)
    const urlToOpen = new URL("/", self.location.origin).href;
    event.waitUntil(
      clients
        .matchAll({ type: "window", includeUncontrolled: true })
        .then((windowClients) => {
          // Açık bir pencere varsa ona odaklan
          for (let i = 0; i < windowClients.length; i++) {
            const client = windowClients[i];
            if (client.url === urlToOpen && "focus" in client) {
              return client.focus();
            }
          }
          // Açık pencere yoksa yeni bir pencere aç
          if (clients.openWindow) {
            return clients.openWindow(urlToOpen);
          }
        })
    );
  });
} catch (error) {
  console.error("❌ Firebase Service Worker başlatılamadı: ", error);
}