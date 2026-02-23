import { motion } from 'motion/react';
import { ArrowLeft, Phone, Video, MoreVertical, Send, Paperclip, Smile, Reply, Forward } from 'lucide-react';
import { Screen } from '../../App';
import { useEffect, useMemo, useRef, useState } from 'react';
import { FoxBadge } from '../ui/FoxBadge';
import { Session } from '../../lib/session';
import {
  getCollectiveMessages,
  getFileUrl,
  getMessagesUser,
  getUploaderFileUrl,
  markCollectiveRead,
  markRead,
  sendCollectiveMessage,
  sendMessageUser,
  uploadAsset,
  uploadDirectFile
} from '../../lib/api';

interface ChatScreenProps {
  chat: any;
  onNavigate: (screen: Screen, data?: any) => void;
  session: Session | null;
}

function getFileKind(filename: string) {
  const lower = filename.toLowerCase();
  if (/(\.png|\.jpg|\.jpeg|\.gif|\.webp|\.bmp)$/.test(lower)) return 'image';
  if (/(\.mp4|\.webm|\.mov)$/.test(lower)) return 'video';
  if (/(\.mp3|\.wav|\.ogg|\.m4a)$/.test(lower)) return 'audio';
  return 'file';
}

export function ChatScreen({ chat, onNavigate, session }: ChatScreenProps) {
  const [message, setMessage] = useState('');
  const [showProfilePanel, setShowProfilePanel] = useState(false);
  const [messages, setMessages] = useState<any[]>([]);
  const fileInputRef = useRef<HTMLInputElement | null>(null);

  const canSend = Boolean(session && chat);
  const isCollective = chat?.type === 'group' || chat?.type === 'channel';

  const mapMessages = (data: any[]) => {
    return (data || []).map((msg: any) => {
      const text = msg.text || '';
      if (text.startsWith('FILE:')) {
        const filename = text.replace('FILE:', '').trim();
        const kind = getFileKind(filename);
        const fileUrl = isCollective
          ? getUploaderFileUrl(filename, session?.token, session?.username)
          : getFileUrl(filename, session?.token, session?.username);
        return {
          ...msg,
          type: kind,
          fileName: filename,
          fileUrl,
          text: msg.caption || ''
        };
      }
      return {
        ...msg,
        type: msg.type || 'text'
      };
    });
  };

  const loadMessages = async () => {
    if (!session || !chat) return;
    let data: any[] = [];
    if (isCollective) {
      data = await getCollectiveMessages({ chatId: chat.id, username: session.username, token: session.token, limit: 50 });
    } else {
      data = await getMessagesUser({ me: session.username, other: chat.id, token: session.token });
    }
    setMessages(mapMessages(data || []));
    try {
      if (isCollective) {
        await markCollectiveRead({ chatId: chat.id, username: session.username, token: session.token });
      } else {
        await markRead({ chatId: chat.id, username: session.username, token: session.token });
      }
    } catch {
      // ignore
    }
  };

  useEffect(() => {
    if (!session || !chat) return;
    let active = true;

    const load = async () => {
      try {
        if (!active) return;
        await loadMessages();
      } catch {
        if (!active) return;
        setMessages([]);
      }
    };

    load();
    return () => {
      active = false;
    };
  }, [session, chat]);

  const handleSend = async () => {
    if (!canSend || !message.trim()) return;
    const text = message.trim();
    setMessage('');
    try {
      if (isCollective) {
        await sendCollectiveMessage({ chatId: chat.id, sender: session!.username, text, token: session!.token });
      } else {
        await sendMessageUser({ sender: session!.username, receiver: chat.id, text, token: session!.token });
      }
      await loadMessages();
    } catch {
      // ignore for now
    }
  };

  const handleAttachClick = () => {
    fileInputRef.current?.click();
  };

  const handleFileChange = async (event: React.ChangeEvent<HTMLInputElement>) => {
    if (!event.target.files?.length || !session || !chat) return;
    const file = event.target.files[0];
    event.target.value = '';
    try {
      if (isCollective) {
        const upload = await uploadAsset({ username: session.username, token: session.token, file });
        if (upload?.filename) {
          await sendCollectiveMessage({
            chatId: chat.id,
            sender: session.username,
            text: `FILE:${upload.filename}`,
            token: session.token
          });
        }
      } else {
        await uploadDirectFile({
          sender: session.username,
          receiver: chat.id,
          token: session.token,
          file
        });
      }
      await loadMessages();
    } catch {
      // ignore
    }
  };

  const badgeTitle = chat?.badgeTitle || chat?.badge_title;
  const badgeText = chat?.badgeText || chat?.badge_text;
  const badgeIcon = chat?.badgeIcon || chat?.badge_icon || '🦊';

  return (
    <div className="w-full h-full flex flex-col md:flex-row" style={{ background: 'var(--nm-bg)' }}>
      <div className="flex-1 flex flex-col">
        <div
          className="px-4 py-3 flex items-center justify-between border-b"
          style={{
            background: 'var(--nm-surface)',
            borderColor: 'var(--nm-border)'
          }}
        >
          <div className="flex items-center gap-3">
            <button
              onClick={() => onNavigate('main')}
              className="p-2 rounded-xl transition-all duration-200 hover:scale-110 active:scale-95 md:hidden"
              style={{ background: 'var(--nm-surface-hover)' }}
            >
              <ArrowLeft className="w-5 h-5" style={{ color: 'var(--nm-text)' }} />
            </button>

            <div
              className="w-10 h-10 rounded-full flex items-center justify-center text-xl cursor-pointer overflow-hidden"
              style={{ background: 'var(--nm-surface-hover)' }}
              onClick={() => setShowProfilePanel(!showProfilePanel)}
            >
              {chat?.avatarUrl ? (
                <img src={chat.avatarUrl} alt={chat?.name} className="w-full h-full object-cover" />
              ) : (
                chat?.name?.charAt(0).toUpperCase()
              )}
            </div>

            <div>
              <div className="flex items-center gap-2">
                <h2 className="font-bold" style={{ color: 'var(--nm-text)' }}>
                  {chat?.name || 'Чат'}
                </h2>
                {(badgeTitle || badgeText) && (
                  <FoxBadge size="sm" title={badgeTitle || 'Бейдж'} text={badgeText || undefined} icon={badgeIcon} />
                )}
              </div>
              <p className="text-sm" style={{ color: 'var(--nm-text-secondary)' }}>
                {chat?.statusText || ''}
              </p>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <button
              className="p-2 rounded-xl transition-all duration-200 hover:scale-110 active:scale-95"
              style={{ background: 'var(--nm-surface-hover)', color: 'var(--nm-text)' }}
            >
              <Phone className="w-5 h-5" />
            </button>
            <button
              className="p-2 rounded-xl transition-all duration-200 hover:scale-110 active:scale-95"
              style={{ background: 'var(--nm-surface-hover)', color: 'var(--nm-text)' }}
            >
              <Video className="w-5 h-5" />
            </button>
            <button
              className="p-2 rounded-xl transition-all duration-200 hover:scale-110 active:scale-95"
              style={{ background: 'var(--nm-surface-hover)', color: 'var(--nm-text)' }}
            >
              <MoreVertical className="w-5 h-5" />
            </button>
          </div>
        </div>

        <div className="flex-1 overflow-y-auto p-4 space-y-4">
          {messages.map((msg: any) => (
            <MessageBubble key={msg.id || msg.time} message={msg} session={session} onNavigate={onNavigate} />
          ))}
        </div>

        <div
          className="p-4 border-t"
          style={{
            background: 'var(--nm-surface)',
            borderColor: 'var(--nm-border)'
          }}
        >
          <div className="flex items-end gap-2">
            <button
              onClick={handleAttachClick}
              className="p-2 rounded-xl transition-all duration-200 hover:scale-110 active:scale-95"
              style={{ background: 'var(--nm-surface-hover)', color: 'var(--nm-text)' }}
            >
              <Paperclip className="w-5 h-5" />
            </button>
            <input
              ref={fileInputRef}
              type="file"
              className="hidden"
              onChange={handleFileChange}
            />

            <div className="flex-1">
              <textarea
                value={message}
                onChange={(e) => setMessage(e.target.value)}
                placeholder="Напишите сообщение..."
                rows={1}
                className="w-full px-4 py-3 rounded-xl border resize-none outline-none transition-all duration-200 focus:border-[var(--nm-accent)]"
                style={{
                  background: 'var(--nm-bg)',
                  color: 'var(--nm-text)',
                  borderColor: 'var(--nm-border)'
                }}
              />
            </div>

            <button
              className="p-2 rounded-xl transition-all duration-200 hover:scale-110 active:scale-95"
              style={{ background: 'var(--nm-surface-hover)', color: 'var(--nm-text)' }}
            >
              <Smile className="w-5 h-5" />
            </button>

            <button
              onClick={handleSend}
              disabled={!canSend}
              className="p-3 rounded-xl transition-all duration-200 hover:scale-110 active:scale-95 disabled:opacity-60"
              style={{
                background: 'var(--nm-accent)',
                color: 'white',
                boxShadow: `0 4px 16px var(--nm-shadow)`
              }}
            >
              <Send className="w-5 h-5" />
            </button>
          </div>
        </div>
      </div>

      {showProfilePanel && (
        <motion.div
          initial={{ x: 300, opacity: 0 }}
          animate={{ x: 0, opacity: 1 }}
          exit={{ x: 300, opacity: 0 }}
          transition={{ duration: 0.3, ease: [0.22, 1, 0.36, 1] }}
          className="hidden md:block w-80 border-l"
          style={{
            background: 'var(--nm-surface)',
            borderColor: 'var(--nm-border)'
          }}
        >
          <div className="p-6">
            <div className="flex flex-col items-center text-center mb-6">
              <div
                className="w-24 h-24 rounded-full flex items-center justify-center text-5xl mb-4 overflow-hidden"
                style={{ background: 'var(--nm-surface-hover)' }}
              >
                {chat?.avatarUrl ? (
                  <img src={chat.avatarUrl} alt={chat?.name} className="w-full h-full object-cover" />
                ) : (
                  chat?.name?.charAt(0).toUpperCase()
                )}
              </div>
              <div className="flex items-center gap-2 mb-2">
                <h3 className="text-xl font-bold" style={{ color: 'var(--nm-text)' }}>
                  {chat?.name}
                </h3>
                {chat?.type === 'user' && (badgeTitle || badgeText) && (
                  <FoxBadge size="md" title={badgeTitle || 'Бейдж'} text={badgeText || undefined} icon={badgeIcon} />
                )}
              </div>
              {chat?.type === 'user' && (
                <p style={{ color: 'var(--nm-text-secondary)' }}>@{chat?.id}</p>
              )}
            </div>
          </div>
        </motion.div>
      )}
    </div>
  );
}

function MessageBubble({ message, session, onNavigate }: { message: any; session: Session | null; onNavigate: (screen: Screen, data?: any) => void }) {
  const [showActions, setShowActions] = useState(false);
  const isOwn = session?.username === message.sender;

  if (message.type === 'image') {
    return (
      <div className={`flex ${isOwn ? 'justify-end' : 'justify-start'}`}>
        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          onHoverStart={() => setShowActions(true)}
          onHoverEnd={() => setShowActions(false)}
          className="max-w-md group relative"
        >
          <div
            className="rounded-2xl overflow-hidden cursor-pointer"
            onClick={() => onNavigate('media-viewer', { type: 'image', url: message.fileUrl })}
          >
            <img src={message.fileUrl} alt="Изображение" className="w-full h-64 object-cover" />
          </div>
          <MessageActions show={showActions} isOwn={isOwn} onNavigate={onNavigate} message={message} />
        </motion.div>
      </div>
    );
  }

  if (message.type === 'audio') {
    return (
      <div className={`flex ${isOwn ? 'justify-end' : 'justify-start'}`}>
        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          onHoverStart={() => setShowActions(true)}
          onHoverEnd={() => setShowActions(false)}
          className="max-w-md group relative"
        >
          <div
            className="p-3 rounded-2xl"
            style={{
              background: isOwn ? 'var(--nm-accent)' : 'var(--nm-surface)',
              border: isOwn ? 'none' : '1px solid var(--nm-border)'
            }}
          >
            <audio controls src={message.fileUrl} className="w-64" />
          </div>
          <MessageActions show={showActions} isOwn={isOwn} onNavigate={onNavigate} message={message} />
        </motion.div>
      </div>
    );
  }

  if (message.type === 'video') {
    return (
      <div className={`flex ${isOwn ? 'justify-end' : 'justify-start'}`}>
        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          className="max-w-md"
        >
          <video src={message.fileUrl} controls className="rounded-2xl max-w-md" />
        </motion.div>
      </div>
    );
  }

  if (message.type === 'file') {
    return (
      <div className={`flex ${isOwn ? 'justify-end' : 'justify-start'}`}>
        <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} className="max-w-md">
          <a
            href={message.fileUrl}
            className="px-4 py-3 rounded-2xl inline-flex"
            style={{ background: 'var(--nm-surface)', border: '1px solid var(--nm-border)', color: 'var(--nm-text)' }}
          >
            {message.fileName || 'Файл'}
          </a>
        </motion.div>
      </div>
    );
  }

  return (
    <div className={`flex ${isOwn ? 'justify-end' : 'justify-start'}`}>
      <motion.div
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        onHoverStart={() => setShowActions(true)}
        onHoverEnd={() => setShowActions(false)}
        className="max-w-md group relative"
      >
        <div
          className="px-4 py-3 rounded-2xl"
          style={{
            background: isOwn ? 'var(--nm-accent)' : 'var(--nm-surface)',
            color: isOwn ? 'white' : 'var(--nm-text)',
            border: isOwn ? 'none' : '1px solid var(--nm-border)',
            boxShadow: isOwn ? `0 4px 16px var(--nm-shadow)` : 'none'
          }}
        >
          <p>{message.text}</p>
        </div>

        <MessageActions show={showActions} isOwn={isOwn} onNavigate={onNavigate} message={message} />
      </motion.div>
    </div>
  );
}

function MessageActions({ show, isOwn, onNavigate, message }: any) {
  if (!show) return null;

  return (
    <motion.div
      initial={{ opacity: 0, y: -10 }}
      animate={{ opacity: 1, y: 0 }}
      className={`absolute ${isOwn ? 'left-0' : 'right-0'} -top-8 flex gap-1`}
    >
      <button
        className="p-2 rounded-lg transition-all duration-200 hover:scale-110"
        style={{
          background: 'var(--nm-surface)',
          border: '1px solid var(--nm-border)',
          color: 'var(--nm-text)'
        }}
      >
        <Reply className="w-4 h-4" />
      </button>
      <button
        onClick={() => {
          // Forward message modal would open here
        }}
        className="p-2 rounded-lg transition-all duration-200 hover:scale-110"
        style={{
          background: 'var(--nm-surface)',
          border: '1px solid var(--nm-border)',
          color: 'var(--nm-text)'
        }}
      >
        <Forward className="w-4 h-4" />
      </button>
      <button
        className="p-2 rounded-lg transition-all duration-200 hover:scale-110"
        style={{
          background: 'var(--nm-surface)',
          border: '1px solid var(--nm-border)',
          color: 'var(--nm-text)'
        }}
      >
        <Smile className="w-4 h-4" />
      </button>
    </motion.div>
  );
}
