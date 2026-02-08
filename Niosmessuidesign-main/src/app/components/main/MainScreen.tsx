import { motion } from 'motion/react';
import { Search, Plus, Settings, MessageCircle, Hash, Users, Pin, Clock } from 'lucide-react';
import { Screen } from '../../App';
import { useState } from 'react';

interface MainScreenProps {
  onNavigate: (screen: Screen, data?: any) => void;
}

const mockChats = [
  {
    id: 1,
    name: 'Команда разработки',
    type: 'group',
    avatar: '👥',
    lastMessage: 'Новая версия готова к релизу',
    time: '10:30',
    unread: 3,
    pinned: true,
  },
  {
    id: 2,
    name: 'Алексей Петров',
    type: 'user',
    avatar: '👨‍💻',
    lastMessage: 'Отлично, давай обсудим завтра',
    time: '09:15',
    unread: 0,
    pinned: false,
  },
  {
    id: 3,
    name: 'Дизайн & UI',
    type: 'channel',
    avatar: '🎨',
    lastMessage: 'Новые макеты готовы',
    time: 'Вчера',
    unread: 12,
    pinned: true,
  },
  {
    id: 4,
    name: 'Мария Иванова',
    type: 'user',
    avatar: '👩‍🎨',
    lastMessage: 'Спасибо за обратную связь!',
    time: 'Вчера',
    unread: 0,
    pinned: false,
  },
  {
    id: 5,
    name: 'Технические новости',
    type: 'channel',
    avatar: '📰',
    lastMessage: 'Новая статья о React 19',
    time: '2 дня назад',
    unread: 5,
    pinned: false,
  },
];

export function MainScreen({ onNavigate }: MainScreenProps) {
  const [selectedChatId, setSelectedChatId] = useState<number | null>(null);

  return (
    <div className="w-full h-full flex" style={{ background: 'var(--nm-bg)' }}>
      {/* Left sidebar - Chat list */}
      <div
        className="w-full md:w-96 flex flex-col border-r"
        style={{ 
          background: 'var(--nm-surface)',
          borderColor: 'var(--nm-border)'
        }}
      >
        {/* Header */}
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

          {/* Search */}
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5" style={{ color: 'var(--nm-text-secondary)' }} />
            <input
              type="text"
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

        {/* Chat list */}
        <div className="flex-1 overflow-y-auto">
          {mockChats.map((chat) => (
            <motion.button
              key={chat.id}
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
              {/* Avatar */}
              <div
                className="w-12 h-12 rounded-full flex items-center justify-center text-2xl flex-shrink-0"
                style={{ background: 'var(--nm-surface-hover)' }}
              >
                {chat.avatar}
              </div>

              {/* Chat info */}
              <div className="flex-1 min-w-0 text-left">
                <div className="flex items-center gap-2 mb-1">
                  {chat.pinned && <Pin className="w-3 h-3" style={{ color: 'var(--nm-accent)' }} />}
                  <h3 className="font-medium truncate" style={{ color: 'var(--nm-text)' }}>
                    {chat.name}
                  </h3>
                  {chat.type === 'channel' && <Hash className="w-3 h-3" style={{ color: 'var(--nm-text-secondary)' }} />}
                  {chat.type === 'group' && <Users className="w-3 h-3" style={{ color: 'var(--nm-text-secondary)' }} />}
                </div>
                <p className="text-sm truncate" style={{ color: 'var(--nm-text-secondary)' }}>
                  {chat.lastMessage}
                </p>
              </div>

              {/* Time and badge */}
              <div className="flex flex-col items-end gap-1">
                <span className="text-xs" style={{ color: 'var(--nm-text-secondary)' }}>
                  {chat.time}
                </span>
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

      {/* Empty state - Fox */}
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
                scale: [1, 1.1, 1],
              }}
              transition={{
                duration: 3,
                repeat: Infinity,
                ease: "easeInOut"
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
