/**
 * api.js — thin async wrapper around the Messenger REST API.
 * All methods return parsed JSON or throw { status, detail }.
 */
const BASE = '/api/v1';

async function _req(method, path, body, token, isForm = false) {
  const headers = {};
  if (token) headers['Authorization'] = `Bearer ${token}`;
  let bodyData;
  if (body && !isForm) { headers['Content-Type'] = 'application/json'; bodyData = JSON.stringify(body); }
  else if (isForm) { bodyData = body; }  // FormData

  const res = await fetch(BASE + path, { method, headers, body: bodyData });
  const ct = res.headers.get('content-type') || '';
  const data = ct.includes('json') ? await res.json() : await res.text();
  if (!res.ok) throw { status: res.status, detail: data?.detail || data };
  return data;
}

const API = {
  // Auth
  register: (b)          => _req('POST', '/auth/register', b),
  verifyEmail: (b)        => _req('POST', '/auth/verify-email', b),
  login: (b)              => _req('POST', '/auth/login', b),
  verify2fa: (b)          => _req('POST', '/auth/2fa/verify', b),
  logout: (t)             => _req('POST', '/auth/logout', null, t),
  resetPasswordReq: (b)   => _req('POST', '/auth/reset-password/request', b),
  resetPasswordConfirm:(b)=> _req('POST', '/auth/reset-password/confirm', b),

  // Profile
  me: (t)                 => _req('GET', '/profile/me/info', null, t),
  getProfile: (u, t)      => _req('GET', `/profile/${u}`, null, t),
  updateProfile: (b, t)   => _req('PATCH', '/profile/me/update', b, t),
  uploadAvatar: (fd, t)   => _req('POST', '/profile/me/avatar', fd, t, true),
  toggle2fa: (b, t)       => _req('POST', '/profile/me/2fa', b, t),
  listSessions: (t)        => _req('GET', '/profile/me/sessions', null, t),
  kickSession: (id, t)     => _req('DELETE', `/profile/me/sessions/${id}`, null, t),

  // Chats
  listChats: (t)           => _req('GET', '/chats/list', null, t),
  openDM: (username, t)    => _req('POST', `/chats/direct/${username}`, null, t),
  createGroup: (b, t)      => _req('POST', '/chats/create', b, t),
  getChat: (id, t)         => _req('GET', `/chats/${id}`, null, t),
  getMembers: (id, t)      => _req('GET', `/chats/${id}/members`, null, t),
  updateChat: (id, b, t)   => _req('PATCH', `/chats/${id}/update`, b, t),
  inviteUser: (id, uid, t) => _req('POST', `/chats/${id}/invite`, { user_id: uid }, t),
  banMember: (id, b, t)    => _req('POST', `/chats/${id}/ban`, b, t),
  muteMember: (id, b, t)   => _req('POST', `/chats/${id}/mute`, b, t),
  promote: (id, b, t)      => _req('POST', `/chats/${id}/promote`, b, t),
  leaveChat: (id, t)       => _req('POST', `/chats/${id}/leave`, null, t),
  markRead: (id, t)        => _req('POST', `/chats/${id}/read`, null, t),

  // Messages
  sendMessage: (chatId, b, t)   => _req('POST', `/messages/${chatId}/send`, b, t),
  history: (chatId, page, t)    => _req('GET', `/messages/${chatId}/history?page=${page}&page_size=50`, null, t),
  editMessage: (chatId, msgId, b, t) => _req('PATCH', `/messages/${chatId}/${msgId}`, b, t),
  deleteMessage: (chatId, msgId, t)  => _req('DELETE', `/messages/${chatId}/${msgId}`, null, t),
  react: (chatId, msgId, emoji, t)   => _req('POST', `/messages/${chatId}/${msgId}/react?emoji=${encodeURIComponent(emoji)}`, null, t),

  // Comments (channel posts)
  postComment: (channelId, postId, b, t) => _req('POST', `/messages/${channelId}/posts/${postId}/comment`, b, t),
  getComments: (channelId, postId, t)    => _req('GET', `/messages/${channelId}/posts/${postId}/comments`, null, t),

  // Upload
  initUpload: (fd, t)     => _req('POST', '/messages/upload/init', fd, t, true),
  uploadChunk: (fd, t)    => _req('POST', '/messages/upload/chunk', fd, t, true),

  // Calls
  initiateCall: (b, t)    => _req('POST', '/calls/initiate', b, t),
  answerCall: (b, t)      => _req('POST', '/calls/answer', b, t),
  endCall: (b, t)         => _req('POST', '/calls/end', b, t),

  // Search
  search: (q, t)          => _req('GET', `/search?q=${encodeURIComponent(q)}`, null, t),

  // Invite
  joinChat: (slug, t)     => _req('POST', `/join/${slug}`, null, t),
  inviteInfo: (slug)      => _req('GET', `/join/${slug}`),
};

window.API = API;
