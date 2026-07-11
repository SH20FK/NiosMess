/**
 * api.js — WebSocket client wrapper for the Messenger API.
 * All methods return a Promise that resolves with the payload or rejects with { error }.
 * Supports per-connection AES-256-GCM encryption.
 */
const WS_URL = 'wss://ni-os.ru/ws';

let ws;
let wsReady = false;
let wsQueue = [];
const pendingRequests = new Map();
let requestId = 0;
let token = localStorage.getItem('nm_token') || '';
let connKey = null; // per-connection AES key (base64)

/**
 * AES-256-GCM encryption utilities (Web Crypto API)
 */
const Crypto = {
  async importKey(base64Key) {
    const rawKey = Uint8Array.from(atob(base64Key), c => c.charCodeAt(0));
    return await crypto.subtle.importKey('raw', rawKey, 'AES-GCM', false, ['encrypt', 'decrypt']);
  },

  async encrypt(plaintext, key) {
    const encoder = new TextEncoder();
    const encoded = encoder.encode(plaintext);
    const iv = crypto.getRandomValues(new Uint8Array(12));
    const cryptoKey = await this.importKey(key);
    const encrypted = await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, cryptoKey, encoded);
    const ct = new Uint8Array(encrypted);
    // Split ciphertext and auth tag (last 16 bytes)
    const tag = ct.slice(-16);
    const ciphertext = ct.slice(0, -16);
    return {
      ciphertext: btoa(String.fromCharCode(...ciphertext)),
      iv: btoa(String.fromCharCode(...iv)),
      tag: btoa(String.fromCharCode(...tag)),
    };
  },

  async decrypt(ciphertextB64, ivB64, tagB64, key) {
    const ct = Uint8Array.from(atob(ciphertextB64), c => c.charCodeAt(0));
    const iv = Uint8Array.from(atob(ivB64), c => c.charCodeAt(0));
    const tag = Uint8Array.from(atob(tagB64), c => c.charCodeAt(0));
    const combined = new Uint8Array(ct.length + tag.length);
    combined.set(ct, 0);
    combined.set(tag, ct.length);
    const cryptoKey = await this.importKey(key);
    const decrypted = await crypto.subtle.decrypt({ name: 'AES-GCM', iv }, cryptoKey, combined);
    return new TextDecoder().decode(decrypted);
  },
};

async function encryptPayload(data, key) {
  if (!key) return data;
  const jsonStr = JSON.stringify(data);
  const b64 = btoa(unescape(encodeURIComponent(jsonStr)));
  const encrypted = await Crypto.encrypt(b64, key);
  return { encrypted: true, data: encrypted };
}

async function decryptPayload(encrypted, key) {
  if (!key || !encrypted.encrypted) return encrypted;
  const jsonStr = atob(await Crypto.decrypt(encrypted.data.ciphertext, encrypted.data.iv, encrypted.data.tag, key));
  return JSON.parse(decodeURIComponent(escape(jsonStr)));
}

function wsConnect() {
  ws = new WebSocket(WS_URL);
  ws.onopen = () => {
    wsReady = true;
    // Send queued messages (they will be encrypted once key is received)
    wsQueue.forEach(q => ws.send(q));
    wsQueue = [];
  };
  ws.onmessage = async (e) => {
    try {
      let data;
      try {
        data = JSON.parse(e.data);
      } catch (_) {
        return;
      }

      // Handle key exchange message
      if (data.action === 'key_exchange' && data.key) {
        connKey = data.key;
        console.log('[WS] Connection key received');
        // Re-send any queued messages with encryption
        if (wsQueue.length > 0) {
          const queueCopy = [...wsQueue];
          wsQueue = [];
          for (const q of queueCopy) {
            const msgData = JSON.parse(q);
            const encrypted = await encryptPayload(msgData, connKey);
            ws.send(JSON.stringify(encrypted));
          }
        }
        return;
      }

      // Decrypt incoming messages if encrypted
      if (connKey && data.encrypted && data.data) {
        try {
          const decrypted = await decryptPayload(data, connKey);
          data = decrypted;
        } catch (decryptErr) {
          console.error('[WS] Decryption failed:', decryptErr);
          return;
        }
      }

      if (data.request_id && pendingRequests.has(data.request_id)) {
        const { resolve, reject } = pendingRequests.get(data.request_id);
        pendingRequests.delete(data.request_id);
        if (data.error) {
          if (data.error === 'Invalid or expired session token' && token) {
            logout();
          }
          reject(data);
        } else {
          resolve(data.payload);
        }
      } else if (data.action === 'new_message') {
        const msg = data.payload;
        if (msg && typeof msg === 'object' && msg.chat_id === window.currentChatId) {
          window.messages.push(msg);
          if (msg.id > window.lastMessageId) window.lastMessageId = msg.id;
          if (typeof window.renderMessages === 'function') window.renderMessages();
          const area = document.getElementById('messages-area');
          if (area && area.scrollHeight - area.scrollTop - area.clientHeight < 120) {
            if (typeof window.scrollToBottom === 'function') window.scrollToBottom();
          }
        }
        if (typeof window.loadChatList === 'function') window.loadChatList();
      }
    } catch (err) {
      console.error('[WS] Message handler error:', err);
    }
  };
  ws.onclose = () => {
    wsReady = false;
    connKey = null;
    setTimeout(wsConnect, 3000);
  };
  ws.onerror = () => {
    wsReady = false;
    connKey = null;
  };
}

async function wsSend(action, payload) {
  return new Promise(async (resolve, reject) => {
    const reqId = ++requestId;
    pendingRequests.set(reqId, { resolve, reject });
    const msg = { action, payload: payload || {}, token, request_id: reqId };

    // Encrypt if we have a connection key
    const toSend = connKey ? await encryptPayload(msg, connKey) : msg;
    const jsonStr = JSON.stringify(toSend);

    if (wsReady && ws.readyState === WebSocket.OPEN) {
      ws.send(jsonStr);
    } else {
      wsQueue.push(jsonStr);
    }
  });
}

wsConnect();

function _body(b) { return b || {}; }

const API = {
  setToken: (t) => { token = t; localStorage.setItem('nm_token', t); },
  getToken: () => token,
  wsConnect, wsSend,

  // Auth
  register: (b) => wsSend('register', _body(b)),
  verifyEmail: (b) => wsSend('verify_email', _body(b)),
  login: (b) => wsSend('login', _body(b)),
  verify2fa: (b) => wsSend('verify_2fa', _body(b)),
  logout: () => wsSend('logout', {}),
  resetPasswordReq: (b) => wsSend('reset_password_request', _body(b)),
  resetPasswordConfirm: (b) => wsSend('reset_password_confirm', _body(b)),

  // Profile
  me: () => wsSend('me_info', {}),
  getProfile: (username) => wsSend('get_profile', { username }),
  updateProfile: (b) => wsSend('update_profile', _body(b)),
  uploadAvatar: (b64, filename) => wsSend('upload_avatar', { data_base64: b64, filename }),
  toggle2fa: (b) => wsSend('toggle_2fa', _body(b)),
  listSessions: () => wsSend('list_sessions', {}),
  kickSession: (id) => wsSend('kick_session', { session_id: id }),

  // Chats
  listChats: () => wsSend('list_chats', {}),
  openDM: (username) => wsSend('open_direct', { username }),
  createGroup: (b) => wsSend('create_group', _body(b)),
  getChat: (id) => wsSend('get_chat', { chat_id: id }),
  getMembers: (id) => wsSend('get_members', { chat_id: id }),
  updateChat: (id, b) => wsSend('update_chat', { chat_id: id, ..._body(b) }),
  inviteUser: (id, uid) => wsSend('invite_user', { chat_id: id, user_id: uid }),
  banMember: (id, b) => wsSend('ban_member', { chat_id: id, ..._body(b) }),
  muteMember: (id, b) => wsSend('mute_member', { chat_id: id, ..._body(b) }),
  promote: (id, b) => wsSend('promote_member', { chat_id: id, ..._body(b) }),
  leaveChat: (id) => wsSend('leave_chat', { chat_id: id }),
  markRead: (id) => wsSend('mark_read', { chat_id: id }),

  // Messages
  sendMessage: (chatId, b) => wsSend('send_message', { chat_id: chatId, ..._body(b) }),
  history: (chatId, page = 1) => wsSend('history', { chat_id: chatId, page, page_size: 50 }),
  editMessage: (chatId, msgId, b) => wsSend('edit_message', { chat_id: chatId, message_id: msgId, ..._body(b) }),
  deleteMessage: (chatId, msgId) => wsSend('delete_message', { chat_id: chatId, message_id: msgId }),
  react: (chatId, msgId, emoji) => wsSend('react', { chat_id: chatId, message_id: msgId, emoji }),

  // Comments (channel posts)
  postComment: (channelId, postId, b) => wsSend('post_comment', { channel_id: channelId, post_id: postId, ..._body(b) }),
  getComments: (channelId, postId) => wsSend('get_comments', { channel_id: channelId, post_id: postId }),

  // Upload
  initUpload: (b) => wsSend('init_upload', _body(b)),
  uploadChunk: (b) => wsSend('upload_chunk', _body(b)),

  // Calls
  initiateCall: (b) => wsSend('initiate_call', _body(b)),
  answerCall: (b) => wsSend('answer_call', _body(b)),
  endCall: (b) => wsSend('end_call', _body(b)),

  // Search
  search: (q) => wsSend('search', { q }),

  // Invite
  joinChat: (slug) => wsSend('join_chat', { slug }),
  inviteInfo: (slug) => wsSend('get_invite_info', { slug }),

  // Bots
  callbackQuery: (b) => wsSend('callback_query', _body(b)),

  // Admin
  adminListUsers: (b) => wsSend('admin_list_users', _body(b)),
  adminGetUser: (b) => wsSend('admin_get_user', _body(b)),
  banUser: (b) => wsSend('ban_user', _body(b)),
  unbanUser: (b) => wsSend('unban_user', _body(b)),
  freezeUser: (b) => wsSend('freeze_user', _body(b)),
  spamBlock: (b) => wsSend('spam_block', _body(b)),
  adminListChats: (b) => wsSend('admin_list_chats', _body(b)),
  banChat: (b) => wsSend('ban_chat', _body(b)),
  listBadges: (b) => wsSend('list_badges', _body(b)),
  createBadge: (b) => wsSend('create_badge', _body(b)),
  deleteBadge: (b) => wsSend('delete_badge', _body(b)),
  awardBadge: (b) => wsSend('award_badge', _body(b)),
  revokeBadge: (b) => wsSend('revoke_badge', _body(b)),

  // AI
  aiProcessText: (b) => wsSend('ai_process_text', _body(b)),

  // Save/Load
  worldSave: (b) => wsSend('world_save', _body(b)),
  worldLoad: (b) => wsSend('world_load', _body(b)),
};

window.API = API;
