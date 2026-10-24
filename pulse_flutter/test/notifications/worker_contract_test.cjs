// Executes the production service worker with deterministic browser/FCM ports.
const {readFileSync} = require('node:fs');
const {resolve} = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const {test} = require('node:test');
const source = readFileSync(resolve(__dirname, '../../web/firebase-messaging-sw.js'), 'utf8');

function harness(database = new Map()) {
  const handlers = {}, shown = [], opened = [], posted = [], notifications = [];
  let background;
  const indexedDB = {open() {
    const request = {};
    const db = {close(){}, createObjectStore(){}, transaction() {
      const tx = {objectStore() { return {
        get(key) {return {result:structuredClone(database.get(key))};},
        put(value,key) {database.set(key,structuredClone(value));return {result:key};},
      };}};
      setImmediate(()=>tx.oncomplete?.()); return tx;
    }};
    setImmediate(()=>{request.result=db;request.onsuccess?.();}); return request;
  }};
  const clients = {windows:[], async matchAll(){return this.windows;}, async openWindow(url){opened.push(url);}};
  const self = {clients, location:{origin:'https://fixture.invalid'},
    registration:{scope:'https://fixture.invalid/firebase-cloud-messaging-push-scope',
      async showNotification(title,options){shown.push({title,options});},
      async getNotifications({tag}={}) {return notifications.filter(n=>!tag||n.tag===tag);}},
    addEventListener(type,listener){handlers[type]=listener;}};
  vm.runInNewContext(source, {self, clients, indexedDB, Date, Math, URL, console,
    importScripts(){}, firebase:{initializeApp(){}, messaging(){return {onBackgroundMessage(fn){background=fn;}};}}});
  async function event(type,extra) {
    let work=Promise.resolve();
    handlers[type]({stopImmediatePropagation(){},waitUntil(p){work=p;},...extra}); await work;
  }
  async function settings(data) {await event('message',{data:{type:'niosmess_notification_settings',data},source:{postMessage(v){posted.push(v);}}});}
  async function click(data,action='') {await event('notificationclick',{notification:{data,close(){}},action});}
  return {database,shown,opened,posted,notifications,clients,settings,click,push:data=>background({data})};
}
test('warm click keeps route and cold click persists full call action until authenticated client is ready',async()=>{
  const h=harness();
  await h.click({type:'incoming_call',account_id:'7',room_id:'room',chat_id:'42',message_id:'9',is_video:'true'},'action_accept');
  assert.deepEqual(h.opened,['https://fixture.invalid/']);
  assert.equal(h.database.get('pendingClick').notification_action,'action_accept');
  const restarted=harness(h.database);
  await restarted.settings({account_id:7,enabled:true,ready:false});
  assert.equal(restarted.posted.length,0);
  await restarted.settings({account_id:7,enabled:true,ready:true});
  assert.equal(restarted.posted[0].data.room_id,'room');
  assert.equal(restarted.posted[0].data.is_video,'true');
  assert.equal(restarted.database.get('pendingClick'),null);
});
test('activity click routes survive existing-window delivery without focusing another origin',async()=>{
  const h=harness(); let focused=false;
  h.clients.windows=[{url:'https://other.invalid/',focus(){throw Error('foreign focus');}},
    {url:'https://fixture.invalid/#/niosgram',postMessage(v){h.posted.push(v);},async focus(){focused=true;}}];
  await h.click({route:'/niosgram/post/42/comments',event_id:'activity-9'});
  assert.equal(h.posted[0].data.route,'/niosgram/post/42/comments'); assert.ok(focused);
});
test('push respects logout/account scope, categories, mute and preview',async()=>{
  const h=harness();
  await h.settings({account_id:7,enabled:true,ready:true,preferences:{preview:false,muted_chat_ids:[43]}});
  await h.push({account_id:'8',chat_id:'42',message_id:'1',body:'private'});
  await h.push({account_id:'7',chat_id:'43',message_id:'2',body:'private'});
  assert.equal(h.shown.length,0);
  await h.push({account_id:'7',chat_id:'42',message_id:'3',body:'private'});
  assert.equal(h.shown[0].options.body,'New message');
  await h.settings({account_id:null,enabled:false,ready:true});
  await h.push({account_id:'7',chat_id:'42',message_id:'4',body:'private'});
  assert.equal(h.shown.length,1);
});
test('visible window receives event instead of a system notification, and repeated FCM is deduplicated',async()=>{
  const h=harness();
  await h.settings({account_id:7,enabled:true,ready:true});
  h.clients.windows=[{visibilityState:'visible',focused:true,postMessage(v){h.posted.push(v);}}];
  const data={event_id:'message:42:9',account_id:'7',chat_id:'42',message_id:'9',body:'fixture'};
  await h.push(data);await h.push(data);
  assert.equal(h.shown.length,0);assert.equal(h.posted.filter(p=>p.type==='niosmess_notification_message').length,1);
});
test('ended, expired and reordered call pushes cannot resurrect ringing notifications',async()=>{
  const h=harness(); let closed=false;
  await h.settings({account_id:7,enabled:true,ready:true});
  h.notifications.push({tag:'call-room',close(){closed=true;}});
  await h.push({type:'call_ended',room_id:'room',account_id:'7'});
  await h.push({type:'incoming_call',room_id:'room',account_id:'7'});
  await h.push({type:'incoming_call',room_id:'other',account_id:'7',expires_at:'2020-01-01T00:00:00Z'});
  assert.ok(closed); assert.equal(h.shown.length,0);
});
test('a pending click from another account is discarded',async()=>{
  const h=harness(); await h.click({account_id:7,chat_id:42});
  await h.settings({account_id:8,enabled:true,ready:true});
  assert.equal(h.posted.length,0);assert.equal(h.database.get('pendingClick'),null);
});
