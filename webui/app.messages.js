const twoChar = new Set([...revMap.keys()].filter((v) => v.length === 2));
const oneChar = new Set([...revMap.keys()].filter((v) => v.length === 1));

function getMessageId(m) {
  return String(m?.id || m?.temp_id || "");
}

function normalizeReadFlag(m) {
  if (!m) return false;
  const raw = m.is_read ?? m.isRead ?? m.read ?? m.readed ?? m.seen;
  if (raw === undefined || raw === null) return false;
  if (typeof raw === "string") {
    return raw === "1" || raw.toLowerCase() === "true";
  }
  return !!raw;
}

function updateMessageReadStatus(msgId, isRead) {
  if (!msgId) return;
  const el = document.querySelector(`[data-id="${msgId}"]`);
  if (!el) return;
  const status = el.querySelector(".message-status");
  if (!status) return;
  status.textContent = isRead ? "\u2713\u2713" : "\u2713";
}

function syncReadStatesFromServer(serverMessages) {
  if (!Array.isArray(serverMessages) || !serverMessages.length) return false;
  const serverMap = new Map(serverMessages.map((m) => [getMessageId(m), m]));
  let changed = false;
  state.messages = (state.messages || []).map((m) => {
    const id = getMessageId(m);
    if (!id) return m;
    const fresh = serverMap.get(id);
    if (!fresh) return m;
    const wasRead = normalizeReadFlag(m);
    const isRead = normalizeReadFlag(fresh);
    if (wasRead !== isRead) {
      updateMessageReadStatus(id, isRead);
      changed = true;
      return { ...m, is_read: fresh.is_read ?? m.is_read, read: fresh.read ?? m.read, isRead: fresh.isRead ?? m.isRead };
    }
    return m;
  });
  return changed;
}
async function loadMessages({ silent = true } = {}) {
  if (!state.activeTarget || !state.session) return;
  if (state.messagesLoading) return;
  state.messagesLoading = true;
  const listEl = $("messageList");
  const animateLoad = !silent;
  if (animateLoad && listEl) listEl.classList.add("is-loading");
  const stopLoadingAnim = () => {
    if (animateLoad && listEl) listEl.classList.remove("is-loading");
  };
  if (state.activeTarget === FAVORITES_CHAT_ID) {
    try {
      const data = await apiFetch(
        `/get_chat_messages?chat_id=${encodeURIComponent(FAVORITES_CHAT_ID)}&username=${encodeURIComponent(state.session.username)}&token=${encodeURIComponent(state.session.token)}&limit=50`,
        {},
        { silent }
      );
      const newMessages = Array.isArray(data)
        ? data
        : (Array.isArray(data?.messages) ? data.messages : []);
      state.messages = newMessages;
      state.messagesLoaded = true;
      renderMessages(newMessages);
    } catch (err) {
      if (!silent) toast("Не удалось загрузить сообщения");
    } finally {
      state.messagesLoading = false;
      stopLoadingAnim();
    }
    return;
  }

  try {
    let data = null;
    if (state.activeChatType === "group" || state.activeChatType === "channel") {
      data = await apiFetch(
        `/collective/messages?chat_id=${encodeURIComponent(state.activeTarget)}&username=${encodeURIComponent(state.session.username)}&token=${encodeURIComponent(state.session.token)}&limit=50`,
        {},
        { silent }
      );
    } else {
      data = await apiFetch(
        `/get_messages?me=${encodeURIComponent(state.session.username)}&other=${encodeURIComponent(state.activeTarget)}&token=${encodeURIComponent(state.session.token)}`,
        {},
        { silent }
      );
    }

    const newMessages = Array.isArray(data)
      ? data
      : (Array.isArray(data?.messages) ? data.messages : []);

    if (!state.messagesLoaded) {
      if (newMessages.length === 0) {
        $("messageList").innerHTML = "";
        $("messagesEmpty").classList.remove("hidden");
        state.messagesLoaded = true;
        return;
      }

      state.messages = newMessages;
      state.messagesLoaded = true;
      renderMessages(newMessages);
      const scroller = document.querySelector(".messages-container") || $("messageList");
      if (scroller) {
        requestAnimationFrame(() => {
          scroller.scrollTo({ top: scroller.scrollHeight, behavior: 'instant' });
        });
      }

      // Auto-read logic REMOVED
      /*
      const lastId = newMessages[newMessages.length - 1]?.id || newMessages[newMessages.length - 1]?.temp_id;
      if (state.activeChatType === "user") {
        markDirectRead(state.activeTarget, lastId);
      } else if (state.activeChatType === "group" || state.activeChatType === "channel") {
        markCollectiveRead(state.activeTarget);
      }
      */
      return;
    }

    if (newMessages.length === 0) {
      return;
    }

    const existingIds = new Set(state.messages.map(m => m.id || m.temp_id));
    const newItems = newMessages.filter(m => !existingIds.has(m.id || m.temp_id));

    syncReadStatesFromServer(newMessages);

    if (newItems.length === 0 && state.messages.length === newMessages.length) {
      return;
    }

    if (newItems.length > 0) {
      state.messages = newMessages;

      newItems.forEach(msg => {
        appendMessage(msg);
      });

      const scroller = document.querySelector(".messages-container") || $("messageList");
      const wasAtBottom = scroller ? scroller.scrollHeight - scroller.scrollTop - scroller.clientHeight < 100 : false;
      if (wasAtBottom) {
        setTimeout(() => {
          if (scroller) scroller.scrollTo({ top: scroller.scrollHeight, behavior: 'smooth' });
        }, 50);
      }

      // Auto-read logic REMOVED to fix immediate read status bug
      /*
      const lastId = newMessages[newMessages.length - 1]?.id || newMessages[newMessages.length - 1]?.temp_id;
      if (state.activeChatType === "user") {
        markDirectRead(state.activeTarget, lastId);
      } else if (state.activeChatType === "group" || state.activeChatType === "channel") {
        markCollectiveRead(state.activeTarget);
      }
      */
    }

  } catch (err) {
    if (!silent) toast("Не удалось загрузить сообщения");
  } finally {
    state.messagesLoading = false;
    stopLoadingAnim();
  }
}
function renderMessages(msgs) {
  if (state.rendering) return;
  state.rendering = true;

  const list = $("messageList");
  const scroller = document.querySelector(".messages-container") || list;
  const wasAtBottom = scroller ? scroller.scrollHeight - scroller.scrollTop - scroller.clientHeight < 50 : false;

  $("messagesEmpty").classList.add("hidden");
  list.innerHTML = "";

  msgs.forEach((m) => {
    createMessageElement(m, list);
  });

  if (scroller && (wasAtBottom || msgs.length <= 5)) {
    requestAnimationFrame(() => {
      scroller.scrollTo({ top: scroller.scrollHeight, behavior: 'instant' });
    });
  }

  if (!$("messageSearchBar").classList.contains("hidden") && state.messageSearchQuery) {
    runMessageSearch();
  }

  renderPinnedBar();
  state.rendering = false;
}
function appendMessage(msg) {
  const list = $("messageList");
  const scroller = document.querySelector(".messages-container") || list;
  const wasAtBottom = scroller ? scroller.scrollHeight - scroller.scrollTop - scroller.clientHeight < 60 : false;
  $("messagesEmpty")?.classList.add("hidden");
  createMessageElement(msg, list);
  if (!$("messageSearchBar").classList.contains("hidden") && state.messageSearchQuery) {
    runMessageSearch();
  }
  if (scroller && wasAtBottom) {
    requestAnimationFrame(() => {
      scroller.scrollTo({ top: scroller.scrollHeight, behavior: 'smooth' });
    });
  }
}
const MEDIA_IMAGE_EXT = new Set(["jpg", "jpeg", "png", "gif", "webp", "svg", "ico", "bmp"]);
const MEDIA_AUDIO_EXT = new Set(["mp3", "wav", "ogg", "m4a", "aac", "flac", "webm"]);
const MEDIA_VIDEO_EXT = new Set(["mp4", "webm", "mov", "mkv"]);
const WS_FILE_PREFIX = "wsfile://";
const FILE_CHUNK_SIZE = 1024 * 1024;
const MAX_FILE_SIZE = 50 * 1024 * 1024;
const wsFilePending = new Map();
let wsFileDisabledUntil = 0;

function isWsFileUrl(url) {
  return typeof url === "string" && url.startsWith(WS_FILE_PREFIX);
}

function buildWsFileUrl(name) {
  return `${WS_FILE_PREFIX}${encodeURIComponent(name)}`;
}

function getWsFileName(url) {
  if (!isWsFileUrl(url)) return "";
  return decodeURIComponent(url.slice(WS_FILE_PREFIX.length));
}

const MIME_BY_EXT = {
  jpg: "image/jpeg",
  jpeg: "image/jpeg",
  png: "image/png",
  gif: "image/gif",
  webp: "image/webp",
  svg: "image/svg+xml",
  ico: "image/x-icon",
  bmp: "image/bmp",
  mp3: "audio/mpeg",
  wav: "audio/wav",
  ogg: "audio/ogg",
  m4a: "audio/mp4",
  aac: "audio/aac",
  flac: "audio/flac",
  webm: "video/webm",
  mp4: "video/mp4",
  mov: "video/quicktime",
  mkv: "video/x-matroska",
  pdf: "application/pdf",
  txt: "text/plain",
  json: "application/json",
  zip: "application/zip",
};

function guessMimeType(name) {
  if (!name) return "";
  const ext = String(name).toLowerCase().split(".").pop();
  return MIME_BY_EXT[ext] || "";
}

function blobToBase64(blob) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => {
      const result = String(reader.result || "");
      const base64 = result.includes(",") ? result.split(",")[1] : result;
      resolve(base64);
    };
    reader.onerror = () => reject(reader.error || new Error("File read failed"));
    reader.readAsDataURL(blob);
  });
}

function base64ToUint8Array(base64) {
  const binary = atob(base64 || "");
  const len = binary.length;
  const bytes = new Uint8Array(len);
  for (let i = 0; i < len; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

function buildWsUrl() {
  if (!state.session) throw new Error("Нет сессии");
  let base = state.apiBase;
  try {
    base = localStorage.getItem("niosmess_ws_base") || base;
  } catch { }
  base = base.replace(/^http/, "ws");
  return `${base}/ws?token=${encodeURIComponent(state.session.token)}&username=${encodeURIComponent(state.session.username)}`;
}

function openFileSocket(timeoutMs = 10000) {
  if (wsFileDisabledUntil && Date.now() < wsFileDisabledUntil) {
    return Promise.reject(new Error("WebSocket недоступен"));
  }
  return new Promise((resolve, reject) => {
    let settled = false;
    let ws = null;
    const finalize = (err) => {
      if (settled) return;
      settled = true;
      if (ws && (ws.readyState === WebSocket.OPEN || ws.readyState === WebSocket.CONNECTING)) {
        try { ws.close(); } catch { }
      }
      if (err) reject(err);
    };

    try {
      ws = new WebSocket(buildWsUrl());
    } catch (err) {
      reject(err);
      return;
    }

    const timer = setTimeout(() => {
      finalize(new Error("WebSocket timeout"));
    }, timeoutMs);

    const cleanup = () => {
      clearTimeout(timer);
      ws.removeEventListener("open", onOpen);
      ws.removeEventListener("error", onError);
      ws.removeEventListener("close", onClose);
    };

    const onOpen = () => {
      if (settled) return;
      settled = true;
      cleanup();
      resolve(ws);
    };
    const onError = () => {
      cleanup();
      finalize(new Error("WebSocket error"));
    };
    const onClose = (event) => {
      cleanup();
      const reason = event && event.code === 1008 ? "Неверный токен" : "WebSocket закрыт";
      finalize(new Error(reason));
    };

    ws.addEventListener("open", onOpen);
    ws.addEventListener("error", onError);
    ws.addEventListener("close", onClose);
  });
}

function buildHttpDownloadUrl(name) {
  if (!name) return "";
  const params = new URLSearchParams();
  if (state.session?.token) params.set("token", state.session.token);
  if (state.session?.username) params.set("username", state.session.username);
  const query = params.toString();
  return `${state.apiBase}/download/${encodeURIComponent(name)}${query ? `?${query}` : ""}`;
}

function isWsFailure(err) {
  const msg = String(err?.message || "");
  if (!msg) return false;
  if (msg.includes("Неверный токен")) return false;
  return msg.includes("WebSocket");
}

async function downloadFileBlob(filename) {
  try {
    return await downloadFileViaWs(filename);
  } catch (err) {
    if (isWsFailure(err)) {
      wsFileDisabledUntil = Date.now() + 60 * 1000;
    }
    const httpUrl = buildHttpDownloadUrl(filename);
    if (!httpUrl) throw err;
    return await fetchMediaBlob(httpUrl);
  }
}

async function downloadFileViaWs(filename) {
  if (!filename) throw new Error("download failed: empty filename");
  const ws = await openFileSocket();
  return new Promise((resolve, reject) => {
    let finished = false;
    const chunks = [];

    const cleanup = () => {
      ws.removeEventListener("message", onMessage);
      ws.removeEventListener("close", onClose);
      ws.removeEventListener("error", onError);
      if (ws.readyState === WebSocket.OPEN || ws.readyState === WebSocket.CONNECTING) {
        try { ws.close(); } catch { }
      }
    };

    const finish = (err, blob) => {
      if (finished) return;
      finished = true;
      cleanup();
      if (err) reject(err);
      else resolve(blob);
    };

    const onError = () => finish(new Error("WebSocket error"));
    const onClose = (event) => {
      if (finished) return;
      const reason = event && event.code === 1008 ? "Неверный токен" : "WebSocket закрыт";
      finish(new Error(reason));
    };

    const onMessage = (event) => {
      let data = null;
      try {
        data = JSON.parse(event.data);
      } catch {
        return;
      }
      if (!data || typeof data.type !== "string") return;

      if (data.type === "file_chunk" && typeof data.chunk === "string") {
        chunks.push(base64ToUint8Array(data.chunk));
        return;
      }
      if (data.type === "download_end") {
        const mime = guessMimeType(filename);
        const blob = new Blob(chunks, mime ? { type: mime } : {});
        finish(null, blob);
        return;
      }
      if (data.type === "error") {
        finish(new Error(data.message || "Ошибка скачивания"));
      }
    };

    ws.addEventListener("message", onMessage);
    ws.addEventListener("close", onClose);
    ws.addEventListener("error", onError);

    try {
      ws.send(JSON.stringify({ type: "download_start", filename }));
    } catch (err) {
      finish(err);
    }
  });
}

async function getWsFileObjectUrl(filename) {
  if (!filename) return "";
  const key = buildWsFileUrl(filename);
  const cached = mediaObjectUrlCache.get(key);
  if (cached) return cached;
  if (wsFilePending.has(key)) return wsFilePending.get(key);

  const promise = downloadFileBlob(filename)
    .then((blob) => {
      const objUrl = URL.createObjectURL(blob);
      mediaObjectUrlCache.set(key, objUrl);
      wsFilePending.delete(key);
      return objUrl;
    })
    .catch((err) => {
      wsFilePending.delete(key);
      throw err;
    });

  wsFilePending.set(key, promise);
  return promise;
}

async function downloadFileToDisk(filename) {
  if (!filename) return;
  try {
    const blob = await downloadFileBlob(filename);
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    link.remove();
    setTimeout(() => {
      try { URL.revokeObjectURL(url); } catch { }
    }, 1000);
  } catch (err) {
    toast(err.message || "Ошибка скачивания");
  }
}

function createDownloadLinkElement(link, label) {
  const fileDiv = document.createElement("div");
  fileDiv.className = "message-file";
  const icon = document.createElement("span");
  icon.innerHTML = "&#128196; ";
  const anchor = document.createElement("a");
  const filename = isWsFileUrl(link) ? (getWsFileName(link) || label) : label;
  anchor.textContent = label || filename || "file";

  if (isWsFileUrl(link)) {
    anchor.href = "#";
    anchor.addEventListener("click", (e) => {
      e.preventDefault();
      downloadFileToDisk(filename);
    });
  } else {
    anchor.href = link;
    anchor.target = "_blank";
    anchor.rel = "noreferrer";
  }

  fileDiv.appendChild(icon);
  fileDiv.appendChild(anchor);
  return fileDiv;
}
function buildDownloadUrl(name) {
  if (!name) return "";
  return buildWsFileUrl(name);
}
function normalizeMediaUrl(url) {
  if (!url) return "";
  if (url.startsWith("blob:") || url.startsWith("data:") || isWsFileUrl(url)) return url;
  if (!url.startsWith("http://") && !url.startsWith("https://") && !url.startsWith("/") && !url.includes("/")) {
    return buildDownloadUrl(url);
  }
  try {
    const base = new URL(state.apiBase);
    const target = new URL(url, base);
    if (target.origin === base.origin) {
      if (state.session?.token && !target.searchParams.get("token")) {
        target.searchParams.set("token", state.session.token);
      }
      if (state.session?.username && !target.searchParams.get("username")) {
        target.searchParams.set("username", state.session.username);
      }
    }
    return target.toString();
  } catch {
    return url;
  }
}
async function fetchMediaBlob(url) {
  if (!url) {
    throw new Error("download failed: empty url");
  }
  if (isWsFileUrl(url)) {
    const filename = getWsFileName(url);
    return await downloadFileBlob(filename);
  }
  if ("caches" in window) {
    try {
      const cache = await caches.open(MEDIA_CACHE_NAME);
      const cached = await cache.match(url);
      if (cached) {
        return await cached.blob();
      }
    } catch { }
  }
  const headers = {};
  if (state.session?.token) {
    headers.Authorization = `Bearer ${state.session.token}`;
    headers["X-Token"] = state.session.token;
  }
  if (state.session?.username) {
    headers["X-Username"] = state.session.username;
  }
  const res = await fetch(url, { headers });
  if (!res.ok) {
    throw new Error(`download failed: ${res.status}`);
  }
  const blob = await res.blob();
  if ("caches" in window) {
    try {
      const cache = await caches.open(MEDIA_CACHE_NAME);
      await cache.put(url, new Response(blob));
    } catch { }
  }
  return blob;
}
const MEDIA_CACHE_NAME = "niosmess-media-cache-v1";
const mediaObjectUrlCache = new Map();
async function primeMediaCache(url) {
  if (!url || mediaObjectUrlCache.has(url) || !("caches" in window)) return;
  if (isWsFileUrl(url)) {
    const filename = getWsFileName(url);
    getWsFileObjectUrl(filename).catch(() => { });
    return;
  }
  try {
    const cache = await caches.open(MEDIA_CACHE_NAME);
    let res = await cache.match(url);
    if (!res) {
      const blob = await fetchMediaBlob(url);
      await cache.put(url, new Response(blob));
      res = await cache.match(url);
    }
    if (res) {
      const blob = await res.blob();
      const objUrl = URL.createObjectURL(blob);
      mediaObjectUrlCache.set(url, objUrl);
    }
  } catch { }
}
function setMediaElementSource(el, url, sourceEl) {
  if (!el || !url) return;
  if (isWsFileUrl(url)) {
    const filename = getWsFileName(url);
    getWsFileObjectUrl(filename)
      .then((objUrl) => {
        el.src = objUrl;
        if (sourceEl) sourceEl.src = objUrl;
      })
      .catch(() => { });
    return;
  }
  const cached = mediaObjectUrlCache.get(url);
  if (cached) {
    el.src = cached;
    if (sourceEl) sourceEl.src = cached;
    return;
  }
  el.src = url;
  if (sourceEl) sourceEl.src = url;
  primeMediaCache(url);
}
async function clearMediaCache() {
  if ("caches" in window) {
    try {
      await caches.delete(MEDIA_CACHE_NAME);
    } catch { }
  }
  wsFilePending.clear();
  mediaObjectUrlCache.forEach((url) => {
    try {
      URL.revokeObjectURL(url);
    } catch { }
  });
  mediaObjectUrlCache.clear();
  if (typeof clearAvatarCache === "function") {
    await clearAvatarCache();
  }
  if (typeof clearProfileCache === "function") {
    clearProfileCache();
  }
  if (typeof refreshCacheStats === "function") {
    refreshCacheStats();
  }
  toast("Кеш очищен");
}

function formatBytes(bytes) {
  if (!bytes || bytes <= 0) return "0 MB";
  const units = ["B", "KB", "MB", "GB"];
  let idx = 0;
  let value = bytes;
  while (value >= 1024 && idx < units.length - 1) {
    value /= 1024;
    idx += 1;
  }
  return `${value.toFixed(value >= 10 || idx === 0 ? 0 : 1)} ${units[idx]}`;
}

async function getCacheStats(cacheName) {
  if (!("caches" in window)) {
    return { count: 0, bytes: 0 };
  }
  try {
    const cache = await caches.open(cacheName);
    const keys = await cache.keys();
    let bytes = 0;
    for (const key of keys) {
      const res = await cache.match(key);
      if (!res) continue;
      const blob = await res.clone().blob();
      bytes += blob.size || 0;
    }
    return { count: keys.length, bytes };
  } catch {
    return { count: 0, bytes: 0 };
  }
}

async function refreshCacheStats() {
  const mediaSize = $("cacheMediaSize");
  const mediaCount = $("cacheMediaCount");
  const avatarSize = $("cacheAvatarSize");
  const avatarCount = $("cacheAvatarCount");
  const updated = $("cacheUpdatedAt");
  const usageWrap = $("cacheUsage");
  const usageFill = $("cacheUsageFill");
  const usageMeta = $("cacheUsageMeta");
  if (!mediaSize || !mediaCount || !avatarSize || !avatarCount || !updated) return;

  const [media, avatar] = await Promise.all([
    getCacheStats(MEDIA_CACHE_NAME),
    getCacheStats(typeof AVATAR_CACHE_NAME === "string" ? AVATAR_CACHE_NAME : "niosmess-avatar-cache-v1"),
  ]);

  mediaSize.textContent = formatBytes(media.bytes);
  mediaCount.textContent = `${media.count} файлов`;
  avatarSize.textContent = formatBytes(avatar.bytes);
  avatarCount.textContent = `${avatar.count} шт`;
  updated.textContent = new Date().toLocaleString();

  if (usageWrap && usageFill && usageMeta && navigator.storage?.estimate) {
    try {
      const estimate = await navigator.storage.estimate();
      const usage = estimate.usage || 0;
      const quota = estimate.quota || 0;
      const percent = quota > 0 ? Math.min(100, Math.round((usage / quota) * 100)) : 0;
      usageFill.style.width = `${percent}%`;
      usageMeta.textContent = quota > 0 ? `${formatBytes(usage)} из ${formatBytes(quota)} (${percent}%)` : formatBytes(usage);
      usageWrap.hidden = false;
    } catch {
      usageWrap.hidden = true;
    }
  }
}
function inferMediaType({ ext, mime }) {
  if (mime) {
    if (mime.startsWith("image/")) return "image";
    if (mime.startsWith("video/")) return "video";
    if (mime.startsWith("audio/")) return "audio";
  }
  if (ext && MEDIA_IMAGE_EXT.has(ext)) return "image";
  if (ext && MEDIA_VIDEO_EXT.has(ext)) return "video";
  if (ext && MEDIA_AUDIO_EXT.has(ext)) return "audio";
  return "file";
}
function resolveReplyData(replyData) {
  if (!replyData) return null;
  if (typeof replyData === "object") return replyData;
  const id = String(replyData);
  const found = state.messages?.find((m) => String(m.id || m.temp_id) === id);
  return found || { id };
}
function getReplyAuthorName(replyData) {
  const username = replyData?.username || replyData?.sender || replyData?.user || "";
  const cached = username ? state.userInfoCache?.[username] : null;
  const rawName = replyData?.name || cached?.name || username || "Пользователь";
  return deobfuscate(String(rawName));
}
function getReplyPreviewText(replyData) {
  if (!replyData) return "Сообщение";
  const raw = String(replyData.text || replyData.message || "");
  const plain = raw.startsWith("FILE:") || raw.startsWith("MEDIA:") || raw.startsWith("STICKER:") || raw.startsWith("GIF:") || raw.startsWith("POLL:") || raw.startsWith("LOCATION:") || raw.startsWith("CONTACT:")
    ? raw
    : deobfuscate(raw);

  if (plain.startsWith("POLL:")) return "Опрос";
  if (plain.startsWith("LOCATION:")) return "Геолокация";
  if (plain.startsWith("CONTACT:")) return "Контакт";
  if (plain.startsWith("STICKER:")) return "Стикер";
  if (plain.startsWith("GIF:")) return "GIF";
  if (plain.startsWith("MEDIA:")) {
    try {
      const data = JSON.parse(plain.slice(6).trim());
      const kind = data?.kind || data?.type || inferMediaType({ ext: (data?.name || "").split(".").pop(), mime: data?.mime || data?.content_type || "" });
      if (data?.is_voice || kind === "voice") return "Голосовое сообщение";
      if (kind === "audio") return "Музыка";
      if (kind === "video") return "Видео";
      if (kind === "image") return "Фото";
      return "Файл";
    } catch {
      return "Файл";
    }
  }
  if (plain.startsWith("FILE:")) {
    const payload = plain.replace("FILE:", "").trim();
    const ext = payload.toLowerCase().split(".").pop();
    const kind = inferMediaType({ ext, mime: "" });
    if (kind === "image") return "Фото";
    if (kind === "video") return "Видео";
    if (kind === "audio") return replyData?.is_voice ? "Голосовое сообщение" : "Музыка";
    return "Файл";
  }
  if (replyData?.is_voice) return "Голосовое сообщение";
  return plain.substring(0, 120) || "Сообщение";
}
function getAttachmentFromMessage(m) {
  const attachment = m.attachment || m.file || m.media || null;
  let name = "";
  let url = "";
  let mime = "";
  let size = null;
  let duration = null;
  let waveform = null;
  let kind = "";
  let thumbUrl = "";
  let stickerEmoji = "";

  if (attachment) {
    name = attachment.name || attachment.filename || attachment.file_name || attachment.id || attachment.file_id || "";
    url = attachment.url || attachment.file_url || attachment.download_url || "";
    mime = attachment.type || attachment.mime || attachment.content_type || "";
    size = attachment.size || attachment.file_size || null;
    duration = attachment.duration || attachment.length || null;
    waveform = attachment.waveform || attachment.wave || null;
    kind = attachment.kind || attachment.media_type || attachment.type || kind;
    thumbUrl = attachment.thumb_url || attachment.thumb || attachment.preview_url || attachment.preview || "";
  }

  if (!url) url = m.file_url || m.fileUrl || "";
  if (!name) name = m.file_name || m.filename || "";
  if (!size) size = m.size || m.file_size || null;
  if (!duration) duration = m.duration || m.length || null;
  if (!waveform) waveform = m.waveform || m.wave || null;
  if (!thumbUrl) thumbUrl = m.thumb_url || m.thumb || m.preview_url || m.preview || "";

  const rawText = typeof m.text === "string" ? m.text : "";
  if (rawText) {
    const plainText = rawText.startsWith("FILE:") || rawText.startsWith("MEDIA:") || rawText.startsWith("STICKER:") || rawText.startsWith("GIF:")
      ? rawText
      : deobfuscate(rawText);
    if (plainText.startsWith("MEDIA:")) {
      const payload = plainText.slice(6).trim();
      try {
        const data = JSON.parse(payload);
        if (data) {
          name = data.name || data.file_name || name;
          url = data.url || data.file_url || url;
          mime = data.mime || data.content_type || mime;
          size = data.size || size;
          duration = data.duration || duration;
          waveform = data.waveform || waveform;
          kind = data.kind || data.type || kind;
          thumbUrl = data.thumb || data.thumb_url || thumbUrl;
          if (data.is_voice != null) m.is_voice = data.is_voice;
        }
      } catch { }
    } else if (plainText.startsWith("STICKER:")) {
      const payload = plainText.slice(8).trim();
      kind = "sticker";
      if (payload.startsWith("{")) {
        try {
          const data = JSON.parse(payload);
          if (data) {
            url = data.url || url;
            stickerEmoji = data.emoji || data.text || stickerEmoji;
          }
        } catch { }
      } else if (payload.startsWith("http") || payload.startsWith("data:")) {
        url = payload;
      } else {
        stickerEmoji = payload;
      }
    } else if (plainText.startsWith("GIF:")) {
      const payload = plainText.slice(4).trim();
      kind = "gif";
      if (payload.startsWith("{")) {
        try {
          const data = JSON.parse(payload);
          if (data) {
            url = data.url || url;
            name = data.name || name;
          }
        } catch { }
      } else {
        url = payload;
      }
    } else if (plainText.startsWith("FILE:")) {
      const payload = plainText.replace("FILE:", "").trim();
      if (payload.startsWith("http") || payload.startsWith("data:")) {
        url = payload;
      } else {
        name = payload;
      }
    } else if (!name) {
      const candidate = plainText.trim();
      const candidateExt = candidate.toLowerCase().split(".").pop();
      if (candidateExt && (MEDIA_IMAGE_EXT.has(candidateExt) || MEDIA_AUDIO_EXT.has(candidateExt) || MEDIA_VIDEO_EXT.has(candidateExt))) {
        name = candidate;
      }
    }
  }

  if (!url && name) url = buildDownloadUrl(name);

  if (!name && url) {
    try {
      const parsed = new URL(url);
      name = decodeURIComponent(parsed.pathname.split("/").pop() || "");
    } catch {
      name = url.split("/").pop() || "";
    }
  }

  let ext = name ? name.toLowerCase().split(".").pop() : "";
  if (ext) {
    ext = ext.split("?")[0].split("#")[0].replace(/[^a-z0-9]/g, "");
  }
  if ((!ext || ext === name.toLowerCase()) && url) {
    try {
      const parsed = new URL(url);
      const last = parsed.pathname.split("/").pop() || "";
      const candidate = last.toLowerCase();
      if (candidate.includes(".")) {
        ext = candidate.split(".").pop();
        if (!name) name = decodeURIComponent(last);
      }
    } catch { }
  }

  const baseType = inferMediaType({ ext, mime });
  const type = kind === "gif" || kind === "sticker" ? "image" : baseType;
  const isVoice = !!m.voice || !!m.is_voice || (type === "audio" && /^voice_/i.test(name));

  return {
    name,
    url: normalizeMediaUrl(url),
    ext,
    mime,
    type,
    isVoice,
    size,
    duration,
    waveform,
    thumbUrl: normalizeMediaUrl(thumbUrl),
    kind,
    stickerEmoji,
  };
}
function createMessageElement(m, container) {
  if (!container) return;
  const isMe = m.sender === state.session.username;
  const attachment = getAttachmentFromMessage(m);
  const isFile = !!attachment.url;
  const msgId = String(m.id || m.temp_id);

  const message = document.createElement("div");
  message.className = `message ${isMe ? "out" : "in"}`.trim();
  message.dataset.id = msgId;

  if (m.temp) message.classList.add("sending");
  if (state.favorites.has(msgId)) message.classList.add("favorite");
  if (state.activeTarget) {
    const pinned = getPinnedForChat(state.activeTarget);
    if (pinned && String(pinned.id || pinned.temp_id || "") === msgId) {
      message.classList.add("pinned");
    }
  }

  const replyData = resolveReplyData(m.reply_to || m.replyTo || m.reply || null);

  if (replyData && !m.deleted) {
    const replyWrap = document.createElement("div");
    replyWrap.className = "message-reply";

    const replyAuthor = document.createElement("div");
    replyAuthor.className = "message-reply-author";
    replyAuthor.textContent = getReplyAuthorName(replyData);

    const replyText = document.createElement("div");
    replyText.className = "message-reply-text";
    replyText.textContent = getReplyPreviewText(replyData);

    replyWrap.appendChild(replyAuthor);
    replyWrap.appendChild(replyText);
    message.appendChild(replyWrap);
  }

  if (m.uploading) {
    const upload = m.upload || {};
    const total = Number(upload.total || 0);
    const loaded = Number(upload.loaded || 0);
    const percent = total > 0 ? Math.min(100, Math.round((loaded / total) * 100)) : 0;

    const uploadWrap = document.createElement("div");
    uploadWrap.className = "upload-inline";

    const name = document.createElement("div");
    name.className = "upload-inline-name";
    name.textContent = upload.name || "Файл";

    const bar = document.createElement("div");
    bar.className = "upload-inline-bar";
    const fill = document.createElement("div");
    fill.className = "upload-inline-fill";
    fill.style.width = `${percent}%`;
    bar.appendChild(fill);

    const meta = document.createElement("div");
    meta.className = "upload-inline-meta";
    const percentEl = document.createElement("span");
    percentEl.className = "upload-inline-percent";
    percentEl.textContent = `${percent}%`;
    const bytesEl = document.createElement("span");
    bytesEl.className = "upload-inline-bytes";
    const totalText = formatBytes(total) || "0 B";
    const loadedText = formatBytes(loaded) || "0 B";
    bytesEl.textContent = `${loadedText} / ${totalText}`;
    const speedEl = document.createElement("span");
    speedEl.className = "upload-inline-speed";
    speedEl.textContent = formatSpeed(upload.speed || 0);

    meta.appendChild(percentEl);
    meta.appendChild(bytesEl);
    meta.appendChild(speedEl);

    uploadWrap.appendChild(name);
    uploadWrap.appendChild(bar);
    uploadWrap.appendChild(meta);
    message.appendChild(uploadWrap);
    container.appendChild(message);
    return;
  }

  if (m.deleted) {
    const deletedSpan = document.createElement("span");
    deletedSpan.className = "message-deleted";
    deletedSpan.textContent = "\u0421\u043e\u043e\u0431\u0449\u0435\u043d\u0438\u0435 \u0443\u0434\u0430\u043b\u0435\u043d\u043e";
    message.appendChild(deletedSpan);
  } else if (isFile) {
    const raw = attachment.name || "file";
    const link = attachment.url || buildDownloadUrl(raw);

    if (attachment.type === "image") {
      const preview = document.createElement("div");
      preview.className = "file-preview";

      const img = document.createElement("img");
      setMediaElementSource(img, link);
      img.alt = raw;
      img.loading = "lazy";
      img.onerror = () => {
        fetchMediaBlob(link)
          .then((blob) => {
            img.src = URL.createObjectURL(blob);
          })
          .catch(() => {
            preview.remove();
            message.appendChild(createDownloadLinkElement(link, raw));
          });
      };

      preview.appendChild(img);
      message.appendChild(preview);

      preview.addEventListener("click", () => openMediaViewer({ type: "image", url: link, name: raw }));
    } else if (attachment.type === "audio") {
      if (attachment.isVoice) {
        const voiceEl = createVoicePlayer(link, attachment.mime || "audio/webm", attachment.duration, attachment.waveform);
        message.appendChild(voiceEl);
      } else {
        const audioWrap = document.createElement("div");
        audioWrap.className = "message-audio";
        const audio = document.createElement("audio");
        audio.controls = true;
        audio.preload = "metadata";
        const source = document.createElement("source");
        setMediaElementSource(audio, link, source);
        audio.onerror = () => {
          fetchMediaBlob(link)
            .then((blob) => {
              audio.src = URL.createObjectURL(blob);
            })
            .catch(() => { });
        };
        source.type = attachment.mime || "audio/webm";
        audio.appendChild(source);
        audioWrap.appendChild(audio);
        const openBtn = document.createElement("button");
        openBtn.className = "audio-open-btn";
        openBtn.type = "button";
        openBtn.innerHTML = `
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none">
            <path d="M8 5l11 7-11 7V5z" fill="currentColor"/>
          </svg>
        `;
        const cleanTitle = raw.replace(/\.[^/.]+$/, "");
        openBtn.addEventListener("click", (e) => {
          e.stopPropagation();
          const queue = getMusicQueueFromMessages();
          const src = audio.currentSrc || link;
          const track = { src, title: cleanTitle, artist: "NiosMess" };
          const idx = queue.findIndex((t) => t.src === src);
          openMusicPlayer(track, queue, idx);
        });
        audioWrap.addEventListener("click", (e) => {
          if (e.target === audio) return;
          const queue = getMusicQueueFromMessages();
          const src = audio.currentSrc || link;
          const track = { src, title: cleanTitle, artist: "NiosMess" };
          const idx = queue.findIndex((t) => t.src === src);
          openMusicPlayer(track, queue, idx);
        });
        audioWrap.appendChild(openBtn);
        message.appendChild(audioWrap);
      }
    } else if (attachment.type === "video") {
      const isVideoNote = attachment.kind === "video_note" || !!m.is_video_note;
      if (isVideoNote) {
        const noteWrap = document.createElement("div");
        noteWrap.className = "message-video-note";
        const video = document.createElement("video");
        video.playsInline = true;
        video.preload = "metadata";
        video.loop = false;
        setMediaElementSource(video, link);
        video.onerror = () => {
          fetchMediaBlob(link).then(blob => { video.src = URL.createObjectURL(blob); }).catch(() => { });
        };
        const notePlayBtn = document.createElement("button");
        notePlayBtn.className = "video-note-play";
        notePlayBtn.type = "button";
        notePlayBtn.innerHTML = `<svg viewBox="0 0 24 24" fill="currentColor" width="24" height="24"><path d="M8 5l11 7-11 7V5z"/></svg>`;
        notePlayBtn.addEventListener("click", () => {
          if (video.paused) { video.play().catch(() => { }); notePlayBtn.style.display = "none"; }
        });
        video.addEventListener("ended", () => { notePlayBtn.style.display = ""; });
        video.addEventListener("pause", () => { notePlayBtn.style.display = ""; });
        noteWrap.appendChild(video);
        noteWrap.appendChild(notePlayBtn);
        message.appendChild(noteWrap);
      } else {
        const video = document.createElement("video");
        setMediaElementSource(video, link);
        video.controls = true;
        video.playsInline = true;
        video.preload = "metadata";
        video.onerror = () => {
          fetchMediaBlob(link)
            .then((blob) => {
              video.src = URL.createObjectURL(blob);
            })
            .catch(() => { });
        };
        video.style.maxWidth = "100%";
        video.style.borderRadius = "10px";
        message.appendChild(video);
      }
    } else {
      message.appendChild(createDownloadLinkElement(link, raw));
    }
  } else {
    const safe = String(m.text || "");
    const deobf = deobfuscate(safe).replace(/\s+/g, " ").trim();

    if (deobf.startsWith("POLL:")) {
      const raw = deobf.slice(5).trim();
      let pollData = null;
      try {
        pollData = JSON.parse(raw);
      } catch {
        pollData = null;
      }
      if (pollData) {
        const poll = normalizePoll({
          id: pollData.id,
          question: pollData.question,
          options: pollData.options,
          multiple: pollData.multiple,
          votedBy: (state.polls[pollData.id] || {}).votedBy || {},
        });
        state.polls[poll.id] = { ...state.polls[poll.id], ...poll };
        localStorage.setItem("niosmess_polls", JSON.stringify(state.polls));
        message.classList.add("has-poll");
        renderPollMessage(message, poll);
        container.appendChild(message);
        return;
      }
    }

    if (deobf.startsWith("LOCATION:")) {
      const raw = deobf.slice(9).trim();
      let loc = null;
      try {
        loc = JSON.parse(raw);
      } catch {
        loc = null;
      }
      if (loc && Number.isFinite(Number(loc.lat)) && Number.isFinite(Number(loc.lon))) {
        const lat = Number(loc.lat);
        const lon = Number(loc.lon);
        const label = loc.label ? String(loc.label) : "\u0413\u0435\u043e\u043b\u043e\u043a\u0430\u0446\u0438\u044f";
        const card = document.createElement("div");
        card.className = "message-location";
        const link = `https://maps.google.com/?q=${lat},${lon}`;
        card.innerHTML = `
          <div class="location-title">${label}</div>
          <div class="location-coords">${lat.toFixed(6)}, ${lon.toFixed(6)}</div>
          <a class="location-link" href="${link}" target="_blank" rel="noreferrer">\u041e\u0442\u043a\u0440\u044b\u0442\u044c \u043a\u0430\u0440\u0442\u0443</a>
        `;
        message.appendChild(card);
        container.appendChild(message);
        return;
      }
    }

    if (deobf.startsWith("CONTACT:")) {
      const raw = deobf.slice(8).trim();
      let contact = null;
      try {
        contact = JSON.parse(raw);
      } catch {
        contact = null;
      }
      if (contact) {
        const card = document.createElement("div");
        card.className = "message-contact";
        const title = document.createElement("div");
        title.className = "contact-title";
        title.textContent = contact.name || "\u041a\u043e\u043d\u0442\u0430\u043a\u0442";
        card.appendChild(title);

        const list = document.createElement("div");
        list.className = "contact-list";

        const addRow = (label, value) => {
          if (!value) return;
          const row = document.createElement("div");
          row.className = "contact-row";
          row.innerHTML = `<span class="contact-label">${label}</span><span class="contact-value">${value}</span>`;
          list.appendChild(row);
        };

        addRow("\u0422\u0435\u043b\u0435\u0444\u043e\u043d", contact.phone);
        addRow("\u041b\u043e\u0433\u0438\u043d", contact.username);
        addRow("Email", contact.email);

        card.appendChild(list);
        message.appendChild(card);
        container.appendChild(message);
        return;
      }
    }

    const urlRegex = /(https?:\/\/[^\s]+)/g;
    const urls = deobf.match(urlRegex);

    const formatted = parseMarkdown(deobf);
    const textSpan = document.createElement("span");
    textSpan.innerHTML = formatted;
    message.appendChild(textSpan);

    if (urls && urls.length > 0) {
      addLinkPreview(message, urls[0]);
    }
  }

  const reactionData = getReactions(msgId);
  const reactions = reactionData.counts || {};
  const reactionKeys = Object.keys(reactions);
  if (reactionKeys.length) {
    const reactionsWrap = document.createElement("div");
    reactionsWrap.className = "message-reactions";
    reactionKeys.forEach((emoji) => {
      const pill = document.createElement("button");
      pill.className = "reaction-pill";
      if (reactionData.mine && reactionData.mine[emoji]) pill.classList.add("active");
      pill.textContent = `${emoji} ${reactions[emoji]}`;
      pill.addEventListener("click", (e) => {
        e.stopPropagation();
        toggleReaction(msgId, emoji);
        updateMessageReactions(msgId);
      });
      reactionsWrap.appendChild(pill);
    });
    message.appendChild(reactionsWrap);
  }

  const meta = document.createElement("div");
  meta.className = "message-meta";

  const timeValue = m.time || m.created_at || m.timestamp || m.date;
  const timeText = formatMessageTime(timeValue);
  if (timeText) {
    const timeSpan = document.createElement("span");
    timeSpan.className = "message-time";
    timeSpan.textContent = timeText;
    meta.appendChild(timeSpan);
  }

  if (m.edited || m.edited_at || m.editedAt) {
    const editedSpan = document.createElement("span");
    editedSpan.className = "message-edited";
    editedSpan.textContent = "\u0438\u0437\u043c\u0435\u043d\u0435\u043d\u043e";
    meta.appendChild(editedSpan);
  }

  if (isMe) {
    const status = document.createElement("span");
    status.className = "message-status";
    const isRead = state.activeChatType === "user" ? normalizeReadFlag(m) : false;
    status.textContent = m.temp ? "\u2026" : (isRead ? "\u2713\u2713" : "\u2713");
    meta.appendChild(status);
  }

  if (meta.childNodes.length) message.appendChild(meta);

  message.addEventListener("contextmenu", (e) => {
    e.preventDefault();
    showContextMenu(e, message, m);
  });

  message.addEventListener("dblclick", () => {
    toggleReaction(msgId, "👍");
    updateMessageReactions(msgId);
  });

  container.appendChild(message);
}
function updateMessageReactions(msgId) {
  const el = document.querySelector(`[data-id="${msgId}"]`);
  if (!el) return;
  const existing = el.querySelector(".message-reactions");
  if (existing) existing.remove();

  const reactionData = getReactions(msgId);
  const reactions = reactionData.counts || {};
  const keys = Object.keys(reactions);
  if (!keys.length) return;

  const reactionsWrap = document.createElement("div");
  reactionsWrap.className = "message-reactions";
  keys.forEach((emoji) => {
    const pill = document.createElement("button");
    pill.className = "reaction-pill";
    if (reactionData.mine && reactionData.mine[emoji]) pill.classList.add("active");
    pill.textContent = `${emoji} ${reactions[emoji]}`;
    pill.addEventListener("click", (e) => {
      e.stopPropagation();
      toggleReaction(msgId, emoji);
      updateMessageReactions(msgId);
    });
    reactionsWrap.appendChild(pill);
  });
  el.appendChild(reactionsWrap);
}
function parseMarkdown(text) {
  let result = text;

  result = result.replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>");
  result = result.replace(/__(.+?)__/g, "<strong>$1</strong>");

  result = result.replace(/\*(.+?)\*/g, "<em>$1</em>");
  result = result.replace(/_(.+?)_/g, "<em>$1</em>");

  result = result.replace(/`(.+?)`/g, "<code>$1</code>");

  result = result.replace(/~~(.+?)~~/g, "<del>$1</del>");

  return result;
}
function openMediaViewer(item) {
  const viewer = $("mediaViewer");
  const body = $("mediaViewerBody");
  const download = $("mediaViewerDownload");
  if (!viewer || !body || !download) return;

  body.innerHTML = "";
  download.onclick = null;
  download.href = item.url;
  if (isWsFileUrl(item.url)) {
    const filename = item.name || getWsFileName(item.url);
    download.href = "#";
    download.onclick = (e) => {
      e.preventDefault();
      downloadFileToDisk(filename);
    };
  }

  if (item.type === "image") {
    const img = document.createElement("img");
    setMediaElementSource(img, item.url);
    img.alt = item.name || "";
    img.onerror = () => {
      fetchMediaBlob(item.url)
        .then((blob) => {
          img.src = URL.createObjectURL(blob);
        })
        .catch(() => { });
    };
    body.appendChild(img);
  } else if (item.type === "video") {
    const video = document.createElement("video");
    setMediaElementSource(video, item.url);
    video.controls = true;
    video.playsInline = true;
    video.preload = "metadata";
    video.onerror = () => {
      fetchMediaBlob(item.url)
        .then((blob) => {
          video.src = URL.createObjectURL(blob);
        })
        .catch(() => { });
    };
    body.appendChild(video);
  } else if (item.type === "audio") {
    const audio = document.createElement("audio");
    setMediaElementSource(audio, item.url);
    audio.controls = true;
    audio.preload = "metadata";
    audio.onerror = () => {
      fetchMediaBlob(item.url)
        .then((blob) => {
          audio.src = URL.createObjectURL(blob);
        })
        .catch(() => { });
    };
    body.appendChild(audio);
  } else {
    const link = document.createElement("a");
    if (isWsFileUrl(item.url)) {
      const filename = item.name || getWsFileName(item.url);
      link.href = "#";
      link.addEventListener("click", (e) => {
        e.preventDefault();
        downloadFileToDisk(filename);
      });
    } else {
      link.href = item.url;
      link.target = "_blank";
      link.rel = "noreferrer";
    }
    link.textContent = item.name || item.url;
    body.appendChild(link);
  }

  viewer.classList.remove("hidden");
}
function closeMediaViewer() {
  $("mediaViewer")?.classList.add("hidden");
  $("mediaViewerBody") && ($("mediaViewerBody").innerHTML = "");
}
function buildMediaItems(messages) {
  const items = [];

  messages.forEach((m) => {
    const attachment = getAttachmentFromMessage(m);
    if (!attachment.url) return;
    const name = attachment.name || (isWsFileUrl(attachment.url) ? getWsFileName(attachment.url) : attachment.url);
    items.push({ type: attachment.type, url: attachment.url, name });
  });

  return items;
}
function openMediaGallery() {
  const gallery = $("mediaGallery");
  const grid = $("mediaGalleryGrid");
  if (!gallery || !grid) return;

  const items = buildMediaItems(state.messages || []);
  grid.innerHTML = "";
  if (!items.length) {
    toast("Медиа нет");
    return;
  }

  items.forEach((item) => {
    const card = document.createElement("div");
    card.className = "media-card";

    if (item.type === "image") {
      const img = document.createElement("img");
      setMediaElementSource(img, item.url);
      img.alt = item.name || "";
      img.onerror = () => {
        fetchMediaBlob(item.url)
          .then((blob) => {
            img.src = URL.createObjectURL(blob);
          })
          .catch(() => { });
      };
      card.appendChild(img);
    } else if (item.type === "video") {
      const video = document.createElement("video");
      setMediaElementSource(video, item.url);
      video.muted = true;
      video.playsInline = true;
      video.preload = "metadata";
      video.onerror = () => {
        fetchMediaBlob(item.url)
          .then((blob) => {
            video.src = URL.createObjectURL(blob);
          })
          .catch(() => { });
      };
      card.appendChild(video);
    } else {
      const info = document.createElement("div");
      info.className = "media-card-info";
      info.textContent = item.name || item.url;
      card.appendChild(info);
    }

    if (!card.querySelector(".media-card-info")) {
      const info = document.createElement("div");
      info.className = "media-card-info";
      info.textContent = item.name || item.url;
      card.appendChild(info);
    }

    card.addEventListener("click", () => openMediaViewer(item));
    grid.appendChild(card);
  });

  gallery.classList.remove("hidden");
}
function closeMediaGallery() {
  $("mediaGallery")?.classList.add("hidden");
}
function getYouTubeId(urlObj) {
  if (!urlObj) return "";
  if (urlObj.hostname.includes("youtu.be")) {
    return urlObj.pathname.replace("/", "");
  }
  const v = urlObj.searchParams.get("v");
  if (v) return v;
  const parts = urlObj.pathname.split("/");
  const idx = parts.findIndex((p) => p === "shorts" || p === "embed");
  if (idx >= 0 && parts[idx + 1]) return parts[idx + 1];
  return "";
}

function buildLinkPreviewData(url, meta = null) {
  const urlObj = new URL(url);
  const domain = urlObj.hostname.replace(/^www\./, "");
  const lower = domain.toLowerCase();
  let type = "link";
  let title = meta?.title || domain;
  let description = meta?.description || "";
  let image = meta?.image || "";
  let badge = "";
  let siteName = meta?.site_name || "";

  if (lower.includes("youtube.com") || lower.includes("youtu.be")) {
    type = "youtube";
    badge = "Видео";
    const id = getYouTubeId(urlObj);
    if (!image && id) image = `https://img.youtube.com/vi/${id}/hqdefault.jpg`;
    if (!siteName) siteName = "YouTube";
  } else if (lower.includes("spotify.com")) {
    type = "spotify";
    badge = "Музыка";
    if (!siteName) siteName = "Spotify";
  } else if (lower.includes("soundcloud.com")) {
    type = "soundcloud";
    badge = "Музыка";
    if (!siteName) siteName = "SoundCloud";
  } else if (lower.includes("t.me") || lower.includes("telegram.me")) {
    type = "telegram";
    if (!siteName) siteName = "Telegram";
  } else if (lower.includes("vk.com") || lower.includes("vk.ru")) {
    type = "vk";
    if (!siteName) siteName = "VK";
  }

  if (!title) title = siteName || domain;
  return {
    type,
    title,
    description,
    image,
    domain,
    badge,
    url,
    siteName: siteName || domain,
  };
}

async function fetchLinkPreviewMeta(url) {
  if (!state.session?.token || !state.session?.username) return null;
  try {
    const qs = new URLSearchParams({
      url,
      username: state.session.username,
      token: state.session.token,
    });
    const data = await apiFetch(`/link_preview?${qs.toString()}`, {}, { silent: true });
    if (!data || typeof data !== "object") return null;
    return {
      title: data.title || "",
      description: data.description || "",
      image: data.image || "",
      site_name: data.site_name || data.site || "",
      type: data.type || "",
      url: data.url || url,
    };
  } catch {
    return null;
  }
}

async function addLinkPreview(messageEl, url) {
  if (state.settings.linkPreviews === false) return;
  try {
    const meta = await fetchLinkPreviewMeta(url);
    const data = buildLinkPreviewData(url, meta);
    const preview = document.createElement("div");
    preview.className = `link-preview link-preview-${data.type}`;

    const media = document.createElement("div");
    media.className = "link-preview-media";
    if (data.image) {
      media.style.backgroundImage = `url(${data.image})`;
    }

    const body = document.createElement("div");
    body.className = "link-preview-body";

    const header = document.createElement("div");
    header.className = "link-preview-header";

    const title = document.createElement("div");
    title.className = "link-preview-title";
    title.textContent = data.title;

    header.appendChild(title);
    const subtitle = document.createElement("div");
    subtitle.className = "link-preview-url";
    subtitle.textContent = data.siteName || data.domain;

    const metaRow = document.createElement("div");
    metaRow.className = "link-preview-meta";
    metaRow.textContent = data.description || data.url;

    body.appendChild(header);
    body.appendChild(subtitle);
    body.appendChild(metaRow);

    preview.appendChild(media);
    preview.appendChild(body);

    preview.addEventListener("click", () => window.open(data.url, "_blank"));
    messageEl.appendChild(preview);
  } catch { }
}

function openForwardModal(messageData) {
  const modal = $("forwardModal");
  if (!modal || !messageData) return;

  state.forwardMessage = messageData;
  state.forwardTargets = new Set();

  const search = $("forwardSearch");
  if (search) search.value = "";
  const comment = $("forwardComment");
  if (comment) comment.value = "";

  renderForwardList("");
  modal.classList.remove("hidden");
}

function closeForwardModal() {
  const modal = $("forwardModal");
  if (!modal) return;
  modal.classList.add("hidden");
  state.forwardMessage = null;
  state.forwardTargets = new Set();
  const search = $("forwardSearch");
  if (search) search.value = "";
  const comment = $("forwardComment");
  if (comment) comment.value = "";
}

function renderForwardList(query = "") {
  const list = $("forwardList");
  if (!list) return;

  const q = String(query || "").trim().toLowerCase();
  const chats = Array.isArray(state.chatList) ? state.chatList : [];
  const filtered = chats.filter((chat) => {
    const chatId = String(chat.chatId || chat.username || "");
    if (chatId === FAVORITES_CHAT_ID) return false;
    const name = String(chat.name || chat.username || chatId || "").toLowerCase();
    return !q || name.includes(q);
  });

  list.innerHTML = "";
  if (!filtered.length) {
    const empty = document.createElement("div");
    empty.className = "forward-empty";
    empty.textContent = "\u0427\u0430\u0442\u044b \u043d\u0435 \u043d\u0430\u0439\u0434\u0435\u043d\u044b";
    list.appendChild(empty);
    return;
  }

  filtered.forEach((chat) => {
    const chatId = String(chat.chatId || chat.username || "");
    const item = document.createElement("button");
    item.type = "button";
    item.className = "forward-item";
    if (state.forwardTargets?.has(chatId)) item.classList.add("active");

    const title = document.createElement("div");
    title.className = "forward-title";
    title.textContent = chat.name || chat.username || chatId || "\u0427\u0430\u0442";

    const meta = document.createElement("div");
    meta.className = "forward-meta";
    if (chat.type && chat.type !== "user") {
      meta.textContent = `${chat.type} \u2022 ${chatId}`;
    } else {
      meta.textContent = chat.username ? `@${chat.username}` : chatId;
    }

    item.appendChild(title);
    item.appendChild(meta);
    item.addEventListener("click", () => {
      if (!state.forwardTargets) state.forwardTargets = new Set();
      if (state.forwardTargets.has(chatId)) {
        state.forwardTargets.delete(chatId);
        item.classList.remove("active");
      } else {
        state.forwardTargets.add(chatId);
        item.classList.add("active");
      }
    });

    list.appendChild(item);
  });
}

async function submitForward() {
  if (!state.session) return;
  const targets = Array.from(state.forwardTargets || []);
  if (!targets.length) {
    toast("\u0412\u044b\u0431\u0435\u0440\u0438\u0442\u0435 \u0447\u0430\u0442 \u0434\u043b\u044f \u043f\u0435\u0440\u0435\u0441\u044b\u043b\u043a\u0438");
    return;
  }

  const messageData = state.forwardMessage;
  if (!messageData) {
    toast("\u041d\u0435\u0442 \u0441\u043e\u043e\u0431\u0449\u0435\u043d\u0438\u044f \u0434\u043b\u044f \u043f\u0435\u0440\u0435\u0441\u044b\u043b\u043a\u0438");
    return;
  }

  const commentInput = $("forwardComment");
  const rawComment = commentInput?.value || "";
  const commentText = state.settings.trimSpaces === false ? rawComment : rawComment.replace(/\s+/g, " ").trim();

  const messageId = messageData.id || messageData.temp_id;
  if (!messageId) {
    toast("\u041d\u0435\u0432\u043e\u0437\u043c\u043e\u0436\u043d\u043e \u043f\u0435\u0440\u0435\u0441\u043b\u0430\u0442\u044c \u0441\u043e\u043e\u0431\u0449\u0435\u043d\u0438\u0435 \u0431\u0435\u0437 ID");
    return;
  }

  try {
    for (const target of targets) {
      const payload = {
        token: state.session.token,
        message_id: String(messageId),
        target_chat: target,
      };

      if (commentText) {
        payload.comment = obfuscate(commentText);
      }

      await apiFetch("/forward_message", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      }, { silent: true });
    }
    closeForwardModal();
    toast("\u041f\u0435\u0440\u0435\u0441\u043b\u0430\u043d\u043e");
  } catch (err) {
    toast(err.message || "\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u043f\u0435\u0440\u0435\u0441\u043b\u0430\u0442\u044c");
  }
}


function openScheduleModal() {
  const modal = $("scheduleModal");
  if (!modal) return;

  const dateInput = $("scheduleDate");
  const textInput = $("scheduleText");
  if (textInput) {
    const current = $("messageInput")?.value || "";
    textInput.value = current;
  }
  if (dateInput) {
    const now = new Date(Date.now() + 5 * 60 * 1000);
    const pad = (v) => String(v).padStart(2, "0");
    const value = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}T${pad(now.getHours())}:${pad(now.getMinutes())}`;
    if (!dateInput.value) dateInput.value = value;
  }

  modal.classList.remove("hidden");
}

function closeScheduleModal() {
  const modal = $("scheduleModal");
  if (!modal) return;
  modal.classList.add("hidden");
}

function openPollModal() {
  const modal = $("pollModal");
  if (!modal) return;
  const optionsWrap = $("pollOptions");
  if (optionsWrap) {
    optionsWrap.innerHTML = "";
    addPollOption();
    addPollOption();
  }
  const question = $("pollQuestion");
  if (question) question.value = "";
  const multiple = $("pollMultiple");
  if (multiple) multiple.checked = false;
  modal.classList.remove("hidden");
}

function closePollModal() {
  const modal = $("pollModal");
  if (!modal) return;
  modal.classList.add("hidden");
}

function addPollOption(value = "") {
  const optionsWrap = $("pollOptions");
  if (!optionsWrap) return;
  const row = document.createElement("div");
  row.className = "poll-option-row";

  const input = document.createElement("input");
  input.type = "text";
  input.className = "form-input poll-option-input";
  input.placeholder = "\u0412\u0430\u0440\u0438\u0430\u043d\u0442 \u043e\u0442\u0432\u0435\u0442\u0430";
  input.value = value;

  const remove = document.createElement("button");
  remove.type = "button";
  remove.className = "btn btn-secondary";
  remove.textContent = "\u00d7";
  remove.addEventListener("click", () => row.remove());

  row.appendChild(input);
  row.appendChild(remove);
  optionsWrap.appendChild(row);
}

function normalizePoll(poll) {
  const options = Array.isArray(poll.options) ? poll.options.map((opt) => {
    const rawId = opt.id ?? opt.index ?? `opt_${Math.random().toString(36).slice(2, 8)}`;
    const normalizedId = typeof rawId === "string" && rawId.trim() !== "" && !Number.isNaN(Number(rawId))
      ? Number(rawId)
      : rawId;
    return {
      id: normalizedId,
      text: String(opt.text || opt || "").trim(),
      votes: Number(opt.votes || 0),
    };
  }) : [];
  const normalized = {
    id: poll.id || `poll_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`,
    question: String(poll.question || "").trim(),
    options,
    multiple: !!poll.multiple,
    votedBy: poll.votedBy || {},
    createdBy: poll.createdBy || state.session?.username,
  };
  const existing = state.polls?.[normalized.id];
  if (existing?.options?.length) {
    normalized.options = normalized.options.map((opt) => {
      const prev = existing.options.find((item) => item.id === opt.id);
      return prev ? { ...opt, votes: Number(prev.votes || 0) } : opt;
    });
  }
  normalized.total = normalized.options.reduce((sum, opt) => sum + (opt.votes || 0), 0);
  return normalized;
}

async function syncPollVote(pollId, optionIds) {
  if (!state.session?.token || !pollId) return;
  const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-/i.test(pollId);
  if (!isUuid) return;
  try {
    await apiFetch(`/polls/vote`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        token: state.session.token,
        username: state.session.username,
        poll_id: pollId,
        option_ids: Array.isArray(optionIds) ? optionIds : [optionIds],
      }),
    }, { silent: true });
  } catch (err) {
    console.error("Failed to sync poll vote:", err);
  }
}

async function fetchPollResults(pollId) {
  if (!state.session?.token || !state.session?.username || !pollId) return null;
  const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-/i.test(pollId);
  if (!isUuid) return null;
  try {
    const data = await apiFetch(
      `/polls/${encodeURIComponent(pollId)}?token=${encodeURIComponent(state.session.token)}&username=${encodeURIComponent(state.session.username)}`,
      {},
      { silent: true }
    );
    if (data && data.options) {
      const counts = Array.isArray(data.counts) ? data.counts : [];
      return {
        id: data.id,
        question: data.question,
        options: data.options.map((opt) => ({
          id: opt.id,
          text: String(opt.text || "").trim(),
          votes: Number(counts[opt.id] || 0),
        })),
        multiple: !!data.multiple,
        my_votes: Array.isArray(data.my_votes) ? data.my_votes : [],
      };
    }
    return null;
  } catch (err) {
    console.error("Failed to fetch poll results:", err);
    return null;
  }
}


function renderPollMessage(message, poll) {
  const pollWrap = document.createElement("div");
  pollWrap.className = "message-poll";

  const question = document.createElement("div");
  question.className = "poll-question";
  question.textContent = poll.question || "\u041e\u043f\u0440\u043e\u0441";
  pollWrap.appendChild(question);

  const optionsList = document.createElement("div");
  optionsList.className = "poll-options";
  pollWrap.appendChild(optionsList);

  const footer = document.createElement("div");
  footer.className = "poll-footer";
  pollWrap.appendChild(footer);

  async function renderPollOptions() {
    const serverPoll = await fetchPollResults(poll.id);
    if (serverPoll) {
      poll.options = serverPoll.options;
      poll.total = poll.options.reduce((sum, opt) => sum + (opt.votes || 0), 0);
      poll.votedBy = poll.votedBy || {};
      poll.votedBy[state.session?.username] = serverPoll.my_votes || [];
      state.polls[poll.id] = { ...state.polls[poll.id], ...poll };
      localStorage.setItem("niosmess_polls", JSON.stringify(state.polls));
    }

    const userVotes = poll.votedBy?.[state.session?.username] || [];
    const totalVotes = poll.options.reduce((sum, opt) => sum + (opt.votes || 0), 0) || 1;
    optionsList.innerHTML = "";

    poll.options.forEach((opt) => {
      const option = document.createElement("div");
      option.className = "poll-option";
      if (userVotes.includes(opt.id)) option.classList.add("active");

      const bar = document.createElement("div");
      bar.className = "poll-bar";
      const percent = Math.round(((opt.votes || 0) / totalVotes) * 100);
      bar.style.width = `${percent}%`;

      const label = document.createElement("div");
      label.className = "poll-label";
      label.textContent = opt.text || "\u0412\u0430\u0440\u0438\u0430\u043d\u0442";

      const count = document.createElement("div");
      count.className = "poll-count";
      count.textContent = `${percent}%`;

      option.appendChild(bar);
      option.appendChild(label);
      option.appendChild(count);

      option.addEventListener("click", async () => {
        const username = state.session?.username;
        if (!username) return;
        const current = poll.votedBy?.[username] || [];
        let next;
        if (poll.multiple) {
          next = current.includes(opt.id)
            ? current.filter((id) => id !== opt.id)
            : [...current, opt.id];
        } else {
          next = current.includes(opt.id) ? [] : [opt.id];
        }
        poll.votedBy = poll.votedBy || {};
        poll.votedBy[username] = next;

        state.polls[poll.id] = { ...state.polls[poll.id], ...poll };
        localStorage.setItem("niosmess_polls", JSON.stringify(state.polls));

        await syncPollVote(poll.id, next);
        renderPollOptions();
      });

      optionsList.appendChild(option);
    });

    footer.textContent = `${poll.total || 0} \u0433\u043e\u043b\u043e\u0441\u043e\u0432`;
  }

  renderPollOptions();

  message.appendChild(pollWrap);
}


async function submitPoll() {
  const questionInput = $("pollQuestion");
  const optionsWrap = $("pollOptions");
  if (!questionInput || !optionsWrap) return;
  const question = questionInput.value.trim();
  if (!question) {
    toast("\u0412\u0432\u0435\u0434\u0438\u0442\u0435 \u0432\u043e\u043f\u0440\u043e\u0441");
    return;
  }

  const options = Array.from(optionsWrap.querySelectorAll("input"))
    .map((input) => input.value.trim())
    .filter(Boolean);

  if (options.length < 2) {
    toast("\u0414\u043e\u0431\u0430\u0432\u044c\u0442\u0435 \u043c\u0438\u043d\u0438\u043c\u0443\u043c 2 \u0432\u0430\u0440\u0438\u0430\u043d\u0442\u0430");
    return;
  }

  const multiple = $("pollMultiple")?.checked || false;
  const form = new FormData();
  form.append("token", state.session?.token || "");
  form.append("username", state.session?.username || "");
  form.append("chat_id", String(state.activeTarget || ""));
  form.append("question", question);
  form.append("options", JSON.stringify(options));
  form.append("multiple", String(!!multiple));

  let pollId = null;
  try {
    const created = await apiFetch("/polls/create", { method: "POST", body: form });
    pollId = created?.poll_id || null;
  } catch (err) {
    console.error("Failed to create poll:", err);
  }

  const poll = normalizePoll({
    id: pollId || undefined,
    question,
    options: options.map((text, idx) => ({ id: idx, text })),
    multiple,
  });

  state.polls[poll.id] = poll;
  localStorage.setItem("niosmess_polls", JSON.stringify(state.polls));

  const payload = {
    id: poll.id,
    question: poll.question,
    options: poll.options.map((opt) => ({ id: opt.id, text: opt.text })),
    multiple: poll.multiple,
  };

  const input = $("messageInput");
  if (input) {
    input.value = `POLL:${JSON.stringify(payload)}`;
    closePollModal();
    sendMessage();
  }
}

function formatTtlLabel(seconds) {
  const value = Number(seconds);
  if (!value) return "\u041d\u0435 \u0443\u0434\u0430\u043b\u044f\u0442\u044c";
  if (value < 60) return `${value} \u0441\u0435\u043a`;
  if (value < 3600) return `${Math.round(value / 60)} \u043c\u0438\u043d`;
  if (value < 86400) return `${Math.round(value / 3600)} \u0447`;
  return `${Math.round(value / 86400)} \u0434`;
}

function updateTtlIndicator() {
  const indicator = $("ttlIndicator");
  if (!indicator) return;
  if (state.messageTTL && state.messageTTL > 0) {
    indicator.textContent = formatTtlLabel(state.messageTTL);
    indicator.classList.remove("hidden");
  } else {
    indicator.textContent = "";
    indicator.classList.add("hidden");
  }
}

function openTtlModal() {
  const modal = $("ttlModal");
  if (!modal) return;
  const select = $("ttlSelect");
  if (select) select.value = String(state.messageTTL || 0);
  modal.classList.remove("hidden");
}

function closeTtlModal() {
  const modal = $("ttlModal");
  if (!modal) return;
  modal.classList.add("hidden");
}

function submitTtlModal() {
  const select = $("ttlSelect");
  if (!select) return;
  const value = Number(select.value || 0);
  state.messageTTL = Number.isFinite(value) ? value : 0;
  localStorage.setItem("niosmess_message_ttl", String(state.messageTTL));
  updateTtlIndicator();
  closeTtlModal();
  toast("\u0422\u0430\u0439\u043c\u0435\u0440 \u043e\u0431\u043d\u043e\u0432\u043b\u0435\u043d");
}

function openCreateChatModal(type = "group") {
  const modal = $("createChatModal");
  if (!modal) return;
  state.pendingCreateType = type;

  const title = $("createChatTitle");
  if (title) {
    title.textContent = type === "channel" ? "\u0421\u043e\u0437\u0434\u0430\u0442\u044c \u043a\u0430\u043d\u0430\u043b" : "\u0421\u043e\u0437\u0434\u0430\u0442\u044c \u0433\u0440\u0443\u043f\u043f\u0443";
  }

  $("createChatName").value = "";
  $("createChatDescription").value = "";
  $("createChatLink").value = "";
  $("createChatMembers").value = "";
  state.pendingCreateAvatar = "";
  state.pendingCreateAvatarFile = null;
  const preview = $("createChatAvatarPreview");
  if (preview) {
    preview.style.backgroundImage = "";
    preview.classList.remove("has-image");
    preview.textContent = "?";
  }

  const membersWrap = $("createChatMembersWrap");
  if (membersWrap) {
    membersWrap.classList.toggle("hidden", type === "channel");
  }

  modal.classList.remove("hidden");
}

function closeCreateChatModal() {
  const modal = $("createChatModal");
  if (!modal) return;
  modal.classList.add("hidden");
}

function parseMembersList(input) {
  return String(input || "")
    .split(/[,\n]/)
    .map((item) => item.trim())
    .filter(Boolean);
}

async function submitCreateChat() {
  if (!state.session) return;
  const name = $("createChatName").value.trim();
  if (!name) {
    toast("\u0412\u0432\u0435\u0434\u0438\u0442\u0435 \u043d\u0430\u0437\u0432\u0430\u043d\u0438\u0435");
    return;
  }

  const description = $("createChatDescription").value.trim();
  const link = $("createChatLink").value.trim();
  const members = parseMembersList($("createChatMembers").value);
  const type = state.pendingCreateType || "group";

  try {
    let data = null;
    if (type === "channel") {
      data = await apiFetch("/channels", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          token: state.session.token,
          owner: state.session.username,
          name,
        }),
      });
    } else {
      data = await apiFetch("/groups", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          token: state.session.token,
          owner: state.session.username,
          name,
          members,
        }),
      });
    }

    const chatId = data?.id || data?.chat_id || data?.chatId || data?.username;
    if (chatId) {
      saveChatMeta(chatId, {
        description,
        link,
        members,
        avatar: state.pendingCreateAvatar || "",
        owner: state.session.username,
      });
    }

    closeCreateChatModal();
    await loadChats({ silent: true });
    if (chatId) {
      selectChat({ chatId, username: chatId, name, type });
    }
  } catch (err) {
    toast(err.message || "\u041e\u0448\u0438\u0431\u043a\u0430 \u0437\u0430\u0433\u0440\u0443\u0437\u043a\u0438");
  }
}

function openInviteModal() {
  if (!state.activeTarget || (state.activeChatType !== "group" && state.activeChatType !== "channel")) {
    toast("\u0412\u044b\u0431\u0435\u0440\u0438\u0442\u0435 \u0433\u0440\u0443\u043f\u043f\u0443 \u0438\u043b\u0438 \u043a\u0430\u043d\u0430\u043b");
    return;
  }
  const modal = $("inviteModal");
  if (!modal) return;
  const title = $("inviteTitle");
  if (title) title.textContent = state.activeChatType === "channel" ? "\u0423\u0447\u0430\u0441\u0442\u043d\u0438\u043a\u0438 \u043a\u0430\u043d\u0430\u043b\u0430" : "\u0423\u0447\u0430\u0441\u0442\u043d\u0438\u043a\u0438 \u0433\u0440\u0443\u043f\u043f\u044b";
  $("inviteMembers").value = "";
  $("inviteAction").value = "add";
  state.inviteSelected = new Set();
  if ($("inviteSearchInput")) $("inviteSearchInput").value = "";
  modal.classList.remove("hidden");
  renderMembersList();
  renderInviteSelected();
  renderInviteSuggestions("");
}

function closeInviteModal() {
  const modal = $("inviteModal");
  if (!modal) return;
  modal.classList.add("hidden");
}

function renderMembersList() {
  const list = $("inviteMembersList");
  if (!list) return;
  list.innerHTML = "";
  const info = state.chatIndex?.[String(state.activeTarget)] || {};
  const meta = getChatMeta(state.activeTarget) || {};
  const members = meta.members || info.members || [];
  if (!members.length) {
    const empty = document.createElement("div");
    empty.className = "members-empty";
    empty.textContent = "\u041d\u0435\u0442 \u0434\u0430\u043d\u043d\u044b\u0445";
    list.appendChild(empty);
    return;
  }
  members.forEach((name) => {
    const item = document.createElement("div");
    item.className = "member-item";
    item.textContent = name;
    list.appendChild(item);
  });
}


function renderInviteSelected() {
  const wrap = $("inviteSelected");
  if (!wrap) return;
  wrap.innerHTML = "";
  const selected = Array.from(state.inviteSelected || []);
  if (!selected.length) return;
  selected.forEach((username) => {
    const chip = document.createElement("button");
    chip.className = "invite-chip";
    chip.type = "button";
    chip.textContent = `@${username}`;
    chip.addEventListener("click", () => {
      state.inviteSelected.delete(username);
      syncInviteMembersInput();
      renderInviteSelected();
      renderInviteSuggestions($("inviteSearchInput")?.value || "");
    });
    wrap.appendChild(chip);
  });
}

function getInviteCandidates(filter = "") {
  const query = String(filter || "").trim().toLowerCase();
  const action = $("inviteAction")?.value || "add";
  const members = new Set((state.chatIndex?.[String(state.activeTarget)]?.members || []));
  const list = (state.chatList || [])
    .filter((u) => (u.type || "user") === "user")
    .map((u) => {
      const username = u.username || u.chatId || "";
      const cached = state.userInfoCache[username];
      const name = u.name || cached?.name || username;
      return { username, name };
    })
    .filter((u) => u.username && u.username !== state.session?.username)
    .filter((u) => (action === "remove" ? members.has(u.username) : !members.has(u.username)));
  if (!query) return list;
  return list.filter((u) => u.username.toLowerCase().includes(query) || u.name.toLowerCase().includes(query));
}

function syncInviteMembersInput() {
  const field = $("inviteMembers");
  if (!field) return;
  const manual = parseMembersList(field.value);
  const merged = new Set([...(state.inviteSelected || []), ...manual]);
  field.value = Array.from(merged).join(", ");
}

function renderInviteSuggestions(filter = "") {
  const wrap = $("inviteSuggestions");
  if (!wrap) return;
  wrap.innerHTML = "";
  const candidates = getInviteCandidates(filter);
  if (!candidates.length) {
    const empty = document.createElement("div");
    empty.className = "members-empty";
    empty.textContent = "Никого не найдено";
    wrap.appendChild(empty);
    return;
  }
  candidates.slice(0, 8).forEach((user) => {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "invite-suggestion";
    if (state.inviteSelected?.has(user.username)) btn.classList.add("selected");
    btn.innerHTML = `<span class="invite-name">${user.name}</span><span class="invite-username">@${user.username}</span>`;
    btn.addEventListener("click", () => {
      if (!state.inviteSelected) state.inviteSelected = new Set();
      if (state.inviteSelected.has(user.username)) {
        state.inviteSelected.delete(user.username);
      } else {
        state.inviteSelected.add(user.username);
      }
      syncInviteMembersInput();
      renderInviteSelected();
      renderInviteSuggestions($("inviteSearchInput")?.value || "");
    });
    wrap.appendChild(btn);
  });
}

async function submitInvite() {
  if (!state.session || !state.activeTarget) return;
  const action = $("inviteAction").value;
  const members = Array.from(new Set([
    ...parseMembersList($("inviteMembers").value),
    ...(state.inviteSelected ? Array.from(state.inviteSelected) : []),
  ]));
  if (!members.length) {
    toast("\u0414\u043e\u0431\u0430\u0432\u044c\u0442\u0435 \u0443\u0447\u0430\u0441\u0442\u043d\u0438\u043a\u043e\u0432");
    return;
  }

  const basePath = state.activeChatType === "channel"
    ? `/channels/${encodeURIComponent(state.activeTarget)}/members`
    : `/groups/${encodeURIComponent(state.activeTarget)}/members`;

  try {
    for (const member of members) {
      await apiFetch(basePath, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          token: state.session.token,
          operator: state.session.username,
          action,
          target: member,
        }),
      }, { silent: true });
    }

    const meta = getChatMeta(state.activeTarget) || {};
    const existing = Array.isArray(meta.members) ? [...meta.members] : [];
    if (action === "add") {
      members.forEach((m) => {
        if (!existing.includes(m)) existing.push(m);
      });
    } else {
      const removeSet = new Set(members);
      const next = existing.filter((m) => !removeSet.has(m));
      existing.length = 0;
      existing.push(...next);
    }
    saveChatMeta(state.activeTarget, { members: existing });
    renderMembersList();
    toast("\u0413\u043e\u0442\u043e\u0432\u043e");
  } catch (err) {
    toast(err.message || "\u041e\u0448\u0438\u0431\u043a\u0430 \u0437\u0430\u0433\u0440\u0443\u0437\u043a\u0438");
  }
}

function openLocationModal() {
  const modal = $("locationModal");
  if (!modal) return;
  $("locationLabel").value = "";
  $("locationLat").value = "";
  $("locationLon").value = "";
  modal.classList.remove("hidden");
}

function closeLocationModal() {
  const modal = $("locationModal");
  if (!modal) return;
  modal.classList.add("hidden");
}

function detectLocation() {
  if (!navigator.geolocation) {
    toast("\u0413\u0435\u043e\u043b\u043e\u043a\u0430\u0446\u0438\u044f \u043d\u0435 \u0434\u043e\u0441\u0442\u0443\u043f\u043d\u0430");
    return;
  }
  navigator.geolocation.getCurrentPosition(
    (pos) => {
      $("locationLat").value = pos.coords.latitude.toFixed(6);
      $("locationLon").value = pos.coords.longitude.toFixed(6);
    },
    () => toast("\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u043f\u043e\u043b\u0443\u0447\u0438\u0442\u044c \u0433\u0435\u043e\u043b\u043e\u043a\u0430\u0446\u0438\u044e"),
    { enableHighAccuracy: true, timeout: 8000 }
  );
}

function requestCurrentLocation() {
  detectLocation();
}

function submitLocation() {
  const lat = $("locationLat").value.trim();
  const lon = $("locationLon").value.trim();
  if (!lat || !lon) {
    toast("\u0423\u043a\u0430\u0436\u0438\u0442\u0435 \u043a\u043e\u043e\u0440\u0434\u0438\u043d\u0430\u0442\u044b");
    return;
  }
  const label = $("locationLabel").value.trim();
  const payload = { lat: Number(lat), lon: Number(lon), label };
  const input = $("messageInput");
  if (input) {
    input.value = `LOCATION:${JSON.stringify(payload)}`;
    closeLocationModal();
    sendMessage();
  }
}

function openContactModal() {
  const modal = $("contactModal");
  if (!modal) return;
  $("contactName").value = "";
  $("contactPhone").value = "";
  $("contactUsername").value = "";
  $("contactEmail").value = "";
  modal.classList.remove("hidden");
}

function closeContactModal() {
  const modal = $("contactModal");
  if (!modal) return;
  modal.classList.add("hidden");
}

function submitContact() {
  const name = $("contactName").value.trim();
  const phone = $("contactPhone").value.trim();
  const username = $("contactUsername").value.trim();
  const email = $("contactEmail").value.trim();
  if (!name && !phone && !username && !email) {
    toast("\u0412\u0432\u0435\u0434\u0438\u0442\u0435 \u0434\u0430\u043d\u043d\u044b\u0435 \u043a\u043e\u043d\u0442\u0430\u043a\u0442\u0430");
    return;
  }
  const payload = { name, phone, username, email };
  const input = $("messageInput");
  if (input) {
    input.value = `CONTACT:${JSON.stringify(payload)}`;
    closeContactModal();
    sendMessage();
  }
}

const PINNED_KEY = "niosmess_pinned_messages";

function getPinnedMap() {
  if (!state.pinnedMessages) {
    try {
      state.pinnedMessages = JSON.parse(localStorage.getItem(PINNED_KEY) || "{}");
    } catch {
      state.pinnedMessages = {};
    }
  }
  return state.pinnedMessages;
}

function savePinnedMap(map) {
  state.pinnedMessages = map;
  try {
    localStorage.setItem(PINNED_KEY, JSON.stringify(map));
  } catch { }
}

function getPinnedForChat(chatId) {
  const map = getPinnedMap();
  return map[chatId] || null;
}

function clearPinnedMessage(chatId) {
  const map = getPinnedMap();
  delete map[chatId];
  savePinnedMap(map);
}

function renderPinnedBar() {
  const bar = $("pinnedBar");
  const textEl = $("pinnedText");
  if (!bar || !textEl) return;
  if (!state.activeTarget) {
    bar.classList.add("hidden");
    return;
  }
  const pinned = getPinnedForChat(state.activeTarget);
  if (!pinned) {
    bar.classList.add("hidden");
    bar.dataset.msgId = "";
    textEl.textContent = "";
    return;
  }

  const msgId = String(pinned.id || pinned.temp_id || "");
  bar.dataset.msgId = msgId;
  const attachment = getAttachmentFromMessage(pinned);
  let preview = "";
  if (attachment?.url) {
    preview = attachment.name || attachment.url || "\u0424\u0430\u0439\u043b";
  } else {
    const raw = String(pinned.text || "");
    preview = deobfuscate(raw).replace(/\s+/g, " ").trim();
  }
  textEl.textContent = preview || "\u0421\u043e\u043e\u0431\u0449\u0435\u043d\u0438\u0435";
  bar.classList.remove("hidden");
}

function togglePinMessage() {
  if (!state.contextMenuTarget || !state.activeTarget) return;
  const msg = state.contextMenuTarget.data;
  const map = getPinnedMap();
  const msgId = String(msg.id || msg.temp_id || "");
  const current = map[state.activeTarget];
  if (current && String(current.id || current.temp_id || "") === msgId) {
    delete map[state.activeTarget];
    toast("\u0421\u043e\u043e\u0431\u0449\u0435\u043d\u0438\u0435 \u043e\u0442\u043a\u0440\u0435\u043f\u043b\u0435\u043d\u043e");
  } else {
    map[state.activeTarget] = msg;
    toast("\u0421\u043e\u043e\u0431\u0449\u0435\u043d\u0438\u0435 \u0437\u0430\u043a\u0440\u0435\u043f\u043b\u0435\u043d\u043e");
  }
  savePinnedMap(map);
  renderPinnedBar();
  renderMessages(state.messages, { keepScroll: true });
  hideContextMenu();
}

function scrollToMessageById(msgId) {
  if (!msgId) return;
  const el = document.querySelector(`[data-id="${msgId}"]`);
  if (!el) return;
  el.scrollIntoView({ behavior: "smooth", block: "center" });
  el.classList.add("message-highlight");
  setTimeout(() => el.classList.remove("message-highlight"), 1200);
}

function cancelScheduledMessage() {
  if (!Array.isArray(state.scheduled) || !state.activeTarget) return;
  const before = state.scheduled.length;
  state.scheduled = state.scheduled.filter((item) => item?.target !== state.activeTarget);
  persistScheduled();
  if (state.scheduled.length !== before) {
    toast("\u041e\u0442\u043c\u0435\u043d\u0435\u043d\u044b \u043e\u0442\u043b\u043e\u0436\u0435\u043d\u043d\u044b\u0435 \u0441\u043e\u043e\u0431\u0449\u0435\u043d\u0438\u044f");
  }
  if (state.scheduled.length === 0) stopScheduledTimer();
}

function persistScheduled() {
  try {
    localStorage.setItem("niosmess_scheduled", JSON.stringify(state.scheduled || []));
  } catch { }
}

function startScheduledTimer() {
  if (state.scheduledTimer) return;
  state.scheduledTimer = setInterval(processScheduledMessages, 10000);
  processScheduledMessages();
}

function stopScheduledTimer() {
  if (state.scheduledTimer) {
    clearInterval(state.scheduledTimer);
    state.scheduledTimer = null;
  }
}

async function sendScheduledItem(item) {
  if (!item || !state.session) return;
  const payload = {
    sender: state.session.username,
    receiver: item.target,
    text: obfuscate(item.text),
    token: state.session.token,
    reply_to: item.reply_to || null,
  };

  if (item.type === "group" || item.type === "channel") {
    await apiFetch(`/collective/${encodeURIComponent(item.target)}/send`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        token: state.session.token,
        sender: state.session.username,
        text: obfuscate(item.text),
        reply_to: item.reply_to || null,
      }),
    }, { silent: true });
    return;
  }

  await apiFetch("/send_message", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  }, { silent: true });
}

async function processScheduledMessages() {
  if (!Array.isArray(state.scheduled) || state.scheduled.length === 0) {
    stopScheduledTimer();
    return;
  }
  const now = Date.now();
  const pending = [];

  for (const item of state.scheduled) {
    if (!item || !item.time || item.time > now) {
      pending.push(item);
      continue;
    }
    try {
      await sendScheduledItem(item);
    } catch (err) {
      pending.push(item);
    }
  }

  state.scheduled = pending;
  persistScheduled();
  if (state.scheduled.length === 0) stopScheduledTimer();
}

async function fetchScheduledMessages() {
  if (!state.session?.token) return;
  try {
    const data = await apiFetch(
      `/scheduled_messages?token=${encodeURIComponent(state.session.token)}&username=${encodeURIComponent(state.session.username)}`,
      {},
      { silent: true }
    );
    if (Array.isArray(data)) {
      const mapped = data.map((item) => ({
        id: item.id || `sched_${Date.now()}_${Math.random()}`,
        target: item.target_chat || item.receiver,
        type: item.chat_type || "user",
        text: item.text || "",
        time: new Date(item.scheduled_at).getTime(),
        reply_to: item.reply_to || null,
        serverId: item.id,
      }));
      state.scheduled = mapped;
      persistScheduled();
      if (mapped.length > 0) {
        startScheduledTimer();
      }
    }
  } catch (err) {
    console.error("Failed to fetch scheduled messages:", err);
  }
}

async function cancelScheduledMessageServer(scheduleId) {
  if (!state.session?.token || !scheduleId) return;
  try {
    await apiFetch(`/scheduled_messages/${encodeURIComponent(scheduleId)}`, {
      method: "DELETE",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        token: state.session.token,
        username: state.session.username,
      }),
    }, { silent: true });
  } catch (err) {
    console.error("Failed to cancel scheduled message:", err);
  }
}

async function submitScheduleMessage() {
  if (!state.session || !state.activeTarget) return;
  const dateInput = $("scheduleDate");
  const textInput = $("scheduleText");
  const rawText = textInput?.value || "";
  const textValue = state.settings.trimSpaces === false ? rawText : rawText.replace(/\s+/g, " ").trim();
  if (!textValue) {
    toast("\u0412\u0432\u0435\u0434\u0438\u0442\u0435 \u0442\u0435\u043a\u0441\u0442");
    return;
  }
  const when = dateInput?.value ? new Date(dateInput.value).getTime() : 0;
  if (!when || Number.isNaN(when) || when < Date.now()) {
    toast("\u0412\u044b\u0431\u0435\u0440\u0438\u0442\u0435 \u043a\u043e\u0440\u0440\u0435\u043a\u0442\u043d\u043e\u0435 \u0432\u0440\u0435\u043c\u044f");
    return;
  }

  try {
    const payload = {
      token: state.session.token,
      sender: state.session.username,
      receiver: state.activeTarget,
      text: obfuscate(textValue),
      scheduled_at: new Date(when).toISOString(),
      reply_to: state.replyTo ? state.replyTo.id : null,
    };

    const data = await apiFetch("/scheduled_messages", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    }, { silent: true });

    const item = {
      id: data?.id || `sched_${Date.now()}_${Math.random()}`,
      target: state.activeTarget,
      type: state.activeChatType || "user",
      text: textValue,
      time: when,
      reply_to: state.replyTo ? state.replyTo.id : null,
      serverId: data?.id,
    };

    state.scheduled = Array.isArray(state.scheduled) ? state.scheduled : [];
    state.scheduled.push(item);
    persistScheduled();
    startScheduledTimer();
    closeScheduleModal();
    toast("\u0421\u043e\u043e\u0431\u0449\u0435\u043d\u0438\u0435 \u0437\u0430\u043f\u043b\u0430\u043d\u0438\u0440\u043e\u0432\u0430\u043d\u043e");
  } catch (err) {
    toast(err.message || "\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u0437\u0430\u043f\u043b\u0430\u043d\u0438\u0440\u043e\u0432\u0430\u0442\u044c \u0441\u043e\u043e\u0431\u0449\u0435\u043d\u0438\u0435");
  }
}

async function sendMessage() {
  const input = $("messageInput");
  const rawText = input.value;
  const textValue = state.settings.trimSpaces === false ? rawText : rawText.replace(/\s+/g, " ").trim();

  if (!textValue || !state.activeTarget || !state.session) return;

  if (state.activeTarget === FAVORITES_CHAT_ID) {
    try {
      await apiFetch("/send_chat", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          token: state.session.token,
          username: state.session.username,
          text: obfuscate(textValue.replace(/\s+/g, " ").trim()),
        }),
      }, { silent: true });
      input.value = "";
      autoResize(input);
      loadMessages({ silent: true });
    } catch (err) {
      toast(err.message || "\u041e\u0448\u0438\u0431\u043a\u0430 \u0437\u0430\u0433\u0440\u0443\u0437\u043a\u0438");
    } finally {
      input.focus();
    }
    return;
  }

  if (state.editingMessage) {
    await applyEditMessage(textValue);
    return;
  }

  input.value = "";
  autoResize(input);
  clearDraft();
  setTypingIndicator(false);

  const tempId = `temp_${Date.now()}_${Math.random()}`;
  const tempMsg = {
    temp_id: tempId,
    sender: state.session.username,
    receiver: state.activeTarget,
    text: textValue,
    reply_to: state.replyTo ? { ...state.replyTo } : null,
    temp: true,
  };

  state.messages.push(tempMsg);
  appendMessage(tempMsg);

  const payload = {
    sender: state.session.username,
    receiver: state.activeTarget,
    text: obfuscate(textValue.replace(/\s+/g, " ").trim()),
    token: state.session.token,
    reply_to: state.replyTo ? state.replyTo.id : null,
  };

  try {
    if (state.activeChatType === "group" || state.activeChatType === "channel") {
      await apiFetch(`/collective/${encodeURIComponent(state.activeTarget)}/send`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          token: state.session.token,
          sender: state.session.username,
          text: payload.text,
          reply_to: payload.reply_to || null,
        }),
      }, { silent: true });
    } else {
      await apiFetch("/send_message", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      }, { silent: true });
    }

    state.messages = state.messages.filter(m => m.temp_id !== tempId);

    const tempEl = document.querySelector(`[data-id="${tempId}"]`);
    if (tempEl) {
      tempEl.style.animation = "fadeOut 0.2s ease forwards";
      setTimeout(() => {
        tempEl.remove();
        loadMessages({ silent: true });
      }, 200);
    } else {
      loadMessages({ silent: true });
    }
    cancelReply();
  } catch (err) {
    state.messages = state.messages.filter(m => m.temp_id !== tempId);
    const tempEl = document.querySelector(`[data-id="${tempId}"]`);
    if (tempEl) tempEl.remove();
    toast("\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u043e\u0442\u043f\u0440\u0430\u0432\u0438\u0442\u044c");
  } finally {
    input.focus();
  }
}
async function applyEditMessage(newText) {
  const target = state.editingMessage;
  if (!target) return;

  const msgId = String(target.id || target.temp_id);
  state.messages = state.messages.map((m) => {
    if (String(m.id || m.temp_id) === msgId) {
      return { ...m, text: newText, edited: true, edited_at: Date.now() };
    }
    return m;
  });
  renderMessages(state.messages);

  try {
    await apiFetch("/edit_message", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        token: state.session?.token,
        username: state.session?.username,
        message_id: msgId,
        text: obfuscate(newText),
      }),
    }, { silent: true });
  } catch (err) {
    toast("\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u0441\u043e\u0445\u0440\u0430\u043d\u0438\u0442\u044c \u0438\u0437\u043c\u0435\u043d\u0435\u043d\u0438\u044f");
  }

  cancelEdit();
}

function formatSpeed(bytesPerSec) {
  const value = Number(bytesPerSec);
  if (!Number.isFinite(value) || value <= 0) return "";
  return `${formatBytes(value)}/s`;
}

function createUploadPlaceholder(file) {
  const tempId = `upload_${Date.now()}_${Math.random()}`;
  const tempMsg = {
    temp_id: tempId,
    sender: state.session.username,
    receiver: state.activeTarget,
    text: "",
    temp: true,
    uploading: true,
    upload: {
      name: file?.name || "Файл",
      loaded: 0,
      total: file?.size || 0,
      speed: 0,
    },
  };
  state.messages.push(tempMsg);
  appendMessage(tempMsg);
  return tempId;
}

function updateUploadPlaceholder(tempId, loaded, total, speed) {
  const msg = state.messages.find(m => String(m.temp_id) === String(tempId));
  if (msg) {
    msg.upload = {
      ...(msg.upload || {}),
      loaded,
      total,
      speed,
    };
  }

  const el = document.querySelector(`[data-id="${tempId}"]`);
  if (!el) return;
  const percent = total > 0 ? Math.min(100, Math.round((loaded / total) * 100)) : 0;
  const fill = el.querySelector(".upload-inline-fill");
  if (fill) fill.style.width = `${percent}%`;
  const percentEl = el.querySelector(".upload-inline-percent");
  if (percentEl) percentEl.textContent = `${percent}%`;
  const bytesEl = el.querySelector(".upload-inline-bytes");
  if (bytesEl) {
    const totalText = formatBytes(total) || "0 B";
    const loadedText = formatBytes(loaded) || "0 B";
    bytesEl.textContent = `${loadedText} / ${totalText}`;
  }
  const speedEl = el.querySelector(".upload-inline-speed");
  if (speedEl) speedEl.textContent = formatSpeed(speed);
}

function removeUploadPlaceholder(tempId) {
  state.messages = state.messages.filter(m => String(m.temp_id) !== String(tempId));
  const el = document.querySelector(`[data-id="${tempId}"]`);
  if (el) el.remove();
}

async function uploadFileHttp(file, tempId, startedAt, lastTimeRef, lastLoadedRef) {
  const form = new FormData();
  form.append("file", file);
  form.append("sender", state.session.username);
  form.append("receiver", state.activeTarget);
  form.append("token", state.session.token);
  if (state.replyTo?.id) {
    form.append("reply_to", String(state.replyTo.id));
  }
  if (Number.isFinite(state.messageTTL) && Number(state.messageTTL) > 0) {
    form.append("ttl_seconds", String(state.messageTTL));
  }

  const xhr = await new Promise((resolve, reject) => {
    const request = new XMLHttpRequest();
    request.open("POST", `${state.apiBase}/upload`);

    request.upload.onprogress = (event) => {
      if (!event.lengthComputable) return;
      const now = Date.now();
      const delta = (now - lastTimeRef.value) / 1000;
      const speed = delta > 0 ? (event.loaded - lastLoadedRef.value) / delta : 0;
      lastTimeRef.value = now;
      lastLoadedRef.value = event.loaded;
      updateUploadPlaceholder(tempId, event.loaded, event.total, speed);
    };

    request.onload = () => resolve(request);
    request.onerror = () => reject(new Error("Не удалось загрузить файл"));
    request.send(form);
  });

  if (xhr.status < 200 || xhr.status >= 300) {
    let data = {};
    try {
      data = JSON.parse(xhr.responseText || "{}");
    } catch { }
    throw new Error(data.detail || data.error || "Ошибка загрузки");
  }

  updateUploadPlaceholder(
    tempId,
    file.size,
    file.size,
    file.size / Math.max(1, (Date.now() - startedAt) / 1000)
  );
  toast("Файл отправлен ✓");
  setTimeout(() => {
    removeUploadPlaceholder(tempId);
    state.lastMsgId = -1;
    loadMessages({ silent: true });
  }, 500);
  cancelReply();
}

async function sendFileMessage(filename) {
  if (!filename || !state.session || !state.activeTarget) return;
  if (state.activeTarget === FAVORITES_CHAT_ID) return;

  const payload = {
    token: state.session.token,
    sender: state.session.username,
    text: `FILE:${filename}`,
    reply_to: state.replyTo ? state.replyTo.id : null,
  };
  if (Number.isFinite(state.messageTTL) && Number(state.messageTTL) > 0) {
    payload.ttl_seconds = Number(state.messageTTL);
  }

  if (state.activeChatType === "group" || state.activeChatType === "channel") {
    await apiFetch(`/collective/${encodeURIComponent(state.activeTarget)}/send`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    }, { silent: true });
    return;
  }

  await apiFetch("/send_message", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ ...payload, receiver: state.activeTarget }),
  }, { silent: true });
}

async function uploadFile(file) {
  if (!file || !state.activeTarget || !state.session) return;
  if (state.activeTarget === FAVORITES_CHAT_ID) {
    toast("Файлы в избранном не поддерживаются");
    return;
  }

  if (file.size > MAX_FILE_SIZE) {
    toast("Файл слишком большой (макс. 50MB)");
    return;
  }

  const tempId = createUploadPlaceholder(file);
  const startedAt = Date.now();
  const lastTimeRef = { value: startedAt };
  const lastLoadedRef = { value: 0 };
  let ws = null;

  try {
    if (wsFileDisabledUntil && Date.now() < wsFileDisabledUntil) {
      await uploadFileHttp(file, tempId, startedAt, lastTimeRef, lastLoadedRef);
      return;
    }

    try {
      ws = await openFileSocket();
    } catch (err) {
      if (isWsFailure(err)) {
        wsFileDisabledUntil = Date.now() + 60 * 1000;
        await uploadFileHttp(file, tempId, startedAt, lastTimeRef, lastLoadedRef);
        return;
      }
      throw err;
    }

    let serverFilename = "";
    let readyResolve = null;
    let readyReject = null;
    let savedResolve = null;
    let savedReject = null;
    const readyPromise = new Promise((resolve, reject) => {
      readyResolve = resolve;
      readyReject = reject;
    });
    const savedPromise = new Promise((resolve, reject) => {
      savedResolve = resolve;
      savedReject = reject;
    });

    const onError = () => {
      const err = new Error("WebSocket error");
      if (readyReject) readyReject(err);
      if (savedReject) savedReject(err);
    };

    const onClose = (event) => {
      const reason = event && event.code === 1008 ? "Неверный токен" : "WebSocket закрыт";
      const err = new Error(reason);
      if (readyReject) readyReject(err);
      if (savedReject) savedReject(err);
    };

    const onMessage = (event) => {
      let data = null;
      try {
        data = JSON.parse(event.data);
      } catch {
        return;
      }
      if (!data || typeof data.type !== "string") return;

      if (data.type === "file_ready") {
        serverFilename = data.filename || "";
        if (readyResolve) readyResolve(data);
        readyResolve = null;
        readyReject = null;
        return;
      }
      if (data.type === "file_saved") {
        if (savedResolve) savedResolve(data);
        savedResolve = null;
        savedReject = null;
        return;
      }
      if (data.type === "error") {
        const err = new Error(data.message || "Ошибка загрузки");
        if (readyReject) readyReject(err);
        if (savedReject) savedReject(err);
      }
    };

    ws.addEventListener("message", onMessage);
    ws.addEventListener("close", onClose);
    ws.addEventListener("error", onError);

    ws.send(JSON.stringify({ type: "file_start", filename: file.name }));
    const readyData = await readyPromise;
    if (readyData?.filename) serverFilename = readyData.filename;

    let offset = 0;
    while (offset < file.size) {
      const chunk = file.slice(offset, offset + FILE_CHUNK_SIZE);
      const base64 = await blobToBase64(chunk);
      ws.send(JSON.stringify({ type: "file_chunk", chunk: base64 }));

      offset += chunk.size;
      const now = Date.now();
      const delta = (now - lastTimeRef.value) / 1000;
      const speed = delta > 0 ? (offset - lastLoadedRef.value) / delta : 0;
      lastTimeRef.value = now;
      lastLoadedRef.value = offset;
      updateUploadPlaceholder(tempId, offset, file.size, speed);
    }

    ws.send(JSON.stringify({ type: "file_end" }));
    const savedData = await savedPromise;
    const finalFilename = savedData?.filename || serverFilename || file.name;

    updateUploadPlaceholder(
      tempId,
      file.size,
      file.size,
      file.size / Math.max(1, (Date.now() - startedAt) / 1000)
    );

    let alreadyExists = false;
    try {
      await loadMessages({ silent: true });
      alreadyExists = (state.messages || []).some((m) => {
        if (m.sender !== state.session.username) return false;
        const text = String(m.text || "");
        return text.includes(finalFilename);
      });
    } catch { }

    if (!alreadyExists) {
      await sendFileMessage(finalFilename);
    }

    toast("\u0424\u0430\u0439\u043b \u043e\u0442\u043f\u0440\u0430\u0432\u043b\u0435\u043d \u2713");
    setTimeout(() => {
      removeUploadPlaceholder(tempId);
      state.lastMsgId = -1;
      loadMessages({ silent: true });
    }, 500);
    cancelReply();
  } catch (err) {
    removeUploadPlaceholder(tempId);
    toast(err.message || "\u041e\u0448\u0438\u0431\u043a\u0430 \u0437\u0430\u0433\u0440\u0443\u0437\u043a\u0438");
  } finally {
    if (ws && (ws.readyState === WebSocket.OPEN || ws.readyState === WebSocket.CONNECTING)) {
      try { ws.close(); } catch { }
    }
  }
}
async function toggleVoiceRecording() {
  if (!state.activeTarget || !state.session) return;
  if (!navigator.mediaDevices?.getUserMedia) {
    toast("Запись голоса не поддерживается");
    return;
  }

  if (state.voiceRecorder?.recording) {
    state.voiceRecorder.recorder.stop();
    return;
  }

  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    const recorder = new MediaRecorder(stream);
    const chunks = [];

    recorder.ondataavailable = (e) => {
      if (e.data && e.data.size > 0) chunks.push(e.data);
    };

    recorder.onstop = async () => {
      const blob = new Blob(chunks, { type: recorder.mimeType || "audio/webm" });
      const file = new File([blob], `voice_${Date.now()}.webm`, { type: blob.type });
      $("recordingIndicator")?.classList.add("hidden");
      stream.getTracks().forEach((t) => t.stop());
      state.voiceRecorder = null;
      await uploadFile(file);
    };

    recorder.start();
    state.voiceRecorder = { recorder, recording: true };
    $("recordingIndicator")?.classList.remove("hidden");
  } catch (err) {
    toast("Не удалось начать запись");
  }
}

// ─── Custom Voice Player ───────────────────────────────────────────────────
function createVoicePlayer(url, mime, knownDuration, waveformData) {
  const BAR_COUNT = 40;
  const NS = "http://www.w3.org/2000/svg";

  const wrap = document.createElement("div");
  wrap.className = "voice-player";

  // Play/pause button
  const playBtn = document.createElement("button");
  playBtn.className = "vp-play-btn";
  playBtn.type = "button";
  playBtn.innerHTML = `<svg viewBox="0 0 24 24" fill="currentColor" width="18" height="18"><path d="M8 5l11 7-11 7V5z"/></svg>`;

  // Waveform SVG
  const waveformWrap = document.createElement("div");
  waveformWrap.className = "vp-waveform";

  const svg = document.createElementNS(NS, "svg");
  svg.setAttribute("viewBox", `0 0 ${BAR_COUNT * 5} 32`);
  svg.setAttribute("preserveAspectRatio", "none");
  svg.style.width = "100%";
  svg.style.height = "32px";

  // Generate bar heights from waveform data or random
  let bars = [];
  if (Array.isArray(waveformData) && waveformData.length >= BAR_COUNT) {
    bars = waveformData.slice(0, BAR_COUNT).map(v => Math.max(0.12, Math.min(1, Math.abs(v))));
  } else if (Array.isArray(waveformData) && waveformData.length > 0) {
    // Interpolate
    for (let i = 0; i < BAR_COUNT; i++) {
      const idx = Math.floor(i * waveformData.length / BAR_COUNT);
      bars.push(Math.max(0.12, Math.min(1, Math.abs(waveformData[idx]))));
    }
  } else {
    // Pseudo-random seeded by url for stable looks
    let seed = url ? url.split("").reduce((a, c) => (a * 31 + c.charCodeAt(0)) | 0, 0) : 12345;
    for (let i = 0; i < BAR_COUNT; i++) {
      seed = (seed * 1664525 + 1013904223) & 0xffffffff;
      const t = (seed >>> 0) / 0xffffffff;
      bars.push(0.15 + t * 0.85);
    }
  }

  const barEls = bars.map((h, i) => {
    const rect = document.createElementNS(NS, "rect");
    const barH = Math.max(4, Math.round(h * 28));
    rect.setAttribute("x", String(i * 5));
    rect.setAttribute("y", String((32 - barH) / 2));
    rect.setAttribute("width", "3");
    rect.setAttribute("height", String(barH));
    rect.setAttribute("rx", "1.5");
    rect.className.baseVal = "vp-bar";
    svg.appendChild(rect);
    return rect;
  });

  waveformWrap.appendChild(svg);

  // Clickable progress on waveform
  let isDragging = false;
  waveformWrap.addEventListener("mousedown", (e) => {
    isDragging = true;
    seekAudio(e);
  });
  waveformWrap.addEventListener("mousemove", (e) => { if (isDragging) seekAudio(e); });
  window.addEventListener("mouseup", () => { isDragging = false; });

  function seekAudio(e) {
    const rect = waveformWrap.getBoundingClientRect();
    const pct = Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width));
    if (Number.isFinite(audio.duration) && audio.duration > 0) {
      audio.currentTime = pct * audio.duration;
      updateProgress(pct);
    }
  }

  function updateProgress(pct) {
    barEls.forEach((bar, i) => {
      if (i / BAR_COUNT <= pct) {
        bar.classList.add("vp-bar-played");
      } else {
        bar.classList.remove("vp-bar-played");
      }
    });
  }

  // Bottom row: time + speed
  const bottomRow = document.createElement("div");
  bottomRow.className = "vp-bottom";

  const timeEl = document.createElement("span");
  timeEl.className = "vp-time";
  timeEl.textContent = knownDuration ? formatDuration(knownDuration) : "0:00";

  const speeds = [1, 1.5, 2];
  let speedIdx = 0;
  const speedBtn = document.createElement("button");
  speedBtn.type = "button";
  speedBtn.className = "vp-speed-btn";
  speedBtn.textContent = "1×";
  speedBtn.addEventListener("click", () => {
    speedIdx = (speedIdx + 1) % speeds.length;
    audio.playbackRate = speeds[speedIdx];
    speedBtn.textContent = speeds[speedIdx] === 1 ? "1×" : speeds[speedIdx] + "×";
  });

  // Transcribe button (Web Speech API)
  const hasSpeech = typeof webkitSpeechRecognition !== "undefined" || typeof SpeechRecognition !== "undefined";
  let transcribeBtn = null;
  let transcriptEl = null;
  if (hasSpeech) {
    transcribeBtn = document.createElement("button");
    transcribeBtn.type = "button";
    transcribeBtn.className = "vp-transcribe-btn";
    transcribeBtn.title = "Расшифровать";
    transcribeBtn.textContent = "АА";

    transcriptEl = document.createElement("div");
    transcriptEl.className = "vp-transcript";
    transcriptEl.hidden = true;

    transcribeBtn.addEventListener("click", () => {
      const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
      if (!SR) return;
      const recog = new SR();
      recog.lang = "ru-RU";
      recog.interimResults = true;
      recog.continuous = false;
      transcribeBtn.textContent = "…";
      transcribeBtn.disabled = true;
      transcriptEl.hidden = false;
      transcriptEl.textContent = "Слушаю…";
      audio.play().catch(() => { });
      recog.start();
      recog.onresult = (ev) => {
        const text = Array.from(ev.results).map(r => r[0].transcript).join(" ");
        transcriptEl.textContent = text;
      };
      recog.onend = () => {
        transcribeBtn.textContent = "АА";
        transcribeBtn.disabled = false;
        if (!transcriptEl.textContent || transcriptEl.textContent === "Слушаю…") {
          transcriptEl.textContent = "Не удалось распознать";
        }
      };
      recog.onerror = () => {
        transcribeBtn.textContent = "АА";
        transcribeBtn.disabled = false;
        transcriptEl.textContent = "Ошибка распознавания";
      };
    });
  }

  bottomRow.appendChild(timeEl);
  bottomRow.appendChild(speedBtn);
  if (transcribeBtn) bottomRow.appendChild(transcribeBtn);

  // Audio element
  const audio = document.createElement("audio");
  audio.preload = "metadata";
  const source = document.createElement("source");
  setMediaElementSource(audio, url, source);
  audio.onerror = () => {
    fetchMediaBlob(url).then(blob => { audio.src = URL.createObjectURL(blob); }).catch(() => { });
  };
  source.type = mime || "audio/webm";
  audio.appendChild(source);

  // Playback events
  playBtn.addEventListener("click", () => {
    if (audio.paused) { audio.play().catch(() => { }); }
    else { audio.pause(); }
  });

  audio.addEventListener("play", () => {
    playBtn.innerHTML = `<svg viewBox="0 0 24 24" fill="currentColor" width="18" height="18"><rect x="6" y="4" width="4" height="16" rx="1"/><rect x="14" y="4" width="4" height="16" rx="1"/></svg>`;
    animateBars(true);
  });
  audio.addEventListener("pause", () => {
    playBtn.innerHTML = `<svg viewBox="0 0 24 24" fill="currentColor" width="18" height="18"><path d="M8 5l11 7-11 7V5z"/></svg>`;
    animateBars(false);
  });
  audio.addEventListener("ended", () => {
    playBtn.innerHTML = `<svg viewBox="0 0 24 24" fill="currentColor" width="18" height="18"><path d="M8 5l11 7-11 7V5z"/></svg>`;
    animateBars(false);
    updateProgress(0);
    timeEl.textContent = knownDuration ? formatDuration(knownDuration) : "0:00";
  });
  audio.addEventListener("loadedmetadata", () => {
    if (!knownDuration) timeEl.textContent = formatDuration(audio.duration);
  });
  audio.addEventListener("timeupdate", () => {
    if (!Number.isFinite(audio.duration) || audio.duration === 0) return;
    const pct = audio.currentTime / audio.duration;
    updateProgress(pct);
    timeEl.textContent = formatDuration(audio.currentTime);
  });

  // Bar animation while playing
  let animFrame = null;
  function animateBars(active) {
    if (!active) { if (animFrame) cancelAnimationFrame(animFrame); animFrame = null; return; }
    function tick() {
      if (audio.paused) return;
      const pct = audio.duration > 0 ? audio.currentTime / audio.duration : 0;
      barEls.forEach((bar, i) => {
        const barPct = i / BAR_COUNT;
        if (barPct <= pct) {
          bar.classList.add("vp-bar-played");
        } else {
          bar.classList.remove("vp-bar-played");
          // Subtle pulse on the next bar
          if (barPct - pct < 0.03) {
            bar.style.opacity = "0.7";
          } else {
            bar.style.opacity = "";
          }
        }
      });
      animFrame = requestAnimationFrame(tick);
    }
    animFrame = requestAnimationFrame(tick);
  }

  wrap.appendChild(playBtn);
  wrap.appendChild(waveformWrap);
  const rightCol = document.createElement("div");
  rightCol.className = "vp-right";
  rightCol.appendChild(bottomRow);
  if (transcriptEl) rightCol.appendChild(transcriptEl);
  wrap.appendChild(rightCol);
  wrap.appendChild(audio);

  return wrap;
}

// ─── Video Note (Кружки) ────────────────────────────────────────────────────
async function toggleVideoNoteRecording() {
  if (!state.activeTarget || !state.session) return;
  if (!navigator.mediaDevices?.getUserMedia) {
    toast("Запись видео не поддерживается");
    return;
  }

  if (state.videoNoteRecorder?.recording) {
    state.videoNoteRecorder.recorder.stop();
    return;
  }

  const overlay = document.getElementById("videoNoteModal");
  const preview = document.getElementById("videoNotePreview");
  const stopBtn = document.getElementById("videoNoteStopBtn");
  const cancelBtn = document.getElementById("videoNoteCancelBtn");
  const timerEl = document.getElementById("videoNoteTimer");

  try {
    const stream = await navigator.mediaDevices.getUserMedia({
      video: { facingMode: "user", width: { ideal: 480 }, height: { ideal: 480 }, aspectRatio: 1 },
      audio: true
    });

    if (preview) {
      preview.srcObject = stream;
      preview.play().catch(() => { });
    }
    if (overlay) overlay.classList.remove("hidden");

    const recorder = new MediaRecorder(stream);
    const chunks = [];
    let seconds = 0;
    let timerInterval = null;

    timerInterval = setInterval(() => {
      seconds++;
      if (timerEl) timerEl.textContent = formatDuration(seconds);
      if (seconds >= 60) recorder.stop();
    }, 1000);

    recorder.ondataavailable = (e) => { if (e.data?.size > 0) chunks.push(e.data); };
    recorder.onstop = async () => {
      clearInterval(timerInterval);
      stream.getTracks().forEach(t => t.stop());
      if (preview) preview.srcObject = null;
      if (overlay) overlay.classList.add("hidden");
      state.videoNoteRecorder = null;
      if (chunks.length === 0) return;
      const blob = new Blob(chunks, { type: recorder.mimeType || "video/webm" });
      const file = new File([blob], `vidnote_${Date.now()}.webm`, { type: blob.type });
      await uploadFile(file, { is_video_note: true });
    };

    recorder.start(100);
    state.videoNoteRecorder = { recorder, recording: true, stream };

    if (stopBtn) {
      stopBtn.onclick = () => recorder.stop();
    }
    if (cancelBtn) {
      cancelBtn.onclick = () => {
        clearInterval(timerInterval);
        recorder.ondataavailable = null;
        recorder.onstop = () => {
          stream.getTracks().forEach(t => t.stop());
          if (preview) preview.srcObject = null;
          if (overlay) overlay.classList.add("hidden");
          state.videoNoteRecorder = null;
        };
        recorder.stop();
      };
    }
  } catch (err) {
    toast("Не удалось начать запись видео");
  }
}

if (Array.isArray(state.scheduled) && state.scheduled.length) {
  startScheduledTimer();
}

updateTtlIndicator();
let currentEmojiCategory = null;

function initRealtime() {
  if (!state.settings || state.settings.realtimeEnabled !== true) return;
  if (!state.session || state.wsDisabled) return;
  if (state.ws && (state.ws.readyState === WebSocket.OPEN || state.ws.readyState === WebSocket.CONNECTING)) {
    return;
  }

  const base = state.apiBase.replace(/^http/, "ws");
  const url = `${base}/ws?token=${encodeURIComponent(state.session.token)}&username=${encodeURIComponent(state.session.username)}`;

  try {
    const ws = new WebSocket(url);
    state.ws = ws;
    state.wsStatus = "connecting";

    ws.onopen = () => {
      state.wsStatus = "online";
      state.wsFailures = 0;
      state.wsRetry = 0;
      state.wsConnectedAt = Date.now();
    };

    ws.onmessage = (event) => {
      let data = null;
      try {
        data = JSON.parse(event.data);
      } catch {
        return;
      }
      if (!data) return;

      if (data.type === "message" || data.event === "message") {
        loadMessages({ silent: true });
        loadChats({ silent: true });
      }

      if (data.type === "read_receipt") {
        if (state.activeTarget === data.chat_id) {
          // Update message UI status
          document.querySelectorAll('.message-status-icon').forEach(icon => {
            icon.innerHTML = '&#10004;&#10004;'; // Read checkmark
            icon.classList.add('read');
          });
          // Also update chats list last message status if needed
          loadChats({ silent: true });
        }
      }

      if (data.type === "poll_update") {
        if (state.activeTarget && state.messages) {
          state.messages.forEach(msg => {
            if (msg.poll_id === data.poll_id) {
              msg.poll_counts = data.counts;
              msg.poll_total = data.total;
              const msgEl = document.querySelector(`[data-id="${msg.id}"]`);
              if (msgEl) renderPoll(msgEl.querySelector('.message-poll-wrapper'), msg);
            }
          });
        }
      }

      if (data.type === "profile_update") {
        const username = data.username;
        if (username) {
          // Invalidate cache
          delete state.userInfoCache[username];
          evictAvatarCache(username);
          // Refresh UI elements
          if (state.activeTarget === username) {
            ensureUserInfo(username);
            updateChatHeader();
          }
          loadChats({ silent: true });
        }
      }

      if (data.type === "typing") {
        const sender = data.sender || data.from || "";
        const receiver = data.receiver || data.to || "";
        if (sender === state.session?.username) return;
        if (receiver && receiver !== state.session?.username) return;
        if (state.activeTarget === sender) {
          if (data.typing === false) {
            setTypingIndicator(false);
            return;
          }
          setTypingIndicator(true);
          if (state.remoteTypingTimer) clearTimeout(state.remoteTypingTimer);
          state.remoteTypingTimer = setTimeout(() => {
            setTypingIndicator(false);
          }, 1500);
        }
      }
    };

    ws.onerror = () => {
      state.wsStatus = "error";
    };

    ws.onclose = () => {
      state.wsStatus = "offline";
      state.wsFailures += 1;
      if (state.wsFailures >= 3) {
        state.wsDisabled = true;
        return;
      }
      setTimeout(() => initRealtime(), Math.min(10000, 1500 + state.wsFailures * 1000));
    };
  } catch {
    state.wsStatus = "error";
  }
}

async function sendTypingEvent(isTyping) {
  if (!isTyping) return;
  if (!state.session || !state.activeTarget) return;
  if (state.activeChatType && state.activeChatType !== "user") return;
  try {
    const profile = JSON.parse(localStorage.getItem("niosmess_myprofile") || "{}");
    if (profile.showTyping === false) return;
  } catch { }

  if (!state.ws || state.ws.readyState !== WebSocket.OPEN) {
    if (state.settings?.realtimeEnabled === true) initRealtime();
    return;
  }

  try {
    state.ws.send(JSON.stringify({
      type: "typing",
      receiver: state.activeTarget,
    }));
  } catch { }
}

function startScheduledWorker() {
  startScheduledTimer();
}
function initEmojiPicker() {
  const picker = $("emojiPicker");

  const header = picker.querySelector(".emoji-header");
  header.innerHTML = `
    <input id="emojiSearch" type="text" placeholder="Поиск эмодзи..." />
    <div class="emoji-categories"></div>
  `;

  const categoriesDiv = header.querySelector(".emoji-categories");

  Object.keys(emojiCategories).forEach((categoryName, index) => {
    const tab = document.createElement("button");
    tab.className = "emoji-category-tab";
    tab.textContent = categoryName;
    tab.dataset.category = categoryName;

    if (index === 0) {
      tab.classList.add("active");
      currentEmojiCategory = categoryName;
    }

    tab.addEventListener("click", () => {
      document.querySelectorAll(".emoji-category-tab").forEach(t => t.classList.remove("active"));
      tab.classList.add("active");
      currentEmojiCategory = categoryName;
      renderEmojiCategory(categoryName);
      $("emojiSearch").value = "";
    });

    categoriesDiv.appendChild(tab);
  });

  renderEmojiCategory(Object.keys(emojiCategories)[0]);

  $("emojiSearch")?.addEventListener("input", (e) => {
    const query = e.target.value.toLowerCase().trim();

    if (!query) {
      renderEmojiCategory(currentEmojiCategory);
      return;
    }

    const results = [];
    Object.values(emojiCategories).forEach(category => {
      category.forEach(item => {
        if (item.keywords.some(kw => kw.includes(query))) {
          results.push(item.emoji);
        }
      });
    });

    const uniqueResults = [...new Set(results)];

    const grid = $("emojiGrid");
    grid.innerHTML = "";

    if (uniqueResults.length === 0) {
      grid.innerHTML = '<div style="grid-column: 1/-1; text-align: center; padding: 20px; color: var(--text-tertiary);">Ничего не найдено</div>';
      return;
    }

    uniqueResults.forEach(emoji => {
      const item = document.createElement("div");
      item.className = "emoji-item";
      item.textContent = emoji;
      item.addEventListener("click", () => {
        insertEmoji(emoji);
      });
      grid.appendChild(item);
    });
  });
}
function renderEmojiCategory(categoryName) {
  const grid = $("emojiGrid");
  grid.innerHTML = "";

  const category = emojiCategories[categoryName];

  if (!category) return;

  category.forEach(item => {
    const emojiEl = document.createElement("div");
    emojiEl.className = "emoji-item";
    emojiEl.textContent = item.emoji;
    emojiEl.title = item.keywords[0];
    emojiEl.addEventListener("click", () => {
      insertEmoji(item.emoji);
    });
    grid.appendChild(emojiEl);
  });
}
function toggleEmojiPicker() {
  if (!state.activeTarget) {
    toast("Сначала выберите чат");
    return;
  }

  const picker = $("emojiPicker");
  const isHidden = picker.classList.contains("hidden");

  picker.classList.toggle("hidden");

  if (isHidden) {
    $("emojiSearch").value = "";
    renderEmojiCategory(currentEmojiCategory || Object.keys(emojiCategories)[0]);
    setTimeout(() => $("emojiSearch").focus(), 100);
  }
}
function insertEmoji(emoji) {
  const input = $("messageInput");
  const pos = input.selectionStart;
  const text = input.value;

  input.value = text.substring(0, pos) + emoji + text.substring(pos);
  input.setSelectionRange(pos + emoji.length, pos + emoji.length);
  input.focus();

  saveDraft();
  autoResize(input);
}
function setReplyTo(messageData) {
  if (!messageData) return;
  state.replyTo = {
    id: messageData.id || messageData.temp_id || "",
    sender: messageData.sender,
    text: messageData.text || "",
  };

  let preview = document.querySelector(".reply-preview");
  if (!preview) {
    preview = document.createElement("div");
    preview.className = "reply-preview";
    const inputWrapper = document.querySelector(".message-input-wrapper");
    inputWrapper?.parentNode?.insertBefore(preview, inputWrapper);
  }

  const rawText = String(state.replyTo.text || "");
  const text = deobfuscate(rawText).replace(/\s+/g, " ").trim();

  preview.innerHTML = `
    <div class="reply-preview-content">
      <div class="reply-preview-title">&#1054;&#1090;&#1074;&#1077;&#1090; &#1085;&#1072; &#1089;&#1086;&#1086;&#1073;&#1097;&#1077;&#1085;&#1080;&#1077;:</div>
      <div class="reply-preview-text">${text || "..."}</div>
    </div>
    <button class="reply-preview-close" onclick="cancelReply()">×</button>
  `;
}
function cancelReply() {
  state.replyTo = null;
  const preview = document.querySelector(".reply-preview");
  if (preview) preview.remove();
}
function setEditingMessage(messageData) {
  if (!messageData) return;
  state.editingMessage = messageData;

  let preview = document.querySelector(".edit-preview");
  if (!preview) {
    preview = document.createElement("div");
    preview.className = "edit-preview";
    const inputWrapper = document.querySelector(".message-input-wrapper");
    inputWrapper?.parentNode?.insertBefore(preview, inputWrapper);
  }

  const rawText = String(messageData.text || "");
  const text = deobfuscate(rawText).replace(/\s+/g, " ").trim();
  preview.innerHTML = `
    <div class="edit-preview-content">
      <div class="edit-preview-title">&#1056;&#1077;&#1076;&#1072;&#1082;&#1090;&#1080;&#1088;&#1086;&#1074;&#1072;&#1085;&#1080;&#1077;</div>
      <div class="edit-preview-text">${text || "..."}</div>
    </div>
    <button class="edit-preview-close" onclick="cancelEdit()">×</button>
  `;

  const input = $("messageInput");
  input.value = text;
  autoResize(input);
  input.focus();
}
function cancelEdit() {
  state.editingMessage = null;
  const preview = document.querySelector(".edit-preview");
  if (preview) preview.remove();
}
function setTypingIndicator(active) {
  const subtitle = $("chatSubtitle");
  if (!subtitle) return;

  if (active) {
    if (state.typingBackup === null) {
      state.typingBackup = subtitle.textContent;
    }
    subtitle.textContent = "\u041f\u0435\u0447\u0430\u0442\u0430\u0435\u0442...";
    subtitle.classList.add("typing");
  } else {
    if (state.typingBackup !== null) {
      subtitle.textContent = state.typingBackup;
      state.typingBackup = null;
    }
    subtitle.classList.remove("typing");
  }
}
function showContextMenu(e, messageEl, messageData) {
  const menu = $("contextMenu");
  if (!menu) return;
  state.contextMenuTarget = { el: messageEl, data: messageData };

  menu.classList.remove("hidden");
  const padding = 8;
  const rect = menu.getBoundingClientRect();
  const maxX = window.innerWidth - rect.width - padding;
  const maxY = window.innerHeight - rect.height - padding;
  const x = Math.max(padding, Math.min(e.clientX, maxX));
  const y = Math.max(padding, Math.min(e.clientY, maxY));
  menu.style.left = `${x}px`;
  menu.style.top = `${y}px`;

  const msgId = String(messageData.id || messageData.temp_id);
  const isFav = state.favorites.has(msgId);
  $("ctxFavorite").querySelector("span").textContent = isFav ? "\u0423\u0431\u0440\u0430\u0442\u044c \u0438\u0437 \u0438\u0437\u0431\u0440\u0430\u043d\u043d\u043e\u0433\u043e" : "\u0418\u0437\u0431\u0440\u0430\u043d\u043d\u043e\u0435";

  const isMine = messageData.sender === state.session?.username;
  const isFile = !!getAttachmentFromMessage(messageData).url;

  $("ctxEdit")?.classList.toggle("hidden", !isMine || isFile || messageData.deleted);
  $("ctxDeleteAll")?.classList.toggle("hidden", !isMine);
  $("ctxReactions")?.classList.toggle("hidden", !!messageData.deleted);
}
function hideContextMenu() {
  $("contextMenu").classList.add("hidden");
  state.contextMenuTarget = null;
}
function copyMessage() {
  if (!state.contextMenuTarget) return;

  const text = state.contextMenuTarget.el.textContent;
  navigator.clipboard.writeText(text).then(() => {
    toast("Скопировано ✓");
  });

  hideContextMenu();
}
function toggleFavorite() {
  if (!state.contextMenuTarget) return;

  const msgId = String(state.contextMenuTarget.data.id || state.contextMenuTarget.data.temp_id);
  const data = { ...state.favoritesData };

  if (state.favorites.has(msgId)) {
    state.favorites.delete(msgId);
    state.contextMenuTarget.el.classList.remove("favorite");
    delete data[msgId];
    toast("Удалено из избранного");
  } else {
    state.favorites.add(msgId);
    state.contextMenuTarget.el.classList.add("favorite");
    data[msgId] = {
      message: state.contextMenuTarget.data,
      savedAt: Date.now(),
      chatWith: state.activeTarget || "",
    };
    toast("Добавлено в избранное ⭐");
  }

  localStorage.setItem("niosmess_favorites", JSON.stringify([...state.favorites]));
  saveFavoritesData(data);
  if (state.activeTarget === FAVORITES_CHAT_ID) {
    renderFavoritesMessages();
  }
  hideContextMenu();
}
function deleteMessageForMe() {
  if (!state.contextMenuTarget) return;
  const msgId = String(state.contextMenuTarget.data.id || state.contextMenuTarget.data.temp_id);

  state.contextMenuTarget.el.style.animation = "fadeOut 0.3s ease forwards";
  setTimeout(() => {
    state.contextMenuTarget.el.remove();
  }, 300);

  state.messages = state.messages.filter(m => String(m.id || m.temp_id) !== msgId);
  toast("\u0421\u043e\u043e\u0431\u0449\u0435\u043d\u0438\u0435 \u0443\u0434\u0430\u043b\u0435\u043d\u043e");
  hideContextMenu();
}
async function deleteMessageForAll() {
  if (!state.contextMenuTarget) return;
  const msgId = String(state.contextMenuTarget.data.id || state.contextMenuTarget.data.temp_id);

  state.messages = state.messages.map((m) => {
    if (String(m.id || m.temp_id) === msgId) {
      return { ...m, deleted: true };
    }
    return m;
  });
  renderMessages(state.messages);

  try {
    await apiFetch("/delete_message", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        token: state.session?.token,
        username: state.session?.username,
        message_id: msgId,
      }),
    }, { silent: true });
  } catch (err) {
    toast("\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u0443\u0434\u0430\u043b\u0438\u0442\u044c \u0443 \u0432\u0441\u0435\u0445");
  }

  hideContextMenu();
}
function applyFormatToSelection(format) {
  if (!state.contextMenuTarget) return;

  const messageEl = state.contextMenuTarget.el;
  const textEl = messageEl.querySelector("span");

  if (!textEl) return;

  const selection = window.getSelection();
  const selectedText = selection.toString();

  if (!selectedText) {
    toast("Выделите текст для форматирования");
    hideContextMenu();
    return;
  }

  let formatted = "";

  switch (format) {
    case "bold":
      formatted = `**${selectedText}**`;
      break;
    case "italic":
      formatted = `*${selectedText}*`;
      break;
    case "code":
      formatted = `\`${selectedText}\``;
      break;
  }

  const input = $("messageInput");
  const currentValue = input.value;
  input.value = currentValue ? `${currentValue} ${formatted}` : formatted;
  input.focus();
  saveDraft();
  autoResize(input);

  toast("Добавлено в поле ввода");
  hideContextMenu();
}
async function searchUsers() {
  if (!state.session) return;

  const q = $("searchInput").value.trim();
  state.chatSearchActive = !!q;

  $("clearSearch").classList.toggle("hidden", !q);

  if (!q) {
    await loadChats({ silent: true, force: true });
    return;
  }

  try {
    const data = await apiFetch(
      `/search_users?q=${encodeURIComponent(q)}&token=${encodeURIComponent(state.session.token)}&my_username=${encodeURIComponent(state.session.username)}`,
      {},
      { silent: true }
    );
    renderChatList(Array.isArray(data) ? data : []);
  } catch {
    renderChatList([]);
  }
}
async function ping() {
  if (!state.session) return;

  try {
    await apiFetch("/ping", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ username: state.session.username, token: state.session.token }),
    }, { silent: true });
  } catch { }
}
async function loadProfile() {
  if (!state.activeTarget || !state.session) return;

  try {
    const data = await apiFetch(
      `/get_user_info?username=${encodeURIComponent(state.activeTarget)}&token=${encodeURIComponent(state.session.token)}&my_username=${encodeURIComponent(state.session.username)}`,
      {},
      { silent: true }
    );

    const profileAvatar = $("profileAvatar");
    if (profileAvatar) {
      profileAvatar.textContent = (data.name ? deobfuscate(data.name) : "?")[0]?.toUpperCase() || "?";
    }
    const profileNameEl = $("profileName");
    const profileNameText = (data.name ? deobfuscate(data.name) : (data.username || "?"));
    if (profileNameEl) {
      const badge = typeof getBadgeData === "function" ? getBadgeData(data, data) : null;
      if (typeof renderNameWithBadge === "function") {
        renderNameWithBadge(profileNameEl, profileNameText, badge);
      } else {
        profileNameEl.textContent = profileNameText;
      }
    }
    $("profileUser").textContent = data.username ? `@${data.username}` : "";
    const aboutText = String(data.about || data.bio || "").trim();
    $("profileStatus").textContent = aboutText || "—";
    $("profileMail").textContent = data.email || "—";
    $("profileDate").textContent = data.regdate || "—";
    if (state.activeTarget && profileAvatar) {
      const initial = (data.name ? deobfuscate(data.name) : (data.username || "?"))[0]?.toUpperCase() || "?";
      applyUserAvatar(profileAvatar, state.activeTarget, initial);
    }
  } catch { }
}
function toggleProfile(force) {
  const panel = $("profilePanel");
  const mainView = $("appView");
  const show = typeof force === "boolean" ? force : !panel.classList.contains("show");

  panel.classList.toggle("show", show);

  if (show) {
    mainView.style.gridTemplateColumns = "420px 1fr 400px";
    loadProfile();
    if (state.profileTimer) clearInterval(state.profileTimer);
    state.profileTimer = setInterval(loadProfile, 3000);
  } else {
    mainView.style.gridTemplateColumns = "420px 1fr 0";
    if (state.profileTimer) clearInterval(state.profileTimer);
    state.profileTimer = null;
  }
}
function loadMyProfile() {
  const profile = JSON.parse(localStorage.getItem("niosmess_myprofile") || "{}");
  const username = state.session?.username || "user";

  const myProfileAvatar = $("myProfileAvatar");
  applyAvatar(myProfileAvatar, (profile.name || username)[0].toUpperCase());
  const initial = profile.name ? profile.name[0].toUpperCase() : username[0].toUpperCase();
  if (username) {
    applyUserAvatar(myProfileAvatar, username, initial);
  }
  const headerName = $("tgSettingsName");
  const headerMeta = $("tgSettingsMeta");
  if (headerName) {
    const cached = state.userInfoCache?.[username] || null;
    const badge = typeof getBadgeData === "function" ? getBadgeData(cached, cached) : null;
    if (typeof renderNameWithBadge === "function") {
      renderNameWithBadge(headerName, profile.name || username, badge);
    } else {
      headerName.textContent = profile.name || username;
    }
  }
  if (headerMeta) headerMeta.textContent = `@${username}`;
  $("myProfileName").value = profile.name || username;
  $("myProfileUsername").value = username;
  $("myProfileEmail").value = profile.email || "";
  $("myProfileBio").value = profile.bio || "";

  $("showOnlineStatus").checked = profile.showOnlineStatus !== false;
  $("showLastSeen").checked = profile.showLastSeen !== false;
  $("showTyping").checked = profile.showTyping !== false;

  loadMyProfileHeader();
}

async function loadMyProfileHeader() {
  if (!state.session?.username) return;
  const username = state.session.username;
  const profile = JSON.parse(localStorage.getItem("niosmess_myprofile") || "{}");
  const headerName = $("tgSettingsName");
  const headerMeta = $("tgSettingsMeta");
  let displayName = profile.name || username;
  let meta = `@${username}`;

  try {
    const data = await apiFetch(
      `/get_user_info?username=${encodeURIComponent(username)}&token=${encodeURIComponent(state.session.token)}&my_username=${encodeURIComponent(username)}`,
      {},
      { silent: true }
    );
    if (data?.name) displayName = deobfuscate(data.name);
    if (data?.regdate) meta = `@${username} · ${data.regdate}`;

    const nameInput = $("myProfileName");
    const emailInput = $("myProfileEmail");
    if (data?.name && nameInput && !nameInput.value.trim()) {
      nameInput.value = deobfuscate(data.name);
    }
    if (data?.email && emailInput && !emailInput.value.trim()) {
      emailInput.value = data.email;
    }
  } catch { }

  if (headerName) {
    const cached = state.userInfoCache?.[username] || null;
    const badge = typeof getBadgeData === "function" ? getBadgeData(cached, cached) : null;
    if (typeof renderNameWithBadge === "function") {
      renderNameWithBadge(headerName, displayName, badge);
    } else {
      headerName.textContent = displayName;
    }
  }
  if (headerMeta) headerMeta.textContent = meta;
}
async function saveMyProfile() {
  setButtonLoading("saveProfileBtn", true);

  const profile = {
    name: $("myProfileName").value.trim(),
    email: $("myProfileEmail").value.trim(),
    bio: $("myProfileBio").value.trim(),
    showOnlineStatus: $("showOnlineStatus").checked,
    showLastSeen: $("showLastSeen").checked,
    showTyping: $("showTyping").checked,
  };

  localStorage.setItem("niosmess_myprofile", JSON.stringify(profile));

  updateUserInfo();

  const username = state.session?.username;
  const token = state.session?.token;
  let serverError = null;

  if (username && token) {
    try {
      const aboutForm = new FormData();
      aboutForm.append("token", token);
      aboutForm.append("username", username);
      aboutForm.append("about", profile.bio || "");
      await apiFetch("/set_about", { method: "POST", body: aboutForm }, { silent: true });
    } catch (err) {
      serverError = err;
    }

    if (profile.name) {
      try {
        const nameForm = new FormData();
        nameForm.append("token", token);
        nameForm.append("username", username);
        nameForm.append("name", profile.name);
        await apiFetch("/profile/set_name", { method: "POST", body: nameForm }, { silent: true });
      } catch (err) {
        if (!serverError) serverError = err;
      }
    }

    state.userInfoCache[username] = {
      ...(state.userInfoCache?.[username] || {}),
      name: profile.name || username,
      about: profile.bio || "",
    };
    state.userInfoTimestamps[username] = Date.now();
    if (typeof saveUserInfoCache === "function") saveUserInfoCache();
  }

  setTimeout(() => {
    setButtonLoading("saveProfileBtn", false);
    if (serverError) {
      toast(serverError.message || "\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u0441\u043e\u0445\u0440\u0430\u043d\u0438\u0442\u044c \u043f\u0440\u043e\u0444\u0438\u043b\u044c");
      return;
    }
    toast("\u041d\u0430\u0441\u0442\u0440\u043e\u0439\u043a\u0438 \u0441\u043e\u0445\u0440\u0430\u043d\u0435\u043d\u044b \u2713");
    closeMyProfile();
  }, 500);
}
async function handleAvatarUpload(file) {
  if (!file) return;

  if (!file.type || !file.type.startsWith('image/')) {
    toast('Выберите изображение');
    return;
  }

  try {
    const avatarFilename = await uploadAvatar(file);

    const reader = new FileReader();
    reader.onload = () => {
      const dataUrl = String(reader.result);
      if (!dataUrl) return;

      localStorage.setItem("niosmess_avatar", dataUrl);

      if (typeof updateUserInfo === 'function') updateUserInfo();
      if (typeof loadMyProfile === 'function') loadMyProfile();

      if (state.session?.username) {
        avatarCache.clear(state.session.username);
      }

      toast(`✅ Аватарка: ${avatarFilename}`);
    };
    reader.readAsDataURL(file);
  } catch (err) {
    toast(err.message || 'Ошибка загрузки');
  }
}
function updateUserInfo() {
  const username = state.session?.username || "user";
  const profile = JSON.parse(localStorage.getItem("niosmess_myprofile") || "{}");
  const name = profile.name || username;
  const initial = name[0].toUpperCase();

  const menuName = $("menuName");
  const menuUsername = $("menuUsername");
  const menuAvatar = $("menuAvatar");

  if (menuName) {
    const cached = state.userInfoCache?.[username] || null;
    const badge = typeof getBadgeData === "function" ? getBadgeData(cached, cached) : null;
    if (typeof renderNameWithBadge === "function") {
      renderNameWithBadge(menuName, name, badge);
    } else {
      menuName.textContent = name;
    }
  }
  if (menuUsername) menuUsername.textContent = `@${username}`;
  if (menuAvatar) {
    applyAvatar(menuAvatar, initial);
    applyUserAvatar(menuAvatar, username, initial);
  }
}
function openMyProfile(tab = "account") {
  loadMyProfile();
  setView("myProfile");
  if (typeof selectSettingsTab === "function") {
    selectSettingsTab(tab);
  }
  closeSideMenu();
}
function closeMyProfile() {
  setView("app");
}
function openSideMenu() {
  const menu = $("sideMenu");
  menu.classList.remove("hidden");
  updateUserInfo();

  requestAnimationFrame(() => {
    requestAnimationFrame(() => {
      menu.classList.add("menu-open");
    });
  });
}
function closeSideMenu() {
  const menu = $("sideMenu");

  menu.classList.remove("menu-open");

  setTimeout(() => {
    menu.classList.add("hidden");
  }, 400);
}

function getMusicQueueFromMessages() {
  const list = Array.isArray(state.messages) ? state.messages : [];
  const tracks = [];
  list.forEach((m) => {
    const attachment = getAttachmentFromMessage(m);
    if (!attachment || attachment.type !== "audio" || attachment.isVoice || !attachment.url) return;
    const name = attachment.name || "track";
    const title = name.replace(/\.[^/.]+$/, "") || "\u0411\u0435\u0437 \u043d\u0430\u0437\u0432\u0430\u043d\u0438\u044f";
    tracks.push({
      id: String(m.id || m.temp_id || attachment.url),
      src: attachment.url,
      title,
      artist: m.sender || "NiosMess",
      cover: attachment.thumbUrl || "",
    });
  });
  return tracks;
}

function ensureMusicPlayer() {
  const audio = $("musicPlayerAudio");
  if (!audio) return null;
  if (!state.music) {
    state.music = { open: false, queue: [], index: -1, current: null, ready: false };
  }
  if (state.music.ready) return audio;

  state.music.ready = true;

  audio.addEventListener("timeupdate", () => updateMusicProgress());
  audio.addEventListener("loadedmetadata", () => updateMusicProgress(true));
  audio.addEventListener("play", () => setMusicPlayState(true));
  audio.addEventListener("pause", () => setMusicPlayState(false));
  audio.addEventListener("ended", () => playNextTrack());

  $("musicProgress")?.addEventListener("input", (e) => {
    if (!Number.isFinite(audio.duration) || audio.duration === 0) return;
    const value = Number(e.target.value) || 0;
    audio.currentTime = (value / 100) * audio.duration;
  });

  $("musicPlayBtn")?.addEventListener("click", toggleMusicPlayback);
  $("musicPrevBtn")?.addEventListener("click", () => playRelative(-1));
  $("musicNextBtn")?.addEventListener("click", () => playRelative(1));

  return audio;
}

function openMusicPlayer(track, queue, index) {
  const player = $("musicPlayer");
  if (!player) return;
  ensureMusicPlayer();
  player.classList.remove("hidden");
  state.music.open = true;

  if (!queue || !queue.length) {
    queue = getMusicQueueFromMessages();
  }

  if (track?.src) {
    const idx = Number.isFinite(index)
      ? index
      : (queue || []).findIndex((t) => t.id === track.id || t.src === track.src);
    if (queue && queue.length) {
      setMusicQueue(queue, idx >= 0 ? idx : 0);
    } else {
      setMusicQueue([track], 0);
    }
    setMusicTrack(track, { autoplay: true });
    return;
  }

  if (queue && queue.length) {
    const idx = Number.isFinite(index) ? index : queue.length - 1;
    setMusicQueue(queue, idx);
    setMusicTrack(queue[idx], { autoplay: false });
  }
}

function closeMusicPlayer() {
  const player = $("musicPlayer");
  if (!player) return;
  player.classList.add("hidden");
  if (!state.music) {
    state.music = { open: false, queue: [], index: -1, current: null, ready: false };
  } else {
    state.music.open = false;
  }
}

function setMusicQueue(queue, index) {
  state.music.queue = Array.isArray(queue) ? queue : [];
  state.music.index = Number.isFinite(index) ? index : -1;
  updateMusicNav();
}

function setMusicTrack(track, options = {}) {
  const audio = ensureMusicPlayer();
  if (!audio || !track?.src) return;

  state.music.current = track;

  const title = track.title || "\u0411\u0435\u0437 \u043d\u0430\u0437\u0432\u0430\u043d\u0438\u044f";
  const artist = track.artist || "NiosMess";

  const titleEl = $("musicTitle");
  const artistEl = $("musicArtist");
  if (titleEl) titleEl.textContent = title;
  if (artistEl) artistEl.textContent = artist;

  const cover = $("musicCover");
  if (cover) {
    if (track.cover) {
      cover.style.backgroundImage = `url(${track.cover})`;
      cover.style.backgroundSize = "cover";
      cover.style.backgroundPosition = "center";
    } else {
      cover.style.backgroundImage = "";
    }
  }

  audio.src = track.src;
  audio.load();

  if (options.autoplay) {
    audio.play().catch(() => { });
  } else {
    setMusicPlayState(false);
  }

  updateMusicProgress(true);
}

function toggleMusicPlayback() {
  const audio = ensureMusicPlayer();
  if (!audio) return;
  if (audio.paused) {
    audio.play().catch(() => { });
  } else {
    audio.pause();
  }
}

function setMusicPlayState(isPlaying) {
  const btn = $("musicPlayBtn");
  if (!btn) return;
  btn.innerHTML = isPlaying
    ? '<svg width="22" height="22" viewBox="0 0 24 24" fill="none"><path d="M8 5h3v14H8zM13 5h3v14h-3z" fill="currentColor"/></svg>'
    : '<svg width="22" height="22" viewBox="0 0 24 24" fill="none"><path d="M8 5l11 7-11 7V5z" fill="currentColor"/></svg>';
}

function updateMusicProgress(forceDuration = false) {
  const audio = $("musicPlayerAudio");
  if (!audio) return;

  const current = $("musicCurrent");
  const duration = $("musicDuration");
  const progress = $("musicProgress");

  if (current) current.textContent = formatDuration(audio.currentTime || 0);

  if (duration && (forceDuration || duration.textContent === "0:00")) {
    duration.textContent = formatDuration(audio.duration || 0);
  }

  if (progress && Number.isFinite(audio.duration) && audio.duration > 0) {
    progress.value = String((audio.currentTime / audio.duration) * 100);
  }
}

function updateMusicNav() {
  const prev = $("musicPrevBtn");
  const next = $("musicNextBtn");
  const hasQueue = Array.isArray(state.music.queue) && state.music.queue.length > 1;

  if (prev) prev.disabled = !hasQueue;
  if (next) next.disabled = !hasQueue;
}

function playRelative(step) {
  const queue = state.music.queue || [];
  if (queue.length < 2) return;
  const nextIndex = (state.music.index + step + queue.length) % queue.length;
  state.music.index = nextIndex;
  setMusicTrack(queue[nextIndex], { autoplay: true });
}

function playNextTrack() {
  playRelative(1);
}
