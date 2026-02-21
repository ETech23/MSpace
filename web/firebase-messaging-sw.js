importScripts('https://www.gstatic.com/firebasejs/9.23.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.23.0/firebase-messaging-compat.js');

// Your Firebase config
// Copy from firebase_options.dart web configuration
firebase.initializeApp({
  apiKey: "AIzaSyC3it3Z27aAQZ6_adgLT8kNCXld3XDZ_pU",
  authDomain: "artisan-marketplace-7105c.firebaseapp.com",
  projectId: "artisan-marketplace-7105c",
  storageBucket: "artisan-marketplace-7105c.appspot.com",
  messagingSenderId: "422368493628",
  appId: "1:422368493628:web:7a0b0f8d9e5f4a3b2c1d0e",
  measurementId: "G-7Q8R9S0T1U2V3W4X5Y6Z7"
});

const messaging = firebase.messaging();

// Background message handler
messaging.onBackgroundMessage((payload) => {
  console.log('Received background message:', payload);

  const notificationTitle = payload.notification?.title || 'New Notification';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data,
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// Notification click handler
self.addEventListener('notificationclick', (event) => {
  console.log('Notification clicked:', event);
  event.notification.close();

  // Navigate to the app
  event.waitUntil(
    clients.openWindow('/')
  );
});