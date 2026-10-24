// The custom click listener must precede the Firebase import (FCM contract).
// Only IDs and routing metadata survive a click; no text or credentials in URLs.
const DB = 'niosmess-notification-worker-v2';
function store(mode, action) {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB, 1);
    request.onupgradeneeded = () => request.result.createObjectStore('state');
    request.onerror = () => reject(request.error);
    request.onsuccess = () => {
      const db = request.result, tx = db.transaction('state', mode);
      let result;
      try { result = action(tx.objectStore('state')); } catch (e) { db.close(); reject(e); return; }
      tx.oncomplete = () => { db.close(); resolve(result && result.result); };
      tx.onerror = () => { db.close(); reject(tx.error); };
    };
  });
}
const read = key => store('readonly', s => s.get(key));
const write = (key, value) => store('readwrite', s => s.put(value, key));
function safeClick(data, action) {
  const keep = ['event_id', 'type', 'account_id', 'chat_id', 'message_id', 'call_id',
    'room_id', 'caller_id', 'caller_nickname', 'is_video', 'route', 'username', 'created_at', 'expires_at'];
  const result = {_click_id: Date.now().toString(36) + Math.random().toString(36).slice(2)};
  for (const key of keep) if (data[key] != null) result[key] = data[key];
  if (action) result.notification_action = action;
  return result;
}
function expired(data) {
  const expires = Date.parse(data.expires_at || '');
  return Number.isFinite(expires) && expires <= Date.now();
}
self.addEventListener('notificationclick', event => {
  // Stop Firebase's handler from also opening a second window.
  event.stopImmediatePropagation();
  event.notification.close();
  const data = safeClick(event.notification.data || {}, event.action);
  event.waitUntil((async () => {
    if (expired(data)) return;
    await write('pendingClick', data);
    const windows = await self.clients.matchAll({type: 'window', includeUncontrolled: true});
    const own = windows.find(c => new URL(c.url).origin === self.location.origin);
    if (own) {
      own.postMessage({type: 'niosmess_notification_click', data});
      await own.focus();
    } else await self.clients.openWindow(new URL('./', self.registration.scope).origin + '/');
  })());
});
self.addEventListener('message', event => {
  if (event.data?.type !== 'niosmess_notification_settings') return;
  event.waitUntil((async () => {
    const settings = event.data.data || {};
    await write('settings', settings);
    const notifications = await self.registration.getNotifications();
    for (const n of notifications) {
      if (!settings.enabled || expired(n.data || {}) || String(n.data?.account_id) !== String(settings.account_id)) n.close();
    }
    const click = await read('pendingClick');
    if (!click || !settings.account_id || !settings.ready) return;
    if (click.account_id != null && String(click.account_id) !== String(settings.account_id)) {
      await write('pendingClick', null); return;
    }
    if (!expired(click)) event.source?.postMessage({type:'niosmess_notification_click', data:click});
    await write('pendingClick', null);
  })());
});
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
messaging.onBackgroundMessage(async payload => {
  const data = payload.data || {};
  const settings = await read('settings');
  // Never surface another account's queued push, including after logout.
  if (!settings?.enabled || !settings.account_id || data.account_id == null ||
      String(data.account_id) !== String(settings.account_id)) return;
  const tag = data.type === 'incoming_call' || data.type === 'call_ended'
    ? 'call-' + data.room_id : 'chat-' + (data.chat_id || data.event_id || 'activity');
  if (data.type === 'chat_read') {
    for (const n of await self.registration.getNotifications({tag})) n.close();
    return;
  }
  if (data.type === 'call_ended') {
    const ended = (await read('ended')) || [];
    await write('ended', [...ended, data.room_id].slice(-128));
    for (const n of await self.registration.getNotifications({tag})) n.close();
    return;
  }
  if (expired(data) || (data.type === 'incoming_call' && ((await read('ended')) || []).includes(data.room_id))) return;
  const options = settings?.preferences || {};
  const isCall = data.type === 'incoming_call';
  const category = isCall ? 'calls' : data.chat_id ? 'messages' : 'activity';
  if (options[category] === false || (options.muted_chat_ids || []).map(String).includes(String(data.chat_id))) return;
  const id = data.event_id || (data.message_id ? 'message:' + data.chat_id + ':' + data.message_id : payload.messageId);
  // Store only a bounded recent ID set, never message bodies or encryption keys.
  const seen = (await read('seen')) || [];
  if (id && seen.includes(id)) return;
  if (id) await write('seen', [...seen, id].slice(-128));
  const windows = await self.clients.matchAll({type:'window', includeUncontrolled:true});
  const visible = windows.filter(c => c.visibilityState === 'visible' && c.focused);
  if (visible.length) {
    for (const c of visible) c.postMessage({type:'niosmess_notification_message',data});
    return;
  }
  const ru = (settings?.locale || data.locale || 'en').startsWith('ru');
  const title = data.title || data.caller_nickname || 'NiosMess';
  const body = isCall ? (ru ? 'Входящий звонок' : 'Incoming call') : options.preview === false
    ? (ru ? 'Новое сообщение' : 'New message') : data.body || (ru ? 'Новое сообщение' : 'New message');
  await self.registration.showNotification(title, {
    body, icon:'/icons/Icon-192.png', badge:'/icons/Icon-192.png', tag,
    requireInteraction:isCall, silent:options.sound === false, data,
    actions:isCall ? [{action:'action_accept',title:ru?'Принять':'Accept'},
      {action:'action_decline',title:ru?'Отклонить':'Decline'}] : [],
  });
});
