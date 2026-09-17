// Firebase Cloud Messaging Service Worker for NiosMess Web
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBKS1OjGKwwJmvEnBwg8q1_WDw1G_def2w',
  appId: '1:825221435616:web:225ca60a8de4e3ce388085',
  messagingSenderId: '825221435616',
  projectId: 'niosmes',
  authDomain: 'niosmes.firebaseapp.com',
  storageBucket: 'niosmes.firebasestorage.app',
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
