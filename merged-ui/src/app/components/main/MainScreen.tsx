import { motion } from 'motion/react';
import { Search, Plus, Settings, Hash, Users, Pin } from 'lucide-react';
import { Screen } from '../../App';
import { useEffect, useMemo, useState } from 'react';
import { Session } from '../../lib/session';
import { fetchAvatarUrl, getChats, getUserInfo } from '../../lib/api';
import { FoxBadge } from '../ui/FoxBadge';

interface MainScreenProps {
  onNavigate: (screen: Screen, data?: any) => void;
  session: Session | null;
}

type ChatItem = {
  id: string;
  name: string;
  type: 'user' | 'group' | 'channel';
  unread: number;
  pinned?: boolean;
  statusText?: string;
  avatarUrl?: string;
  badgeTitle?: string;
  badgeText?: string;
  badgeIcon?: string;
};

export function MainScreen({ onNavigate, session }: MainScreenProps) {
  const [selectedChatId, setSelectedChatId] = useState<string | null>(null);
  const [chats, setChats] = useState<ChatItem[]>([]);
  const [query, setQuery] = useState('');

  useEffect(() => {
    if (!session) return;
    let active = true;

    const load = async () => {
      try {
        const data = await getChats({ username: session.username, token: session.token });
        const raw = data?.chats ?? data ?? [];
        const mapped: ChatItem[] = raw
          .map((item: any) => {
            const chatId = String(item.chat_id ?? item.username ?? item.id ?? item.chatId ?? '');
            if (!chatId) return null;
            const type = item.type || (chatId.startsWith('group_') ? 'group' : chatId.startsWith('channel_') ? 'channel' : 'user');
            return {
              id: chatId,
              name: item.name || chatId,
              type,
              unread: Number(item.unread_count ?? 0) || 0,
              pinned: Boolean(item.pinned),
              statusText:
                type === 'user'
                  ? item?.isonline
                    ? 'в сети'
                    : item?.last_seen_text || 'не в сети'
                  : type === 'group'
                    ? 'Группа'
                    : 'Канал',
              badgeTitle: item?.badge_title,
              badgeText: item?.badge_text,
              badgeIcon: item?.badge_icon
            } as ChatItem;
          })
          .filter(Boolean) as ChatItem[];

        if (!active) return;
        setChats(mapped);

        const userChats = mapped.filter((c) => c.type === 'user');
        await Promise.all(
          userChats.map(async (chat) => {
            try {
              const info = await getUserInfo({ username: chat.id, myUsername: session.username, token: session.token });
              if (!active) return;
              setChats((prev) =>
                prev.map((c) =>
                  c.id === chat.id
                    ? {
                        ...c,
                        name: info?.name || c.name,
                        statusText: info?.isonline ? 'в сети' : info?.last_seen_text || 'не в сети',
                        avatarUrl: c.avatarUrl,
                        badgeTitle: info?.badge_title ?? c.badgeTitle,
                        badgeText: info?.badge_text ?? c.badgeText,
                        badgeIcon: info?.badge_icon ?? c.badgeIcon
                      }
                    : c
                )
              );
              const avatar = await fetchAvatarUrl(chat.id);
              if (!active) return;
              if (avatar) {
                setChats((prev) =>
                  prev.map((c) =>
                    c.id === chat.id
                      ? {
                          ...c,
                          avatarUrl: avatar
                        }
                      : c
                  )
                );
              }
            } catch {
              // ignore profile errors
            }
          })
        );
      } catch {
        // keep empty state
      }
    };

    load();

    return () => {
      active = false;
    };
  }, [session]);

  const filtered = useMemo(() => {
    if (!query) return chats;
    const q = query.toLowerCase();
    return chats.filter((c) => c.name.toLowerCase().includes(q) || c.id.toLowerCase().includes(q));
  }, [chats, query]);

  return (
    <div className="w-full h-full flex" style={{ background: 'var(--nm-bg)' }}>
      <div
        className="w-full md:w-96 flex flex-col border-r"
        style={{
          background: 'var(--nm-surface)',
          borderColor: 'var(--nm-border)'
        }}
      >
        <div className="p-4 border-b" style={{ borderColor: 'var(--nm-border)' }}>
          <div className="flex items-center justify-between mb-4">
            <h1 className="text-2xl font-bold" style={{ color: 'var(--nm-text)' }}>
              Чаты
            </h1>
            <div className="flex items-center gap-2">
              <button
                onClick={() => onNavigate('create-group')}
                className="p-2 rounded-xl transition-all duration-200 hover:scale-110 active:scale-95"
                style={{ background: 'var(--nm-accent)', color: 'white' }}
              >
                <Plus className="w-5 h-5" />
              </button>
              <button
                onClick={() => onNavigate('settings')}
                className="p-2 rounded-xl transition-all duration-200 hover:scale-110 active:scale-95"
                style={{ background: 'var(--nm-surface-hover)', color: 'var(--nm-text)' }}
              >
                <Settings className="w-5 h-5" />
              </button>
            </div>
          </div>

          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5" style={{ color: 'var(--nm-text-secondary)' }} />
            <input
              type="text"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Поиск чатов..."
              className="w-full pl-10 pr-4 py-2 rounded-xl border transition-all duration-200 outline-none focus:border-[var(--nm-accent)]"
              style={{
                background: 'var(--nm-bg)',
                color: 'var(--nm-text)',
                borderColor: 'var(--nm-border)'
              }}
            />
          </div>
        </div>

        <div className="flex-1 overflow-y-auto">
          {filtered.map((chat) => (
            <motion.button
              key={`${chat.type}:${chat.id}`}
              onClick={() => {
                setSelectedChatId(chat.id);
                onNavigate('chat', chat);
              }}
              whileHover={{ x: 4 }}
              whileTap={{ scale: 0.98 }}
              className="w-full p-4 flex items-center gap-3 border-b transition-colors duration-200"
              style={{
                background: selectedChatId === chat.id ? 'var(--nm-surface-hover)' : 'transparent',
                borderColor: 'var(--nm-border)'
              }}
            >
              <div
                className="w-12 h-12 rounded-full flex items-center justify-center text-xl flex-shrink-0 overflow-hidden"
                style={{ background: 'var(--nm-surface-hover)' }}
              >
                {chat.avatarUrl ? (
                  <img src={chat.avatarUrl} alt={chat.name} className="w-full h-full object-cover" />
                ) : (
                  chat.name.charAt(0).toUpperCase()
                )}
              </div>

              <div className="flex-1 min-w-0 text-left">
                <div className="flex items-center gap-2 mb-1">
                  {chat.pinned && <Pin className="w-3 h-3" style={{ color: 'var(--nm-accent)' }} />}
                  <h3 className="font-medium truncate" style={{ color: 'var(--nm-text)' }}>
                    {chat.name}
                  </h3>
                  {(chat.badgeTitle || chat.badgeText || chat.badgeIcon) && (
                    <FoxBadge
                      size="sm"
                      title={chat.badgeTitle || 'Бейдж'}
                      text={chat.badgeText || undefined}
                      icon={chat.badgeIcon || '🦊'}
                    />
                  )}
                  {chat.type === 'channel' && <Hash className="w-3 h-3" style={{ color: 'var(--nm-text-secondary)' }} />}
                  {chat.type === 'group' && <Users className="w-3 h-3" style={{ color: 'var(--nm-text-secondary)' }} />}
                </div>
                <p className="text-sm truncate" style={{ color: 'var(--nm-text-secondary)' }}>
                  {chat.statusText}
                </p>
              </div>

              <div className="flex flex-col items-end gap-1">
                {chat.unread > 0 && (
                  <div
                    className="px-2 py-0.5 rounded-full text-xs font-medium"
                    style={{
                      background: 'var(--nm-accent)',
                      color: 'white'
                    }}
                  >
                    {chat.unread}
                  </div>
                )}
              </div>
            </motion.button>
          ))}
        </div>
      </div>

      <div className="hidden md:flex flex-1 items-center justify-center">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.2 }}
          className="flex flex-col items-center text-center max-w-md px-8"
        >
          <div className="relative mb-6">
            <div className="text-8xl">🦊</div>
            <motion.div
              className="absolute inset-0 -z-10 blur-3xl"
              style={{ background: 'var(--nm-glow)' }}
              animate={{
                opacity: [0.2, 0.4, 0.2],
                scale: [1, 1.1, 1]
              }}
              transition={{
                duration: 3,
                repeat: Infinity,
                ease: 'easeInOut'
              }}
            />
          </div>
          <h2 className="text-2xl font-bold mb-2" style={{ color: 'var(--nm-text)' }}>
            Выберите чат
          </h2>
          <p style={{ color: 'var(--nm-text-secondary)' }}>
            Или создайте новый, чтобы начать общение
          </p>
        </motion.div>
      </div>
    </div>
  );
}
