import { motion } from 'motion/react';
import { Palette, MessageCircle, Settings, Sparkles, Users, Image, Music, Lock } from 'lucide-react';

interface Feature {
  icon: any;
  title: string;
  description: string;
  color: string;
}

const features: Feature[] = [
  {
    icon: Palette,
    title: '7 Premium Themes',
    description: 'Тёмная, Светлая, Бирюзовая, Зелёная, Розовая, Оранжевая, Фиолетовая',
    color: '#9b59f5'
  },
  {
    icon: MessageCircle,
    title: 'Rich Messaging',
    description: 'Текст, медиа, опросы, реакции, цитаты и пересылка сообщений',
    color: '#2dd4bf'
  },
  {
    icon: Music,
    title: 'Music Player',
    description: 'Встроенный музыкальный плеер с анимациями и свечением',
    color: '#f97316'
  },
  {
    icon: Sparkles,
    title: 'Fox Badge',
    description: 'Специальный бейдж для разработчиков и спонсоров',
    color: '#ec4899'
  },
  {
    icon: Users,
    title: 'Groups & Channels',
    description: 'Создание групп и каналов с управлением участниками',
    color: '#22c55e'
  },
  {
    icon: Settings,
    title: 'Advanced Settings',
    description: 'Полная настройка аккаунта, приватности и персонализации',
    color: '#a855f7'
  },
  {
    icon: Image,
    title: 'Media Viewer',
    description: 'Просмотр медиа с зумом, навигацией и скачиванием',
    color: '#f59e0b'
  },
  {
    icon: Lock,
    title: 'Security',
    description: 'Заморозка аккаунта, двухфакторная аутентификация',
    color: '#3b82f6'
  },
];

export function DemoShowcase() {
  return (
    <div className="min-h-screen p-8" style={{ background: 'var(--nm-bg)' }}>
      <div className="max-w-6xl mx-auto">
        {/* Header */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="text-center mb-16"
        >
          <div className="flex justify-center mb-6">
            <motion.div
              animate={{
                rotate: [0, 10, -10, 0],
                scale: [1, 1.1, 1],
              }}
              transition={{
                duration: 3,
                repeat: Infinity,
                ease: "easeInOut"
              }}
              className="text-8xl"
            >
              🦊
            </motion.div>
          </div>

          <h1 className="text-6xl font-bold mb-4" style={{ color: 'var(--nm-text)' }}>
            NiosMess
          </h1>
          <p className="text-2xl mb-2" style={{ color: 'var(--nm-accent)' }}>
            Premium UI Messenger
          </p>
          <p className="text-lg" style={{ color: 'var(--nm-text-secondary)' }}>
            Полноценный UI-набор для современного мессенджера
          </p>
        </motion.div>

        {/* Features Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-16">
          {features.map((feature, index) => {
            const Icon = feature.icon;
            return (
              <motion.div
                key={feature.title}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: index * 0.1 }}
                whileHover={{ y: -8, scale: 1.02 }}
                className="p-6 rounded-2xl"
                style={{
                  background: 'var(--nm-surface)',
                  border: '1px solid var(--nm-border)',
                  boxShadow: `0 8px 32px var(--nm-shadow)`
                }}
              >
                <div
                  className="w-12 h-12 rounded-xl flex items-center justify-center mb-4"
                  style={{ background: `${feature.color}22`, color: feature.color }}
                >
                  <Icon className="w-6 h-6" />
                </div>
                <h3 className="font-bold mb-2" style={{ color: 'var(--nm-text)' }}>
                  {feature.title}
                </h3>
                <p className="text-sm" style={{ color: 'var(--nm-text-secondary)' }}>
                  {feature.description}
                </p>
              </motion.div>
            );
          })}
        </div>

        {/* Stats */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.8 }}
          className="grid grid-cols-2 md:grid-cols-4 gap-6 mb-16"
        >
          {[
            { label: 'Screens', value: '10+' },
            { label: 'Components', value: '50+' },
            { label: 'Themes', value: '7' },
            { label: 'Animations', value: '∞' },
          ].map((stat) => (
            <div
              key={stat.label}
              className="p-6 rounded-2xl text-center"
              style={{
                background: 'var(--nm-surface)',
                border: '1px solid var(--nm-border)'
              }}
            >
              <p className="text-4xl font-bold mb-2" style={{ color: 'var(--nm-accent)' }}>
                {stat.value}
              </p>
              <p style={{ color: 'var(--nm-text-secondary)' }}>
                {stat.label}
              </p>
            </div>
          ))}
        </motion.div>

        {/* CTA */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 1 }}
          className="text-center"
        >
          <p className="text-lg mb-4" style={{ color: 'var(--nm-text-secondary)' }}>
            Нажмите на кнопку меню в правом верхнем углу для навигации
          </p>
          <div
            className="inline-flex items-center gap-2 px-6 py-3 rounded-xl"
            style={{
              background: 'var(--nm-surface)',
              border: '1px solid var(--nm-border)'
            }}
          >
            <span style={{ color: 'var(--nm-text)' }}>Кнопка меню</span>
            <span className="text-2xl">→</span>
            <div
              className="w-8 h-8 rounded-lg flex items-center justify-center"
              style={{ background: 'var(--nm-accent)' }}
            >
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2">
                <line x1="3" y1="12" x2="21" y2="12" />
                <line x1="3" y1="6" x2="21" y2="6" />
                <line x1="3" y1="18" x2="21" y2="18" />
              </svg>
            </div>
          </div>
        </motion.div>
      </div>
    </div>
  );
}
