import { motion } from 'motion/react';
import { ArrowLeft, Phone, Video, MoreVertical, Send, Paperclip, Smile, Image, ThumbsUp, Heart, Laugh, Play, Pause, Reply, Forward } from 'lucide-react';
import { Screen } from '../../App';
import { useState } from 'react';
import { FoxBadge } from '../ui/FoxBadge';
import { MusicPlayer } from '../ui/MusicPlayer';

interface ChatScreenProps {
  chat: any;
  onNavigate: (screen: Screen, data?: any) => void;
}

const mockMessages = [
  {
    id: 1,
    sender: 'Алексей',
    senderId: 'user1',
    avatar: '👨‍💻',
    text: 'Привет! Как дела с новым проектом?',
    time: '10:20',
    isOwn: false,
    reactions: [{ emoji: '👍', count: 2 }],
    hasFoxBadge: true,
  },
  {
    id: 2,
    sender: 'Вы',
    senderId: 'me',
    text: 'Отлично! Уже закончил основные компоненты',
    time: '10:22',
    isOwn: true,
  },
  {
    id: 3,
    sender: 'Алексей',
    senderId: 'user1',
    avatar: '👨‍💻',
    text: 'Супер! Можешь показать превью?',
    time: '10:23',
    isOwn: false,
    replyTo: {
      sender: 'Вы',
      text: 'Отлично! Уже закончил основные компоненты'
    },
  },
  {
    id: 4,
    sender: 'Вы',
    senderId: 'me',
    type: 'image',
    imageUrl: 'https://images.unsplash.com/photo-1633356122544-f134324a6cee?w=400',
    text: 'Вот так выглядит новый дизайн',
    time: '10:25',
    isOwn: true,
    reactions: [{ emoji: '❤️', count: 3 }, { emoji: '🔥', count: 1 }],
  },
  {
    id: 5,
    sender: 'Мария',
    senderId: 'user2',
    avatar: '👩‍🎨',
    text: 'Вау, это выглядит потрясающе! 🎨',
    time: '10:27',
    isOwn: false,
    reactions: [{ emoji: '👍', count: 1 }],
  },
  {
    id: 6,
    type: 'poll',
    sender: 'Алексей',
    senderId: 'user1',
    avatar: '👨‍💻',
    question: 'Какую тему предпочитаете?',
    options: [
      { text: 'Тёмная', votes: 15, percentage: 60 },
      { text: 'Светлая', votes: 7, percentage: 28 },
      { text: 'Цветная', votes: 3, percentage: 12 },
    ],
    time: '10:30',
    isOwn: false,
  },
  {
    id: 7,
    type: 'audio',
    sender: 'Вы',
    senderId: 'me',
    duration: '3:45',
    time: '10:35',
    isOwn: true,
  },
];

export function ChatScreen({ chat, onNavigate }: ChatScreenProps) {
  const [message, setMessage] = useState('');
  const [showProfilePanel, setShowProfilePanel] = useState(false);

  return (
    <div className="w-full h-full flex flex-col md:flex-row" style={{ background: 'var(--nm-bg)' }}>
      {/* Chat area */}
      <div className="flex-1 flex flex-col">
        {/* Header */}
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
              className="w-10 h-10 rounded-full flex items-center justify-center text-xl cursor-pointer"
              style={{ background: 'var(--nm-surface-hover)' }}
              onClick={() => setShowProfilePanel(!showProfilePanel)}
            >
              {chat.avatar}
            </div>

            <div>
              <h2 className="font-bold" style={{ color: 'var(--nm-text)' }}>
                {chat.name}
              </h2>
              <p className="text-sm" style={{ color: 'var(--nm-text-secondary)' }}>
                Онлайн
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

        {/* Messages */}
        <div className="flex-1 overflow-y-auto p-4 space-y-4">
          {mockMessages.map((msg) => (
            <MessageBubble
              key={msg.id}
              message={msg}
              onNavigate={onNavigate}
            />
          ))}

          {/* Music Player Demo */}
          <MusicPlayer />
        </div>

        {/* Input */}
        <div
          className="p-4 border-t"
          style={{
            background: 'var(--nm-surface)',
            borderColor: 'var(--nm-border)'
          }}
        >
          <div className="flex items-end gap-2">
            <button
              className="p-2 rounded-xl transition-all duration-200 hover:scale-110 active:scale-95"
              style={{ background: 'var(--nm-surface-hover)', color: 'var(--nm-text)' }}
            >
              <Paperclip className="w-5 h-5" />
            </button>

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
              className="p-3 rounded-xl transition-all duration-200 hover:scale-110 active:scale-95"
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

      {/* Profile Panel (Desktop) */}
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
                className="w-24 h-24 rounded-full flex items-center justify-center text-5xl mb-4"
                style={{ background: 'var(--nm-surface-hover)' }}
              >
                {chat.avatar}
              </div>
              <div className="flex items-center gap-2 mb-2">
                <h3 className="text-xl font-bold" style={{ color: 'var(--nm-text)' }}>
                  {chat.name}
                </h3>
                {chat.type === 'user' && <FoxBadge />}
              </div>
              <p style={{ color: 'var(--nm-text-secondary)' }}>
                @username
              </p>
            </div>

            <div className="space-y-4">
              <div
                className="p-4 rounded-xl"
                style={{ background: 'var(--nm-bg)' }}
              >
                <p className="text-sm mb-1" style={{ color: 'var(--nm-text-secondary)' }}>
                  О себе
                </p>
                <p style={{ color: 'var(--nm-text)' }}>
                  Разработчик и дизайнер. Люблю создавать красивые интерфейсы.
                </p>
              </div>

              <button
                className="w-full p-3 rounded-xl text-left transition-colors duration-200"
                style={{
                  background: 'var(--nm-surface-hover)',
                  color: 'var(--nm-text)'
                }}
              >
                📷 Медиа-файлы
              </button>

              <button
                className="w-full p-3 rounded-xl text-left transition-colors duration-200"
                style={{
                  background: 'var(--nm-surface-hover)',
                  color: 'var(--nm-text)'
                }}
              >
                🔗 Общие ссылки
              </button>
            </div>
          </div>
        </motion.div>
      )}
    </div>
  );
}

function MessageBubble({ message, onNavigate }: { message: any; onNavigate: (screen: Screen, data?: any) => void }) {
  const [showActions, setShowActions] = useState(false);

  if (message.type === 'poll') {
    return (
      <div className={`flex ${message.isOwn ? 'justify-end' : 'justify-start'}`}>
        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          className="max-w-md"
        >
          <div className="flex items-center gap-2 mb-2">
            {!message.isOwn && (
              <>
                <span className="text-sm">{message.avatar}</span>
                <span className="text-sm font-medium flex items-center gap-1" style={{ color: 'var(--nm-text)' }}>
                  {message.sender}
                  {message.hasFoxBadge && <FoxBadge size="sm" />}
                </span>
              </>
            )}
          </div>
          <div
            className="p-5 rounded-2xl"
            style={{
              background: message.isOwn ? 'var(--nm-accent)' : 'var(--nm-surface)',
              border: message.isOwn ? 'none' : '1px solid var(--nm-border)'
            }}
          >
            <p className="font-medium mb-4" style={{ color: message.isOwn ? 'white' : 'var(--nm-text)' }}>
              {message.question}
            </p>
            <div className="space-y-2">
              {message.options.map((option: any, idx: number) => (
                <button
                  key={idx}
                  className="w-full"
                >
                  <div
                    className="relative p-3 rounded-xl overflow-hidden transition-all duration-200 hover:scale-[1.02]"
                    style={{
                      background: message.isOwn ? 'rgba(255,255,255,0.2)' : 'var(--nm-surface-hover)',
                      border: `1px solid ${message.isOwn ? 'rgba(255,255,255,0.3)' : 'var(--nm-border)'}`
                    }}
                  >
                    <div
                      className="absolute left-0 top-0 h-full transition-all duration-300"
                      style={{
                        width: `${option.percentage}%`,
                        background: message.isOwn ? 'rgba(255,255,255,0.3)' : 'var(--nm-accent)',
                        opacity: 0.2
                      }}
                    />
                    <div className="relative flex items-center justify-between">
                      <span style={{ color: message.isOwn ? 'white' : 'var(--nm-text)' }}>
                        {option.text}
                      </span>
                      <span className="font-medium" style={{ color: message.isOwn ? 'white' : 'var(--nm-accent)' }}>
                        {option.percentage}%
                      </span>
                    </div>
                  </div>
                </button>
              ))}
            </div>
          </div>
          <p className="text-xs mt-1" style={{ color: 'var(--nm-text-secondary)' }}>
            {message.time}
          </p>
        </motion.div>
      </div>
    );
  }

  if (message.type === 'audio') {
    return (
      <div className={`flex ${message.isOwn ? 'justify-end' : 'justify-start'}`}>
        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          onHoverStart={() => setShowActions(true)}
          onHoverEnd={() => setShowActions(false)}
          className="max-w-md group relative"
        >
          <div
            className="p-4 rounded-2xl flex items-center gap-3"
            style={{
              background: message.isOwn ? 'var(--nm-accent)' : 'var(--nm-surface)',
              border: message.isOwn ? 'none' : '1px solid var(--nm-border)'
            }}
          >
            <button
              className="w-10 h-10 rounded-full flex items-center justify-center transition-all duration-200 hover:scale-110"
              style={{
                background: message.isOwn ? 'rgba(255,255,255,0.2)' : 'var(--nm-accent)',
                color: message.isOwn ? 'white' : 'white'
              }}
            >
              <Play className="w-5 h-5" />
            </button>
            <div className="flex-1">
              <div
                className="h-1 rounded-full mb-2"
                style={{ background: message.isOwn ? 'rgba(255,255,255,0.3)' : 'var(--nm-border)' }}
              >
                <div
                  className="h-full rounded-full"
                  style={{
                    width: '40%',
                    background: message.isOwn ? 'white' : 'var(--nm-accent)'
                  }}
                />
              </div>
              <p className="text-xs" style={{ color: message.isOwn ? 'rgba(255,255,255,0.8)' : 'var(--nm-text-secondary)' }}>
                {message.duration}
              </p>
            </div>
          </div>
          <MessageActions show={showActions} isOwn={message.isOwn} onNavigate={onNavigate} message={message} />
          <p className="text-xs mt-1" style={{ color: 'var(--nm-text-secondary)' }}>
            {message.time}
          </p>
        </motion.div>
      </div>
    );
  }

  if (message.type === 'image') {
    return (
      <div className={`flex ${message.isOwn ? 'justify-end' : 'justify-start'}`}>
        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          onHoverStart={() => setShowActions(true)}
          onHoverEnd={() => setShowActions(false)}
          className="max-w-md group relative"
        >
          <div className="flex items-center gap-2 mb-2">
            {!message.isOwn && (
              <>
                <span className="text-sm">{message.avatar}</span>
                <span className="text-sm font-medium" style={{ color: 'var(--nm-text)' }}>
                  {message.sender}
                </span>
              </>
            )}
          </div>
          <div
            className="rounded-2xl overflow-hidden cursor-pointer"
            onClick={() => onNavigate('media-viewer', { type: 'image', url: message.imageUrl })}
          >
            <img
              src={message.imageUrl}
              alt="Изображение"
              className="w-full h-64 object-cover"
            />
            {message.text && (
              <div className="p-4" style={{ background: message.isOwn ? 'var(--nm-accent)' : 'var(--nm-surface)' }}>
                <p style={{ color: message.isOwn ? 'white' : 'var(--nm-text)' }}>
                  {message.text}
                </p>
              </div>
            )}
          </div>
          {message.reactions && (
            <Reactions reactions={message.reactions} />
          )}
          <MessageActions show={showActions} isOwn={message.isOwn} onNavigate={onNavigate} message={message} />
          <p className="text-xs mt-1" style={{ color: 'var(--nm-text-secondary)' }}>
            {message.time}
          </p>
        </motion.div>
      </div>
    );
  }

  return (
    <div className={`flex ${message.isOwn ? 'justify-end' : 'justify-start'}`}>
      <motion.div
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        onHoverStart={() => setShowActions(true)}
        onHoverEnd={() => setShowActions(false)}
        className="max-w-md group relative"
      >
        <div className="flex items-center gap-2 mb-2">
          {!message.isOwn && (
            <>
              <span className="text-sm">{message.avatar}</span>
              <span className="text-sm font-medium flex items-center gap-1" style={{ color: 'var(--nm-text)' }}>
                {message.sender}
                {message.hasFoxBadge && <FoxBadge size="sm" />}
              </span>
            </>
          )}
        </div>

        {message.replyTo && (
          <div
            className="mb-2 p-2 rounded-lg border-l-2"
            style={{
              background: message.isOwn ? 'rgba(0,0,0,0.2)' : 'var(--nm-surface-hover)',
              borderColor: 'var(--nm-accent)'
            }}
          >
            <p className="text-xs font-medium mb-1" style={{ color: 'var(--nm-accent)' }}>
              {message.replyTo.sender}
            </p>
            <p className="text-xs" style={{ color: message.isOwn ? 'rgba(255,255,255,0.7)' : 'var(--nm-text-secondary)' }}>
              {message.replyTo.text}
            </p>
          </div>
        )}

        <div
          className="px-4 py-3 rounded-2xl"
          style={{
            background: message.isOwn ? 'var(--nm-accent)' : 'var(--nm-surface)',
            color: message.isOwn ? 'white' : 'var(--nm-text)',
            border: message.isOwn ? 'none' : '1px solid var(--nm-border)',
            boxShadow: message.isOwn ? `0 4px 16px var(--nm-shadow)` : 'none'
          }}
        >
          <p>{message.text}</p>
        </div>

        {message.reactions && (
          <Reactions reactions={message.reactions} />
        )}

        <MessageActions show={showActions} isOwn={message.isOwn} onNavigate={onNavigate} message={message} />

        <p className="text-xs mt-1" style={{ color: 'var(--nm-text-secondary)' }}>
          {message.time}
        </p>
      </motion.div>
    </div>
  );
}

function Reactions({ reactions }: { reactions: any[] }) {
  return (
    <motion.div
      initial={{ scale: 0 }}
      animate={{ scale: 1 }}
      className="flex gap-1 mt-2"
    >
      {reactions.map((reaction, idx) => (
        <motion.button
          key={idx}
          whileHover={{ scale: 1.1 }}
          whileTap={{ scale: 0.95 }}
          className="px-2 py-1 rounded-full text-xs flex items-center gap-1 transition-all duration-200"
          style={{
            background: 'var(--nm-surface)',
            border: '1px solid var(--nm-border)'
          }}
        >
          <span>{reaction.emoji}</span>
          <span style={{ color: 'var(--nm-text)' }}>{reaction.count}</span>
        </motion.button>
      ))}
      <motion.button
        whileHover={{ scale: 1.1 }}
        whileTap={{ scale: 0.95 }}
        className="w-6 h-6 rounded-full flex items-center justify-center transition-all duration-200"
        style={{
          background: 'var(--nm-surface)',
          border: '1px solid var(--nm-border)',
          color: 'var(--nm-text-secondary)'
        }}
      >
        +
      </motion.button>
    </motion.div>
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
