const DEFAULT_API_BASE = 'https://web.sa2rn.fun';

export type ApiError = {
  status: number;
  detail?: string;
};

function getApiBase() {
  const env = import.meta.env.VITE_API_BASE as string | undefined;
  return env && env.length > 0 ? env : DEFAULT_API_BASE;
}

async function parseJsonSafe(res: Response) {
  try {
    return await res.json();
  } catch {
    return null;
  }
}

export async function apiFetch(path: string, options?: RequestInit) {
  const base = getApiBase();
  const res = await fetch(`${base}${path}`, options);
  if (!res.ok) {
    const data = await parseJsonSafe(res);
    const err: ApiError = {
      status: res.status,
      detail: data?.detail || data?.message || data?.error || undefined
    };
    throw err;
  }
  return res;
}

export async function login(payload: { username: string; password: string }) {
  const form = new FormData();
  form.append('username', payload.username);
  form.append('password', payload.password);
  const res = await apiFetch('/login', { method: 'POST', body: form });
  return res.json();
}

export async function register(payload: { email: string; password: string; username: string; name: string; code?: string }) {
  const res = await apiFetch('/register', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  });
  return res.json();
}

export async function checkSession(payload: { token: string; username: string }) {
  const res = await apiFetch('/check_session', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  });
  return res.json();
}

export async function getChats(payload: { username: string; token: string }) {
  const params = new URLSearchParams({ username: payload.username, token: payload.token, version: '1.0' });
  const res = await apiFetch(`/get_chats?${params.toString()}`);
  return res.json();
}

export async function getUserInfo(payload: { username: string; myUsername: string; token: string }) {
  const params = new URLSearchParams({
    username: payload.username,
    my_username: payload.myUsername,
    token: payload.token
  });
  const res = await apiFetch(`/get_user_info?${params.toString()}`);
  return res.json();
}

export async function getMessagesUser(payload: { me: string; other: string; token: string }) {
  const params = new URLSearchParams({ me: payload.me, other: payload.other, token: payload.token });
  const res = await apiFetch(`/get_messages?${params.toString()}`);
  return res.json();
}

export async function sendMessageUser(payload: { sender: string; receiver: string; text: string; token: string; reply_to?: number }) {
  const res = await apiFetch('/send_message', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  });
  return res.json();
}

export async function getCollectiveMessages(payload: { chatId: string; username: string; token: string; limit?: number }) {
  const params = new URLSearchParams({
    chat_id: payload.chatId,
    username: payload.username,
    token: payload.token,
    limit: String(payload.limit ?? 50)
  });
  const res = await apiFetch(`/collective/messages?${params.toString()}`);
  const data = await res.json();
  return data?.messages ?? [];
}

export async function sendCollectiveMessage(payload: { chatId: string; sender: string; text: string; token: string; reply_to?: number }) {
  const form = new FormData();
  form.append('chat_id', payload.chatId);
  form.append('sender', payload.sender);
  form.append('text', payload.text);
  form.append('token', payload.token);
  if (payload.reply_to != null) form.append('reply_to', String(payload.reply_to));
  const res = await apiFetch('/collective/send', { method: 'POST', body: form });
  return res.json();
}

export async function createGroup(payload: { token: string; owner: string; name: string; members?: string[] }) {
  const res = await apiFetch('/groups', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  });
  return res.json();
}

export async function createChannel(payload: { token: string; owner: string; name: string }) {
  const res = await apiFetch('/channels', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  });
  return res.json();
}

const avatarCache = new Map<string, string>();

export async function fetchAvatarUrl(username: string) {
  if (avatarCache.has(username)) return avatarCache.get(username)!;
  const form = new FormData();
  form.append('other', username);
  const res = await apiFetch('/get_av', { method: 'POST', body: form });
  const blob = await res.blob();
  const url = URL.createObjectURL(blob);
  avatarCache.set(username, url);
  return url;
}

export function getFileUrl(filename: string, token: string, username: string) {
  const base = getApiBase();
  const params = new URLSearchParams({ token, username });
  return `${base}/download/${filename}?${params.toString()}`;
}

export function getUploaderFileUrl(filename: string) {
  const base = getApiBase();
  return `${base}/uploader/download/${filename}`;
}

export async function markRead(payload: { chatId: string; username: string; token: string }) {
  const form = new FormData();
  form.append('chat_id', payload.chatId);
  form.append('username', payload.username);
  form.append('token', payload.token);
  const res = await apiFetch('/mark_read', { method: 'POST', body: form });
  return res.json();
}

export async function markCollectiveRead(payload: { chatId: string; username: string; token: string }) {
  const form = new FormData();
  form.append('chat_id', payload.chatId);
  form.append('username', payload.username);
  form.append('token', payload.token);
  const res = await apiFetch('/collective/mark_read', { method: 'POST', body: form });
  return res.json();
}

export async function uploadDirectFile(payload: {
  sender: string;
  receiver: string;
  token: string;
  file: File;
  reply_to?: number;
  ttl_seconds?: number;
}) {
  const form = new FormData();
  form.append('sender', payload.sender);
  form.append('receiver', payload.receiver);
  form.append('token', payload.token);
  form.append('file', payload.file);
  if (payload.reply_to != null) form.append('reply_to', String(payload.reply_to));
  if (payload.ttl_seconds != null) form.append('ttl_seconds', String(payload.ttl_seconds));
  const res = await apiFetch('/upload', { method: 'POST', body: form });
  return res.json();
}

export async function uploadAsset(payload: { username: string; token: string; file: File }) {
  const form = new FormData();
  form.append('username', payload.username);
  form.append('token', payload.token);
  form.append('file', payload.file);
  const res = await apiFetch('/uploader', { method: 'POST', body: form });
  return res.json();
}
