/**
 * app.js — Messenger frontend logic
 * Handles auth, chat list, messages, media upload, calls, search.
 */

// ── State ────────────────────────────────────────────────────────────────────
const S = {
  token: localStorage.getItem('token') || null,
  me: null,
  activeChatId: null,
  activeCallId: null,
  replyToId: null,
  pollTimer: null,
  lastMsgId: {},   // chatId → last loaded message id
};

// ── Helpers ──────────────────────────────────────────────────────────────────
function toast(msg, dur = 3000) {
  const el = $('#toast');
  el.textContent = msg;
  el.classList.remove('hidden');
  clearTimeout(el._t);
  el._t = setTimeout(() => el.classList.add('hidden'), dur);
}

function $(sel) { return document.querySelector(sel); }
function $$(sel) { return [...document.querySelectorAll(sel)]; }

function show(el) { el.classList.remove('hidden'); }
function hide(el) { el.classList.add('hidden'); }
function toggle(el) { el.classList.toggle('hidden'); }

function fmtTime(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  const now = new Date();
  if (d.toDateString() === now.toDateString()) {
    return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  }
  return d.toLocaleDateString([], { day: '2-digit', month: 'short' });
}

function fmtDuration(sec) {
  if (!sec) return '0:00';
  const m = Math.floor(sec / 60), s = sec % 60;
  return `${m}:${s.toString().padStart(2, '0')}`;
}

function avatarEl(url, letter, size = 'md') {
  const div = document.createElement('div');
  div.className = `avatar ${size}`;
  if (url) {
    const img = document.createElement('img');
    img.src = url; img.alt = '';
    div.appendChild(img);
  } else {
    div.textContent = (letter || '?')[0].toUpperCase();
  }
  return div;
}

function badgesEl(badges) {
  if (!badges || !badges.length) return document.createTextNode('');
  const wrap = document.createElement('span');
  badges.forEach(b => {
    const pill = document.createElement('span');
    pill.className = 'badge-pill';
    pill.style.background = b.color + '22';
    pill.style.color = b.color;
    pill.style.border = `1px solid ${b.color}66`;
    pill.textContent = (b.icon || '') + ' ' + b.name;
    wrap.appendChild(pill);
  });
  return wrap;
}

// ── Screen switching ──────────────────────────────────────────────────────────
function showScreen(id) {
  $$('.screen').forEach(s => s.classList.remove('active'));
  document.getElementById(id).classList.add('active');
}

// ── Tab switching ─────────────────────────────────────────────────────────────
document.addEventListener('click', e => {
  const tab = e.target.closest('.tab');
  if (!tab) return;
  const parent = tab.closest('.auth-box, .modal-box');
  if (!parent) return;
  parent.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
  tab.classList.add('active');
  const target = tab.dataset.tab || tab.dataset.target;
  if (!target) return;
  parent.querySelectorAll('.tab-content').forEach(tc => tc.classList.remove('active'));
  const tc = parent.querySelector('#' + target) || parent.querySelector(`[id="${target}"]`);
  if (tc) tc.classList.add('active');
});

// ── Auth ──────────────────────────────────────────────────────────────────────
let pendingRegEmail = null;

$('#btn-register').addEventListener('click', async () => {
  const body = {
    email: $('#reg-email').value.trim(),
    username: $('#reg-username').value.trim(),
    display_name: $('#reg-displayname').value.trim(),
    password: $('#reg-password').value,
  };
  try {
    await API.register(body);
    pendingRegEmail = body.email;
    show($('#verify-section'));
    toast('Код отправлен на почту!');
  } catch (e) { showAuthError(e.detail); }
});

$('#btn-verify').addEventListener('click', async () => {
  try {
    await API.verifyEmail({ email: pendingRegEmail, code: $('#verify-code').value.trim() });
    toast('Email подтверждён! Можете войти.');
    $$('.tab[data-tab="login"]')[0]?.click();
  } catch (e) { showAuthError(e.detail); }
});

$('#btn-login').addEventListener('click', async () => {
  const body = { identifier: $('#login-identifier').value.trim(), password: $('#login-password').value };
  try {
    const res = await API.login(body);
    if (res.two_fa_required) { show($('#twofa-section')); toast('Код 2FA отправлен на почту'); return; }
    await doLogin(res);
  } catch (e) { showAuthError(e.detail); }
});

$('#btn-2fa').addEventListener('click', async () => {
  const identifier = $('#login-identifier').value.trim();
  const code = $('#login-2fa-code').value.trim();
  try {
    const res = await API.verify2fa({ identifier, code });
    await doLogin(res);
  } catch (e) { showAuthError(e.detail); }
});

// Password reset
$('#btn-reset-request').addEventListener('click', async () => {
  try {
    await API.resetPasswordReq({ email: $('#reset-email').value.trim() });
    show($('#reset-confirm-section'));
    toast('Если аккаунт найден — код отправлен на почту');
  } catch (e) { showAuthError(e.detail); }
});

$('#btn-reset-confirm').addEventListener('click', async () => {
  try {
    await API.resetPasswordConfirm({
      email: $('#reset-email').value.trim(),
      code: $('#reset-code').value.trim(),
      new_password: $('#reset-newpass').value,
    });
    toast('Пароль сброшен! Войдите заново.');
    $$('.tab[data-tab="login"]')[0]?.click();
  } catch (e) { showAuthError(e.detail); }
});

function showAuthError(msg) {
  const el = $('#auth-error');
  el.textContent = typeof msg === 'object' ? JSON.stringify(msg) : (msg || 'Ошибка');
  show(el);
  setTimeout(() => hide(el), 5000);
}

async function doLogin(res) {
  S.token = res.access_token;
  localStorage.setItem('token', S.token);
  S.me = await API.me(S.token);
  initMain();
}

$('#btn-logout').addEventListener('click', async () => {
  try { await API.logout(S.token); } catch (_) {}
  S.token = null; S.me = null; S.activeChatId = null;
  localStorage.removeItem('token');
  clearInterval(S.pollTimer);
  showScreen('auth-screen');
});

// ── Main init ─────────────────────────────────────────────────────────────────
async function initMain() {
  showScreen('main-screen');
  updateMyHeader();
  await loadChatList();
  // Poll for new messages every 3 seconds
  clearInterval(S.pollTimer);
  S.pollTimer = setInterval(pollUpdates, 3000);
}

function updateMyHeader() {
  if (!S.me) return;
  $('#my-name').textContent = S.me.display_name;
  if (S.me.avatar_url) {
    const img = document.createElement('img');
    img.src = S.me.avatar_url; img.style.cssText = 'width:36px;height:36px;border-radius:50%;object-fit:cover';
    const av = $('#my-avatar');
    av.innerHTML = ''; av.appendChild(img);
  }
}

// ── Chat list ─────────────────────────────────────────────────────────────────
async function loadChatList() {
  try {
    const chats = await API.listChats(S.token);
    renderChatList(chats);
  } catch (e) { console.error('loadChatList', e); }
}

function renderChatList(chats) {
  const list = $('#chat-list');
  list.innerHTML = '';
  if (!chats.length) {
    list.innerHTML = '<div style="padding:1.5rem;color:var(--muted);text-align:center;font-size:.88rem">Нет чатов. Начните новый!</div>';
    return;
  }
  chats.forEach(chat => {
    const item = document.createElement('div');
    item.className = 'chat-item' + (chat.id === S.activeChatId ? ' active' : '');
    item.dataset.chatId = chat.id;

    const name = chat.name || 'Чат';
    const preview = chat.last_message
      ? (chat.last_message.is_deleted ? '🗑 Удалено'
        : chat.last_message.msg_type === 'voice' ? '🎤 Голосовое'
        : chat.last_message.msg_type === 'circle' ? '⭕ Кружок'
        : chat.last_message.msg_type === 'call_log' ? (chat.last_message.content || '📞 Звонок')
        : (chat.last_message.content || (chat.last_message.media_name ? '📎 ' + chat.last_message.media_name : '')))
      : 'Нет сообщений';
    const time = chat.last_message ? fmtTime(chat.last_message.sent_at) : '';
    const unread = chat.unread_count || 0;

    // badges for DM partner
    const partnerBadgesHtml = (chat.partner_badges || [])
      .map(b => `<span class="badge-pill" style="background:${b.color}22;color:${b.color};border:1px solid ${b.color}66">${b.icon||''} ${b.name}</span>`)
      .join('');

    item.innerHTML = `
      <div class="avatar md">${chat.avatar_url
        ? `<img src="${chat.avatar_url}" alt=""/>`
        : (chat.chat_type === 'channel' ? '📢' : chat.chat_type === 'group' ? '👥' : name[0].toUpperCase())}</div>
      <div class="chat-info">
        <div class="chat-row">
          <span class="chat-name">${name}${partnerBadgesHtml}</span>
          <span class="chat-time">${time}</span>
        </div>
        <div class="chat-row">
          <span class="chat-preview">${preview}</span>
          ${unread ? `<span class="unread-badge">${unread}</span>` : ''}
        </div>
      </div>`;
    item.addEventListener('click', () => openChat(chat.id));
    list.appendChild(item);
  });
}

// ── Open chat ─────────────────────────────────────────────────────────────────
async function openChat(chatId) {
  S.activeChatId = chatId;
  S.replyToId = null;
  hide($('#reply-preview'));
  hide($('#empty-state'));
  show($('#chat-view'));

  // Mark active in list
  $$('.chat-item').forEach(i => {
    i.classList.toggle('active', parseInt(i.dataset.chatId) === chatId);
  });

  // Mark read
  try { await API.markRead(chatId, S.token); } catch (_) {}

  // Load chat info + messages
  try {
    const chat = await API.getChat(chatId, S.token);
    renderChatHeader(chat);
    await loadMessages(chatId, true);
  } catch (e) { toast('Ошибка открытия чата'); }
}

function renderChatHeader(chat) {
  const name = chat.name || 'Чат';
  const av = $('#chat-avatar');
  if (chat.avatar_url) {
    av.innerHTML = `<img src="${chat.avatar_url}" style="width:44px;height:44px;border-radius:50%;object-fit:cover"/>`;
  } else {
    av.className = 'avatar md';
    av.textContent = chat.chat_type === 'channel' ? '📢' : chat.chat_type === 'group' ? '👥' : name[0].toUpperCase();
  }
  $('#chat-name').textContent = name;
  let meta = '';
  if (chat.chat_type === 'direct' && chat.partner) {
    const badges = (chat.partner.badges || []).map(b => `<span class="badge-pill" style="background:${b.color}22;color:${b.color}">${b.icon||''} ${b.name}</span>`).join('');
    meta = `@${chat.partner.username} ${badges}`;
  } else {
    meta = `${chat.members_count} участников`;
    if (chat.invite_link) meta += ` · <a href="${chat.invite_link}" style="color:var(--accent)" target="_blank">Ссылка</a>`;
  }
  $('#chat-meta').innerHTML = meta;
}

// ── Messages ──────────────────────────────────────────────────────────────────
async function loadMessages(chatId, reset = false) {
  const list = $('#messages-list');
  if (reset) { list.innerHTML = ''; S.lastMsgId[chatId] = null; }
  try {
    const res = await API.history(chatId, 1, S.token);
    if (reset) list.innerHTML = '';
    res.messages.forEach(msg => appendMessage(msg, false));
    scrollBottom();
    if (res.messages.length) {
      S.lastMsgId[chatId] = res.messages[res.messages.length - 1].id;
    }
  } catch (e) { console.error('loadMessages', e); }
}

function appendMessage(msg, scroll = true) {
  const list = $('#messages-list');
  // Avoid duplicates
  if (list.querySelector(`[data-msg-id="${msg.id}"]`)) return;

  const isMe = msg.sender_id === S.me?.id;
  const wrap = document.createElement('div');
  wrap.className = 'msg-wrap ' + (isMe ? 'out' : 'in');
  wrap.dataset.msgId = msg.id;

  // Sender name + badges (in group/channel messages)
  if (!isMe) {
    const senderRow = document.createElement('div');
    senderRow.className = 'msg-sender';
    senderRow.textContent = msg.sender_display_name || msg.sender_username;
    if (msg.sender_badges?.length) {
      msg.sender_badges.forEach(b => {
        const pill = document.createElement('span');
        pill.className = 'badge-pill';
        pill.style.cssText = `background:${b.color}22;color:${b.color};border:1px solid ${b.color}66`;
        pill.textContent = (b.icon || '') + ' ' + b.name;
        senderRow.appendChild(pill);
      });
    }
    wrap.appendChild(senderRow);
  }

  const bubble = document.createElement('div');
  bubble.className = 'msg-bubble';

  // Reply quote
  if (msg.reply_to_id) {
    const q = document.createElement('div');
    q.className = 'reply-quote';
    q.textContent = '↩ В ответ на сообщение #' + msg.reply_to_id;
    bubble.appendChild(q);
  }

  if (msg.is_deleted) {
    bubble.innerHTML += '<span class="msg-deleted">🗑 Сообщение удалено</span>';
  } else if (msg.msg_type === 'voice') {
    bubble.innerHTML += `<div class="voice-msg">
      <button class="voice-play" onclick="playVoice('${msg.media_url}')">▶</button>
      <span>🎤 ${fmtDuration(msg.media_duration)}</span>
    </div>`;
  } else if (msg.msg_type === 'circle') {
    bubble.innerHTML += `<video class="circle-video" src="${msg.media_url}" controls loop></video>`;
  } else if (msg.msg_type === 'call_log') {
    bubble.innerHTML += `<span style="color:var(--muted)">${msg.content}</span>`;
  } else {
    if (msg.content) {
      const txt = document.createElement('span');
      txt.textContent = msg.content;
      bubble.appendChild(txt);
    }
    if (msg.media_url) {
      if (msg.media_type?.startsWith('image/')) {
        const img = document.createElement('img');
        img.src = msg.media_url; img.className = 'media-thumb';
        img.onclick = () => window.open(msg.media_url);
        bubble.appendChild(img);
      } else if (msg.media_type?.startsWith('video/')) {
        const vid = document.createElement('video');
        vid.src = msg.media_url; vid.controls = true; vid.className = 'media-thumb';
        bubble.appendChild(vid);
      } else {
        const a = document.createElement('a');
        a.href = msg.media_url; a.target = '_blank'; a.style.color = 'var(--accent)';
        a.textContent = '📎 ' + (msg.media_name || 'Файл');
        bubble.appendChild(a);
      }
    }
  }

  wrap.appendChild(bubble);

  // Reactions
  if (msg.reactions && Object.keys(msg.reactions).length) {
    const row = document.createElement('div');
    row.className = 'reactions-row';
    Object.entries(msg.reactions).forEach(([emoji, count]) => {
      const chip = document.createElement('button');
      chip.className = 'reaction-chip';
      chip.textContent = `${emoji} ${count}`;
      chip.onclick = () => sendReaction(msg.chat_id, msg.id, emoji);
      row.appendChild(chip);
    });
    wrap.appendChild(row);
  }

  // Meta row: time, edited, reply btn, delete btn
  const meta = document.createElement('div');
  meta.className = 'msg-meta';
  meta.innerHTML = `<span>${fmtTime(msg.sent_at)}</span>`;
  if (msg.edited_at) meta.innerHTML += `<span class="msg-edited">ред.</span>`;
  if (!msg.is_deleted) {
    const replyBtn = document.createElement('button');
    replyBtn.style.cssText = 'background:none;border:none;color:var(--muted);cursor:pointer;font-size:.8rem';
    replyBtn.textContent = '↩';
    replyBtn.onclick = () => setReply(msg);
    meta.appendChild(replyBtn);

    const reactBtn = document.createElement('button');
    reactBtn.style.cssText = 'background:none;border:none;color:var(--muted);cursor:pointer;font-size:.8rem';
    reactBtn.textContent = '😊';
    reactBtn.onclick = () => quickReact(msg);
    meta.appendChild(reactBtn);

    if (isMe && !msg.is_deleted) {
      const delBtn = document.createElement('button');
      delBtn.style.cssText = 'background:none;border:none;color:var(--danger);cursor:pointer;font-size:.8rem';
      delBtn.textContent = '🗑';
      delBtn.onclick = () => deleteMsg(msg.chat_id, msg.id, wrap);
      meta.appendChild(delBtn);
    }
  }
  wrap.appendChild(meta);

  list.appendChild(wrap);
  if (scroll) scrollBottom();
}

function scrollBottom() {
  const list = $('#messages-list');
  list.scrollTop = list.scrollHeight;
}

function setReply(msg) {
  S.replyToId = msg.id;
  $('#reply-text').textContent = `↩ ${msg.sender_display_name}: ${msg.content?.slice(0, 60) || '[медиа]'}`;
  show($('#reply-preview'));
  $('#msg-input').focus();
}

$('#btn-cancel-reply').addEventListener('click', () => {
  S.replyToId = null; hide($('#reply-preview'));
});

async function deleteMsg(chatId, msgId, wrap) {
  try {
    await API.deleteMessage(chatId, msgId, S.token);
    wrap.querySelector('.msg-bubble').innerHTML = '<span class="msg-deleted">🗑 Сообщение удалено</span>';
  } catch (e) { toast('Ошибка удаления'); }
}

async function sendReaction(chatId, msgId, emoji) {
  try { await API.react(chatId, msgId, emoji, S.token); } catch (_) {}
}

function quickReact(msg) {
  const emojis = ['👍', '❤️', '😂', '😮', '😢', '🔥'];
  const picker = document.createElement('div');
  picker.style.cssText = 'position:fixed;background:var(--surface);border:1px solid var(--border);border-radius:8px;padding:.5rem;display:flex;gap:.4rem;z-index:50';
  emojis.forEach(e => {
    const btn = document.createElement('button');
    btn.textContent = e;
    btn.style.cssText = 'background:none;border:none;cursor:pointer;font-size:1.3rem';
    btn.onclick = async () => {
      document.body.removeChild(picker);
      await sendReaction(msg.chat_id, msg.id, e);
      setTimeout(() => loadMessages(S.activeChatId, true), 500);
    };
    picker.appendChild(btn);
  });
  document.body.appendChild(picker);
  const rect = { left: window.innerWidth / 2 - 120, top: window.innerHeight / 2 };
  picker.style.left = rect.left + 'px'; picker.style.top = rect.top + 'px';
  setTimeout(() => document.addEventListener('click', () => {
    if (document.body.contains(picker)) document.body.removeChild(picker);
  }, { once: true }), 50);
}

function playVoice(url) {
  const audio = new Audio(url);
  audio.play().catch(() => toast('Ошибка воспроизведения'));
}

// ── Send message ──────────────────────────────────────────────────────────────
$('#btn-send').addEventListener('click', sendText);
$('#msg-input').addEventListener('keydown', e => {
  if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); sendText(); }
});

async function sendText() {
  const text = $('#msg-input').value.trim();
  if (!text || !S.activeChatId) return;
  $('#msg-input').value = '';
  try {
    const msg = await API.sendMessage(S.activeChatId, {
      content: text,
      reply_to_id: S.replyToId || null,
    }, S.token);
    S.replyToId = null; hide($('#reply-preview'));
    appendMessage(msg);
    S.lastMsgId[S.activeChatId] = msg.id;
  } catch (e) { toast('Ошибка отправки: ' + (e.detail || e)); }
}

// ── File / media upload ───────────────────────────────────────────────────────
$('#btn-attach').addEventListener('click', () => $('#file-input').click());
$('#file-input').addEventListener('change', async (e) => {
  const file = e.target.files[0];
  if (!file || !S.activeChatId) return;
  e.target.value = '';
  await uploadAndSend(file, 'media');
});

$('#btn-voice').addEventListener('click', () => {
  toast('Запись голоса: используйте API напрямую (/messages/upload/init с media_subtype=voice)', 4000);
});

async function uploadAndSend(file, subtype = 'media') {
  const CHUNK = 131072; // 128 KB
  const totalChunks = Math.ceil(file.size / CHUNK);
  toast(`Загрузка файла (${totalChunks} чанков)…`);

  try {
    // Init
    const fd0 = new FormData();
    fd0.append('filename', file.name);
    fd0.append('total_chunks', totalChunks);
    fd0.append('file_size', file.size);
    fd0.append('media_subtype', subtype);
    const { upload_id } = await API.initUpload(fd0, S.token);

    // Send chunks
    for (let i = 0; i < totalChunks; i++) {
      const slice = file.slice(i * CHUNK, (i + 1) * CHUNK);
      const fd = new FormData();
      fd.append('upload_id', upload_id);
      fd.append('chunk_index', i);
      fd.append('chunk', slice, file.name);
      await API.uploadChunk(fd, S.token);
    }

    // Send message with upload_id
    const msg = await API.sendMessage(S.activeChatId, {
      upload_id,
      reply_to_id: S.replyToId || null,
    }, S.token);
    S.replyToId = null; hide($('#reply-preview'));
    appendMessage(msg);
    S.lastMsgId[S.activeChatId] = msg.id;
    toast('Файл отправлен!');
  } catch (e) { toast('Ошибка загрузки: ' + (e.detail || e)); }
}

// ── Poll for new messages ─────────────────────────────────────────────────────
async function pollUpdates() {
  if (!S.activeChatId || !S.token) return;
  try {
    const res = await API.history(S.activeChatId, 1, S.token);
    const lastId = S.lastMsgId[S.activeChatId] || 0;
    const newMsgs = res.messages.filter(m => m.id > lastId);
    newMsgs.forEach(m => appendMessage(m));
    if (newMsgs.length) {
      S.lastMsgId[S.activeChatId] = newMsgs[newMsgs.length - 1].id;
      await API.markRead(S.activeChatId, S.token);
      // Refresh unread badges in sidebar
      const chats = await API.listChats(S.token);
      renderChatList(chats);
    }
  } catch (_) {}
}

// ── Search ────────────────────────────────────────────────────────────────────
$('#btn-search-toggle').addEventListener('click', () => toggle($('#search-bar')));

let searchTimer = null;
$('#search-input').addEventListener('input', e => {
  clearTimeout(searchTimer);
  const q = e.target.value.trim();
  if (!q) { loadChatList(); return; }
  searchTimer = setTimeout(() => doSearch(q), 400);
});

async function doSearch(q) {
  try {
    const res = await API.search(q, S.token);
    const list = $('#chat-list');
    list.innerHTML = '';

    if (res.users.length) {
      const h = document.createElement('div');
      h.style.cssText = 'padding:.4rem 1rem;font-size:.78rem;color:var(--muted);text-transform:uppercase;letter-spacing:.05em';
      h.textContent = 'Пользователи'; list.appendChild(h);
      res.users.forEach(u => {
        const item = document.createElement('div');
        item.className = 'chat-item';
        const badgesHtml = (u.badges || []).map(b =>
          `<span class="badge-pill" style="background:${b.color}22;color:${b.color}">${b.icon||''} ${b.name}</span>`).join('');
        item.innerHTML = `
          <div class="avatar md">${u.avatar_url ? `<img src="${u.avatar_url}"/>` : u.display_name[0]}</div>
          <div class="chat-info"><div class="chat-name">${u.display_name} ${badgesHtml}</div>
          <div class="chat-preview">@${u.username}</div></div>`;
        item.onclick = async () => {
          hide($('#search-bar'));
          $('#search-input').value = '';
          const dm = await API.openDM(u.username, S.token);
          openChat(dm.chat_id);
        };
        list.appendChild(item);
      });
    }

    if (res.chats.length) {
      const h = document.createElement('div');
      h.style.cssText = 'padding:.4rem 1rem;font-size:.78rem;color:var(--muted);text-transform:uppercase;letter-spacing:.05em';
      h.textContent = 'Чаты'; list.appendChild(h);
      res.chats.forEach(c => {
        const item = document.createElement('div');
        item.className = 'chat-item';
        item.innerHTML = `
          <div class="avatar md">${c.chat_type==='channel'?'📢':'👥'}</div>
          <div class="chat-info"><div class="chat-name">${c.name}</div>
          <div class="chat-preview">${c.members_count} участников</div></div>`;
        item.onclick = () => openChat(c.id);
        list.appendChild(item);
      });
    }

    if (res.messages.length) {
      const h = document.createElement('div');
      h.style.cssText = 'padding:.4rem 1rem;font-size:.78rem;color:var(--muted);text-transform:uppercase;letter-spacing:.05em';
      h.textContent = 'Сообщения'; list.appendChild(h);
      res.messages.forEach(m => {
        const item = document.createElement('div');
        item.className = 'chat-item';
        item.innerHTML = `
          <div class="avatar md">💬</div>
          <div class="chat-info"><div class="chat-name">${m.sender_display_name}</div>
          <div class="chat-preview">${m.content?.slice(0,80)}</div></div>`;
        item.onclick = () => openChat(m.chat_id);
        list.appendChild(item);
      });
    }

    if (!res.users.length && !res.chats.length && !res.messages.length) {
      list.innerHTML = '<div style="padding:1.5rem;color:var(--muted);text-align:center">Ничего не найдено</div>';
    }
  } catch (e) { console.error('search', e); }
}

// ── New chat modal ────────────────────────────────────────────────────────────
$('#btn-new-chat').addEventListener('click', () => show($('#modal-new-chat')));
$$('.modal-close').forEach(b => b.addEventListener('click', () => {
  hide($('#modal-new-chat'));
}));

$('#btn-open-dm').addEventListener('click', async () => {
  const username = $('#dm-username').value.trim();
  if (!username) return;
  try {
    const res = await API.openDM(username, S.token);
    hide($('#modal-new-chat'));
    await loadChatList();
    openChat(res.chat_id);
  } catch (e) { toast('Пользователь не найден'); }
});

$('#btn-create-group').addEventListener('click', async () => {
  const name = $('#group-name').value.trim();
  const username = $('#group-username').value.trim() || undefined;
  const chat_type = $('#group-type').value;
  if (!name) { toast('Введите название'); return; }
  try {
    const res = await API.createGroup({ name, username, chat_type }, S.token);
    hide($('#modal-new-chat'));
    toast(`Создано! Ссылка: ${res.invite_link}`);
    await loadChatList();
    openChat(res.chat_id);
  } catch (e) { toast('Ошибка создания: ' + (e.detail || '')); }
});

// ── Calls ─────────────────────────────────────────────────────────────────────
$('#btn-call-voice').addEventListener('click', () => startCall(false));
$('#btn-call-video').addEventListener('click', () => startCall(true));

async function startCall(isVideo) {
  if (!S.activeChatId) return;
  try {
    const res = await API.initiateCall({ chat_id: S.activeChatId, is_video: isVideo }, S.token);
    S.activeCallId = res.call_id;
    $('#call-name').textContent = $('#chat-name').textContent;
    $('#call-status').textContent = isVideo ? '📹 Видеозвонок…' : '📞 Голосовой звонок…';
    show($('#modal-call'));
    toast('Звонок инициирован. ID: ' + res.call_id);
  } catch (e) { toast('Ошибка звонка: ' + (e.detail || e)); }
}

$('#btn-end-call').addEventListener('click', async () => {
  if (!S.activeCallId) { hide($('#modal-call')); return; }
  try {
    const res = await API.endCall({ call_id: S.activeCallId }, S.token);
    toast(`Звонок завершён (${fmtDuration(res.duration_seconds || 0)})`);
  } catch (_) {}
  S.activeCallId = null;
  hide($('#modal-call'));
  setTimeout(() => loadMessages(S.activeChatId, true), 500);
});

// ── Chat info button ──────────────────────────────────────────────────────────
$('#btn-chat-info').addEventListener('click', async () => {
  if (!S.activeChatId) return;
  try {
    const chat = await API.getChat(S.activeChatId, S.token);
    let info = `📋 ${chat.name}\nТип: ${chat.chat_type}\nУчастников: ${chat.members_count}`;
    if (chat.invite_link) info += `\n🔗 ${chat.invite_link}`;
    if (chat.share_link)  info += `\n🌐 ${chat.share_link}`;
    if (chat.description) info += `\n\n${chat.description}`;
    alert(info);
  } catch (_) {}
});

// ── Auto-login on load ────────────────────────────────────────────────────────
(async () => {
  if (S.token) {
    try {
      S.me = await API.me(S.token);
      initMain();
    } catch (_) {
      localStorage.removeItem('token');
      S.token = null;
      showScreen('auth-screen');
    }
  } else {
    showScreen('auth-screen');
  }
})();
