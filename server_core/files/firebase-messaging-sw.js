importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

// Replace with your Firebase project config.
const firebaseConfig = {
    apiKey: "YOUR_API_KEY",
    authDomain: "YOUR_PROJECT_ID.firebaseapp.com",
    projectId: "YOUR_PROJECT_ID",
    storageBucket: "YOUR_PROJECT_ID.appspot.com",
    messagingSenderId: "YOUR_SENDER_ID",
    appId: "YOUR_APP_ID"
};

firebase.initializeApp(firebaseConfig);
const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
    const data = payload.data || {};
    const type = data.type || 'chat_event';

    let title = payload.notification?.title || 'NiosMess';
    let body = payload.notification?.body || 'New activity';
    let tag = `niosmess-${type}`;
    let requireInteraction = false;
    let actions = [];

    if (type === 'incoming_call') {
        title = data.caller_nickname || 'NiosMess';
        body = data.is_video === 'true' ? 'Входящий видеозвонок' : 'Входящий звонок';
        tag = `call-${data.room_id}`;
        requireInteraction = true;
        actions = [
            { action: 'accept_call', title: 'Принять' },
            { action: 'decline_call', title: 'Сбросить' }
        ];
    } else if (type === 'new_message') {
        title = data.title || title;
        body = data.body || 'Новое сообщение';
        tag = `chat-${data.chat_id}`;
    }

    const notificationOptions = {
        body: body,
        icon: 'https://ni-os.ru/static/avatars/default.jpg',
        badge: 'https://ni-os.ru/static/avatars/default.jpg',
        tag: tag,
        requireInteraction: requireInteraction,
        actions: actions,
        data: data,
        sound: 'default'
    };

    self.registration.showNotification(title, notificationOptions);
});

self.addEventListener('notificationclick', (event) => {
    event.notification.close();
    const data = event.notification.data || {};
    const type = data.type;

    event.waitUntil(
        clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
            let targetUrl = '/';
            if (type === 'incoming_call' && data.chat_id && data.room_id) {
                targetUrl = `/?action=incoming_call&chat_id=${encodeURIComponent(data.chat_id)}&room_id=${encodeURIComponent(data.room_id)}&message_id=${encodeURIComponent(data.message_id || '')}&caller_id=${encodeURIComponent(data.caller_id || '')}&caller_nickname=${encodeURIComponent(data.caller_nickname || '')}&is_video=${encodeURIComponent(data.is_video || 'false')}`;
            } else if (type === 'new_message' && data.chat_id) {
                targetUrl = `/?chat_id=${encodeURIComponent(data.chat_id)}`;
            }

            for (const client of clientList) {
                if (client.url && 'focus' in client) {
                    client.postMessage({ type: 'niosmess_focus', payload: data });
                    return client.focus();
                }
            }
            if (clients.openWindow) {
                return clients.openWindow(targetUrl);
            }
        })
    );
});

self.addEventListener('notificationclose', (event) => {
    const data = event.notification.data || {};
    if (data.type === 'incoming_call') {
        // User dismissed the call notification; treat as declined.
        // The main app will send end_call when it reconnects.
    }
});
