import { motion } from 'motion/react';
import { X, Users, Hash, Globe, Lock, Image } from 'lucide-react';
import { Screen } from '../../App';
import { useState } from 'react';

interface CreateGroupScreenProps {
  onNavigate: (screen: Screen) => void;
}

export function CreateGroupScreen({ onNavigate }: CreateGroupScreenProps) {
  const [groupType, setGroupType] = useState<'group' | 'channel'>('group');

  return (
    <div className="w-full h-full flex items-center justify-center p-4" style={{ background: 'rgba(10, 5, 20, 0.8)' }}>
      <motion.div
        initial={{ opacity: 0, scale: 0.9 }}
        animate={{ opacity: 1, scale: 1 }}
        exit={{ opacity: 0, scale: 0.9 }}
        transition={{ duration: 0.3, ease: [0.22, 1, 0.36, 1] }}
        className="w-full max-w-lg rounded-2xl overflow-hidden"
        style={{
          background: 'var(--nm-surface)',
          border: '1px solid var(--nm-border)',
          boxShadow: `0 24px 64px var(--nm-shadow)`
        }}
      >
        {/* Header */}
        <div className="p-6 border-b" style={{ borderColor: 'var(--nm-border)' }}>
          <div className="flex items-center justify-between">
            <h2 className="text-2xl font-bold" style={{ color: 'var(--nm-text)' }}>
              Создать {groupType === 'group' ? 'группу' : 'канал'}
            </h2>
            <button
              onClick={() => onNavigate('main')}
              className="p-2 rounded-xl transition-all duration-200 hover:scale-110 active:scale-95"
              style={{ background: 'var(--nm-surface-hover)', color: 'var(--nm-text)' }}
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>

        {/* Content */}
        <div className="p-6 space-y-6">
          {/* Type selector */}
          <div className="flex gap-2">
            <button
              onClick={() => setGroupType('group')}
              className="flex-1 p-4 rounded-xl transition-all duration-200 hover:scale-[1.02]"
              style={{
                background: groupType === 'group' ? 'var(--nm-accent)' : 'var(--nm-surface-hover)',
                color: groupType === 'group' ? 'white' : 'var(--nm-text)',
                border: groupType === 'group' ? 'none' : '1px solid var(--nm-border)'
              }}
            >
              <Users className="w-6 h-6 mx-auto mb-2" />
              <p className="font-medium">Группа</p>
              <p className="text-xs mt-1 opacity-80">Для общения команды</p>
            </button>

            <button
              onClick={() => setGroupType('channel')}
              className="flex-1 p-4 rounded-xl transition-all duration-200 hover:scale-[1.02]"
              style={{
                background: groupType === 'channel' ? 'var(--nm-accent)' : 'var(--nm-surface-hover)',
                color: groupType === 'channel' ? 'white' : 'var(--nm-text)',
                border: groupType === 'channel' ? 'none' : '1px solid var(--nm-border)'
              }}
            >
              <Hash className="w-6 h-6 mx-auto mb-2" />
              <p className="font-medium">Канал</p>
              <p className="text-xs mt-1 opacity-80">Для новостей</p>
            </button>
          </div>

          {/* Image upload */}
          <div>
            <label className="block text-sm font-medium mb-2" style={{ color: 'var(--nm-text)' }}>
              Изображение
            </label>
            <button
              className="w-full h-32 rounded-xl border-2 border-dashed transition-all duration-200 hover:scale-[1.02] flex flex-col items-center justify-center gap-2"
              style={{
                borderColor: 'var(--nm-border)',
                color: 'var(--nm-text-secondary)'
              }}
            >
              <Image className="w-8 h-8" />
              <span>Загрузить изображение</span>
            </button>
          </div>

          {/* Name */}
          <div>
            <label className="block text-sm font-medium mb-2" style={{ color: 'var(--nm-text)' }}>
              Название
            </label>
            <input
              type="text"
              placeholder={`Название ${groupType === 'group' ? 'группы' : 'канала'}`}
              className="w-full px-4 py-3 rounded-xl border outline-none transition-all duration-200 focus:border-[var(--nm-accent)]"
              style={{
                background: 'var(--nm-bg)',
                color: 'var(--nm-text)',
                borderColor: 'var(--nm-border)'
              }}
            />
          </div>

          {/* Description */}
          <div>
            <label className="block text-sm font-medium mb-2" style={{ color: 'var(--nm-text)' }}>
              Описание
            </label>
            <textarea
              placeholder="Опишите цель группы..."
              rows={3}
              className="w-full px-4 py-3 rounded-xl border outline-none transition-all duration-200 focus:border-[var(--nm-accent)] resize-none"
              style={{
                background: 'var(--nm-bg)',
                color: 'var(--nm-text)',
                borderColor: 'var(--nm-border)'
              }}
            />
          </div>

          {/* Privacy */}
          <div>
            <label className="block text-sm font-medium mb-2" style={{ color: 'var(--nm-text)' }}>
              Приватность
            </label>
            <div className="flex gap-2">
              <button
                className="flex-1 p-3 rounded-xl transition-all duration-200 hover:scale-[1.02] flex items-center gap-3"
                style={{
                  background: 'var(--nm-surface-hover)',
                  border: '1px solid var(--nm-accent)',
                  color: 'var(--nm-text)'
                }}
              >
                <Globe className="w-5 h-5" style={{ color: 'var(--nm-accent)' }} />
                <span>Публичная</span>
              </button>

              <button
                className="flex-1 p-3 rounded-xl transition-all duration-200 hover:scale-[1.02] flex items-center gap-3"
                style={{
                  background: 'var(--nm-surface-hover)',
                  border: '1px solid var(--nm-border)',
                  color: 'var(--nm-text)'
                }}
              >
                <Lock className="w-5 h-5" />
                <span>Приватная</span>
              </button>
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="p-6 border-t" style={{ borderColor: 'var(--nm-border)' }}>
          <div className="flex gap-3">
            <button
              onClick={() => onNavigate('main')}
              className="flex-1 px-6 py-3 rounded-xl transition-all duration-200 hover:scale-[1.02]"
              style={{
                background: 'var(--nm-surface-hover)',
                color: 'var(--nm-text)',
                border: '1px solid var(--nm-border)'
              }}
            >
              Отмена
            </button>

            <button
              onClick={() => onNavigate('main')}
              className="flex-1 px-6 py-3 rounded-xl transition-all duration-200 hover:scale-[1.02]"
              style={{
                background: 'var(--nm-accent)',
                color: 'white',
                boxShadow: `0 8px 32px var(--nm-shadow)`
              }}
            >
              Создать
            </button>
          </div>
        </div>
      </motion.div>
    </div>
  );
}
