// Firebase Cloud Messaging Service Worker for NiosMess Web
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBkUhRH8VhbdrkEBkDw7ZGExrqQ1RKZMik',
  appId: '1:1071718522582:web:a189cbf4f8a1b033c27377',
  messagingSenderId: '1071718522582',
  projectId: 'niosmess-push',
  authDomain: 'niosmess-push.firebaseapp.com',
  storageBucket: 'niosmess-push.firebasestorage.app',
  measurementId: 'G-YWXBMZ5GN6'
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  const data = payload.data || {};
  const isCall = data.type === 'incoming_call';
  const title = payload.notification?.title || data.title || (isCall ? (data.caller_nickname || 'NiosMess') : 'NiosMess');
  const body = payload.notification?.body || data.body || (isCall ? (data.is_video === 'true' ? 'Входящий видеозвонок' : 'Входящий звонок') : 'Новое сообщение');
  const tag = isCall ? ('call-' + (data.room_id || 'active')) : ('chat-' + (data.chat_id || 'msg'));

  const notificationOptions = {
    body: body,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: tag,
    requireInteraction: isCall,
    data: data
  };

  return self.registration.showNotification(title, notificationOptions);
});

self.addEventListener('notificationclick', function(event) {
  event.notification.close();
  const data = event.notification.data || {};
  const chatId = data.chat_id;
  const targetPath = chatId ? ('#/chat/' + chatId) : '#/';

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(clientList) {
      for (let i = 0; i < clientList.length; i++) {
        const client = clientList[i];
        if (client.url && 'focus' in client) {
          client.postMessage({ type: 'niosmess_notification_click', data: data });
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(targetPath);
      }
    })
  );
});
