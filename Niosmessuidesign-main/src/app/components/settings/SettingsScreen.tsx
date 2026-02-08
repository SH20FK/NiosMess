import { motion, AnimatePresence } from 'motion/react';
import { ArrowLeft, User, Palette, Bell, Lock, Settings as SettingsIcon, Download, ChevronLeft, ChevronRight } from 'lucide-react';
import { Screen } from '../../App';
import { useState, useRef, useEffect } from 'react';
import { useTheme } from '../ThemeProvider';

interface SettingsScreenProps {
  onNavigate: (screen: Screen) => void;
}

type Tab = 'account' | 'personalization' | 'notifications' | 'privacy' | 'advanced';

const tabs = [
  { id: 'account' as Tab, label: 'Аккаунт', icon: User },
  { id: 'personalization' as Tab, label: 'Персонализация', icon: Palette },
  { id: 'notifications' as Tab, label: 'Уведомления', icon: Bell },
  { id: 'privacy' as Tab, label: 'Конфиденциальность', icon: Lock },
  { id: 'advanced' as Tab, label: 'Дополнительно', icon: SettingsIcon },
];

const themes = [
  { id: 'dark', name: 'Тёмная', preview: '#9b59f5' },
  { id: 'light', name: 'Светлая', preview: '#9b59f5' },
  { id: 'teal', name: 'Бирюзовая', preview: '#2dd4bf' },
  { id: 'green', name: 'Зелёная', preview: '#22c55e' },
  { id: 'pink', name: 'Розовая', preview: '#ec4899' },
  { id: 'orange', name: 'Оранжевая', preview: '#f97316' },
  { id: 'purple', name: 'Фиолетовая', preview: '#a855f7' },
];

export function SettingsScreen({ onNavigate }: SettingsScreenProps) {
  const [activeTab, setActiveTab] = useState<Tab>('personalization');
  const [slideDirection, setSlideDirection] = useState<'left' | 'right'>('right');

  const handleTabChange = (newTab: Tab) => {
    const currentIndex = tabs.findIndex(t => t.id === activeTab);
    const newIndex = tabs.findIndex(t => t.id === newTab);
    setSlideDirection(newIndex > currentIndex ? 'right' : 'left');
    setActiveTab(newTab);
  };

  return (
    <div className="w-full h-full flex flex-col md:flex-row" style={{ background: 'var(--nm-bg)' }}>
      {/* Left sidebar - Tabs */}
      <div
        className="w-full md:w-64 border-r"
        style={{
          background: 'var(--nm-surface)',
          borderColor: 'var(--nm-border)'
        }}
      >
        {/* Header */}
        <div className="p-4 border-b" style={{ borderColor: 'var(--nm-border)' }}>
          <button
            onClick={() => onNavigate('main')}
            className="flex items-center gap-2 mb-4 transition-all duration-200 hover:gap-3"
            style={{ color: 'var(--nm-text-secondary)' }}
          >
            <ArrowLeft className="w-5 h-5" />
            <span>Назад</span>
          </button>
          <h2 className="text-2xl font-bold" style={{ color: 'var(--nm-text)' }}>
            Настройки
          </h2>
        </div>

        {/* Tabs */}
        <div className="p-2">
          {tabs.map((tab) => {
            const Icon = tab.icon;
            return (
              <motion.button
                key={tab.id}
                onClick={() => handleTabChange(tab.id)}
                whileHover={{ x: 4 }}
                whileTap={{ scale: 0.98 }}
                className="w-full flex items-center gap-3 px-4 py-3 rounded-xl mb-1 transition-all duration-200"
                style={{
                  background: activeTab === tab.id ? 'var(--nm-surface-hover)' : 'transparent',
                  color: activeTab === tab.id ? 'var(--nm-accent)' : 'var(--nm-text)'
                }}
              >
                <Icon className="w-5 h-5" />
                <span className="font-medium">{tab.label}</span>
              </motion.button>
            );
          })}
        </div>
      </div>

      {/* Right content */}
      <div className="flex-1 overflow-y-auto">
        <div className="max-w-3xl mx-auto p-6 md:p-8">
          <AnimatePresence mode="wait">
            <motion.div
              key={activeTab}
              initial={{ opacity: 0, x: slideDirection === 'right' ? 50 : -50 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: slideDirection === 'right' ? -50 : 50 }}
              transition={{ duration: 0.3, ease: [0.22, 1, 0.36, 1] }}
            >
              {activeTab === 'account' && <AccountTab />}
              {activeTab === 'personalization' && <PersonalizationTab />}
              {activeTab === 'notifications' && <NotificationsTab />}
              {activeTab === 'privacy' && <PrivacyTab />}
              {activeTab === 'advanced' && <AdvancedTab />}
            </motion.div>
          </AnimatePresence>
        </div>
      </div>
    </div>
  );
}

function AccountTab() {
  return (
    <div className="space-y-6">
      <div>
        <h3 className="text-2xl font-bold mb-2" style={{ color: 'var(--nm-text)' }}>
          Аккаунт
        </h3>
        <p style={{ color: 'var(--nm-text-secondary)' }}>
          Управление вашим профилем и данными
        </p>
      </div>

      {/* Profile card */}
      <div
        className="p-6 rounded-2xl"
        style={{
          background: 'var(--nm-surface)',
          border: '1px solid var(--nm-border)'
        }}
      >
        <div className="flex items-center gap-4 mb-6">
          <div
            className="w-20 h-20 rounded-full flex items-center justify-center text-4xl"
            style={{ background: 'var(--nm-surface-hover)' }}
          >
            🦊
          </div>
          <div className="flex-1">
            <h4 className="text-xl font-bold mb-1" style={{ color: 'var(--nm-text)' }}>
              Иван Петров
            </h4>
            <p style={{ color: 'var(--nm-text-secondary)' }}>
              @ivanpetrov
            </p>
          </div>
          <button
            className="px-4 py-2 rounded-xl transition-all duration-200 hover:scale-105"
            style={{
              background: 'var(--nm-accent)',
              color: 'white'
            }}
          >
            Изменить
          </button>
        </div>

        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium mb-2" style={{ color: 'var(--nm-text)' }}>
              Имя пользователя
            </label>
            <input
              type="text"
              defaultValue="Иван Петров"
              className="w-full px-4 py-3 rounded-xl border outline-none transition-all duration-200 focus:border-[var(--nm-accent)]"
              style={{
                background: 'var(--nm-bg)',
                color: 'var(--nm-text)',
                borderColor: 'var(--nm-border)'
              }}
            />
          </div>

          <div>
            <label className="block text-sm font-medium mb-2" style={{ color: 'var(--nm-text)' }}>
              Email
            </label>
            <input
              type="email"
              defaultValue="ivan@example.com"
              className="w-full px-4 py-3 rounded-xl border outline-none transition-all duration-200 focus:border-[var(--nm-accent)]"
              style={{
                background: 'var(--nm-bg)',
                color: 'var(--nm-text)',
                borderColor: 'var(--nm-border)'
              }}
            />
          </div>

          <div>
            <label className="block text-sm font-medium mb-2" style={{ color: 'var(--nm-text)' }}>
              О себе
            </label>
            <textarea
              defaultValue="Разработчик и дизайнер"
              rows={3}
              className="w-full px-4 py-3 rounded-xl border outline-none transition-all duration-200 focus:border-[var(--nm-accent)] resize-none"
              style={{
                background: 'var(--nm-bg)',
                color: 'var(--nm-text)',
                borderColor: 'var(--nm-border)'
              }}
            />
          </div>
        </div>
      </div>

      {/* Save button */}
      <button
        className="w-full px-6 py-4 rounded-xl font-medium transition-all duration-200 hover:scale-[1.02]"
        style={{
          background: 'var(--nm-accent)',
          color: 'white',
          boxShadow: `0 8px 32px var(--nm-shadow)`
        }}
      >
        Сохранить изменения
      </button>
    </div>
  );
}

function PersonalizationTab() {
  const { theme, setTheme } = useTheme();
  const [currentThemeIndex, setCurrentThemeIndex] = useState(0);
  const scrollRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const index = themes.findIndex(t => t.id === theme);
    if (index !== -1) {
      setCurrentThemeIndex(index);
    }
  }, [theme]);

  const scrollToIndex = (index: number) => {
    if (scrollRef.current) {
      const itemWidth = 180; // width + gap
      scrollRef.current.scrollTo({
        left: index * itemWidth - itemWidth,
        behavior: 'smooth'
      });
    }
  };

  const handlePrevTheme = () => {
    const newIndex = Math.max(0, currentThemeIndex - 1);
    setCurrentThemeIndex(newIndex);
    scrollToIndex(newIndex);
  };

  const handleNextTheme = () => {
    const newIndex = Math.min(themes.length - 1, currentThemeIndex + 1);
    setCurrentThemeIndex(newIndex);
    scrollToIndex(newIndex);
  };

  return (
    <div className="space-y-6">
      <div>
        <h3 className="text-2xl font-bold mb-2" style={{ color: 'var(--nm-text)' }}>
          Персонализация
        </h3>
        <p style={{ color: 'var(--nm-text-secondary)' }}>
          Настройте внешний вид приложения
        </p>
      </div>

      {/* Theme selector */}
      <div
        className="p-6 rounded-2xl"
        style={{
          background: 'var(--nm-surface)',
          border: '1px solid var(--nm-border)'
        }}
      >
        <h4 className="font-bold mb-4 flex items-center gap-2" style={{ color: 'var(--nm-text)' }}>
          <Palette className="w-5 h-5" />
          Тема оформления
        </h4>

        {/* Theme preview slider */}
        <div className="relative">
          <button
            onClick={handlePrevTheme}
            disabled={currentThemeIndex === 0}
            className="absolute left-0 top-1/2 -translate-y-1/2 z-10 p-2 rounded-full transition-all duration-200 hover:scale-110 disabled:opacity-30 disabled:cursor-not-allowed"
            style={{
              background: 'var(--nm-surface-hover)',
              color: 'var(--nm-text)'
            }}
          >
            <ChevronLeft className="w-5 h-5" />
          </button>

          <div
            ref={scrollRef}
            className="flex gap-4 overflow-x-auto scrollbar-hide px-12 py-2"
            style={{ scrollbarWidth: 'none' }}
          >
            {themes.map((t, index) => (
              <motion.button
                key={t.id}
                onClick={() => {
                  setTheme(t.id as any);
                  setCurrentThemeIndex(index);
                }}
                whileHover={{ scale: 1.05, y: -4 }}
                whileTap={{ scale: 0.95 }}
                className="flex-shrink-0 w-40 p-4 rounded-xl transition-all duration-200"
                style={{
                  background: theme === t.id ? 'var(--nm-surface-hover)' : 'var(--nm-bg)',
                  border: `2px solid ${theme === t.id ? t.preview : 'var(--nm-border)'}`,
                  boxShadow: theme === t.id ? `0 8px 24px ${t.preview}33` : 'none'
                }}
              >
                <div
                  className="w-full h-20 rounded-lg mb-3"
                  style={{
                    background: `linear-gradient(135deg, ${t.preview}, ${t.preview}aa)`
                  }}
                />
                <p className="font-medium text-center" style={{ color: 'var(--nm-text)' }}>
                  {t.name}
                </p>
              </motion.button>
            ))}
          </div>

          <button
            onClick={handleNextTheme}
            disabled={currentThemeIndex === themes.length - 1}
            className="absolute right-0 top-1/2 -translate-y-1/2 z-10 p-2 rounded-full transition-all duration-200 hover:scale-110 disabled:opacity-30 disabled:cursor-not-allowed"
            style={{
              background: 'var(--nm-surface-hover)',
              color: 'var(--nm-text)'
            }}
          >
            <ChevronRight className="w-5 h-5" />
          </button>
        </div>
      </div>

      {/* Other personalization options */}
      <div
        className="p-6 rounded-2xl space-y-4"
        style={{
          background: 'var(--nm-surface)',
          border: '1px solid var(--nm-border)'
        }}
      >
        <h4 className="font-bold mb-4" style={{ color: 'var(--nm-text)' }}>
          Дополнительно
        </h4>

        <ToggleOption
          label="Анимации интерфейса"
          description="Плавные переходы и эффекты"
          defaultChecked={true}
        />

        <ToggleOption
          label="Компактный режим"
          description="Уменьшенные отступы в интерфейсе"
          defaultChecked={false}
        />

        <ToggleOption
          label="Показывать аватары"
          description="Отображать аватары в списке чатов"
          defaultChecked={true}
        />
      </div>
    </div>
  );
}

function NotificationsTab() {
  return (
    <div className="space-y-6">
      <div>
        <h3 className="text-2xl font-bold mb-2" style={{ color: 'var(--nm-text)' }}>
          Уведомления
        </h3>
        <p style={{ color: 'var(--nm-text-secondary)' }}>
          Управление уведомлениями и звуками
        </p>
      </div>

      <div
        className="p-6 rounded-2xl space-y-4"
        style={{
          background: 'var(--nm-surface)',
          border: '1px solid var(--nm-border)'
        }}
      >
        <h4 className="font-bold mb-4" style={{ color: 'var(--nm-text)' }}>
          Личные чаты
        </h4>

        <ToggleOption
          label="Push-уведомления"
          description="Получать уведомления о новых сообщениях"
          defaultChecked={true}
        />

        <ToggleOption
          label="Звук уведомлений"
          description="Воспроизводить звук при получении сообщения"
          defaultChecked={true}
        />

        <ToggleOption
          label="Превью сообщений"
          description="Показывать текст сообщения в уведомлении"
          defaultChecked={true}
        />
      </div>

      <div
        className="p-6 rounded-2xl space-y-4"
        style={{
          background: 'var(--nm-surface)',
          border: '1px solid var(--nm-border)'
        }}
      >
        <h4 className="font-bold mb-4" style={{ color: 'var(--nm-text)' }}>
          Группы и каналы
        </h4>

        <ToggleOption
          label="Уведомления из групп"
          description="Получать уведомления из групповых чатов"
          defaultChecked={true}
        />

        <ToggleOption
          label="Упоминания"
          description="Уведомлять только при упоминании"
          defaultChecked={false}
        />
      </div>
    </div>
  );
}

function PrivacyTab() {
  return (
    <div className="space-y-6">
      <div>
        <h3 className="text-2xl font-bold mb-2" style={{ color: 'var(--nm-text)' }}>
          Конфиденциальность
        </h3>
        <p style={{ color: 'var(--nm-text-secondary)' }}>
          Управление приватностью и безопасностью
        </p>
      </div>

      <div
        className="p-6 rounded-2xl space-y-4"
        style={{
          background: 'var(--nm-surface)',
          border: '1px solid var(--nm-border)'
        }}
      >
        <h4 className="font-bold mb-4" style={{ color: 'var(--nm-text)' }}>
          Видимость профиля
        </h4>

        <SelectOption
          label="Последняя активность"
          options={['Все', 'Контакты', 'Никто']}
          defaultValue="Контакты"
        />

        <SelectOption
          label="Фото профиля"
          options={['Все', 'Контакты', 'Никто']}
          defaultValue="Все"
        />

        <SelectOption
          label="Статус"
          options={['Все', 'Контакты', 'Никто']}
          defaultValue="Все"
        />
      </div>

      <div
        className="p-6 rounded-2xl space-y-4"
        style={{
          background: 'var(--nm-surface)',
          border: '1px solid var(--nm-border)'
        }}
      >
        <h4 className="font-bold mb-4" style={{ color: 'var(--nm-text)' }}>
          Безопасность
        </h4>

        <ToggleOption
          label="Двухфакторная аутентификация"
          description="Дополнительная защита аккаунта"
          defaultChecked={true}
        />

        <ToggleOption
          label="Подтверждение входа"
          description="Уведомлять о новых входах в аккаунт"
          defaultChecked={true}
        />
      </div>
    </div>
  );
}

function AdvancedTab() {
  return (
    <div className="space-y-6">
      <div>
        <h3 className="text-2xl font-bold mb-2" style={{ color: 'var(--nm-text)' }}>
          Дополнительно
        </h3>
        <p style={{ color: 'var(--nm-text-secondary)' }}>
          Расширенные настройки и управление данными
        </p>
      </div>

      {/* Data card */}
      <div
        className="p-6 rounded-2xl"
        style={{
          background: 'var(--nm-surface)',
          border: '1px solid var(--nm-border)'
        }}
      >
        <div className="flex items-start gap-4">
          <div
            className="w-12 h-12 rounded-xl flex items-center justify-center flex-shrink-0"
            style={{ background: 'var(--nm-accent)' }}
          >
            <Download className="w-6 h-6 text-white" />
          </div>
          <div className="flex-1">
            <h4 className="font-bold mb-2" style={{ color: 'var(--nm-text)' }}>
              Сохранение данных
            </h4>
            <p className="text-sm mb-4" style={{ color: 'var(--nm-text-secondary)' }}>
              Экспортируйте все ваши сообщения, медиа и данные профиля
            </p>
            <div className="flex gap-2">
              <button
                className="px-4 py-2 rounded-xl transition-all duration-200 hover:scale-105"
                style={{
                  background: 'var(--nm-accent)',
                  color: 'white'
                }}
              >
                Экспортировать
              </button>
              <button
                className="px-4 py-2 rounded-xl transition-all duration-200 hover:scale-105"
                style={{
                  background: 'var(--nm-surface-hover)',
                  color: 'var(--nm-text)',
                  border: '1px solid var(--nm-border)'
                }}
              >
                История экспорта
              </button>
            </div>
          </div>
        </div>
      </div>

      <div
        className="p-6 rounded-2xl space-y-4"
        style={{
          background: 'var(--nm-surface)',
          border: '1px solid var(--nm-border)'
        }}
      >
        <h4 className="font-bold mb-4" style={{ color: 'var(--nm-text)' }}>
          Хранилище
        </h4>

        <div className="space-y-2">
          <div className="flex justify-between text-sm">
            <span style={{ color: 'var(--nm-text-secondary)' }}>Использовано</span>
            <span style={{ color: 'var(--nm-text)' }}>2.4 ГБ из 15 ГБ</span>
          </div>
          <div
            className="h-2 rounded-full overflow-hidden"
            style={{ background: 'var(--nm-bg)' }}
          >
            <div
              className="h-full rounded-full"
              style={{
                width: '16%',
                background: 'var(--nm-accent)'
              }}
            />
          </div>
        </div>

        <button
          className="w-full mt-4 px-4 py-3 rounded-xl transition-all duration-200 hover:scale-[1.02]"
          style={{
            background: 'var(--nm-surface-hover)',
            color: 'var(--nm-text)',
            border: '1px solid var(--nm-border)'
          }}
        >
          Очистить кэш
        </button>
      </div>

      <div
        className="p-6 rounded-2xl space-y-4"
        style={{
          background: 'var(--nm-surface)',
          border: '1px solid var(--nm-border)'
        }}
      >
        <h4 className="font-bold mb-4" style={{ color: 'var(--nm-text)' }}>
          О приложении
        </h4>

        <div className="space-y-2 text-sm">
          <div className="flex justify-between">
            <span style={{ color: 'var(--nm-text-secondary)' }}>Версия</span>
            <span style={{ color: 'var(--nm-text)' }}>1.0.0</span>
          </div>
          <div className="flex justify-between">
            <span style={{ color: 'var(--nm-text-secondary)' }}>Платформа</span>
            <span style={{ color: 'var(--nm-text)' }}>Web</span>
          </div>
        </div>
      </div>
    </div>
  );
}

function ToggleOption({ label, description, defaultChecked }: any) {
  const [checked, setChecked] = useState(defaultChecked);

  return (
    <div className="flex items-center justify-between py-2">
      <div className="flex-1">
        <p className="font-medium mb-1" style={{ color: 'var(--nm-text)' }}>
          {label}
        </p>
        <p className="text-sm" style={{ color: 'var(--nm-text-secondary)' }}>
          {description}
        </p>
      </div>
      <button
        onClick={() => setChecked(!checked)}
        className="relative w-12 h-6 rounded-full transition-all duration-300"
        style={{
          background: checked ? 'var(--nm-accent)' : 'var(--nm-border)'
        }}
      >
        <motion.div
          className="absolute top-0.5 w-5 h-5 rounded-full bg-white"
          animate={{
            left: checked ? 'calc(100% - 22px)' : '2px'
          }}
          transition={{ type: "spring", stiffness: 500, damping: 30 }}
        />
      </button>
    </div>
  );
}

function SelectOption({ label, options, defaultValue }: any) {
  const [value, setValue] = useState(defaultValue);

  return (
    <div className="py-2">
      <p className="font-medium mb-3" style={{ color: 'var(--nm-text)' }}>
        {label}
      </p>
      <div className="flex gap-2">
        {options.map((option: string) => (
          <button
            key={option}
            onClick={() => setValue(option)}
            className="px-4 py-2 rounded-xl transition-all duration-200 hover:scale-105"
            style={{
              background: value === option ? 'var(--nm-accent)' : 'var(--nm-surface-hover)',
              color: value === option ? 'white' : 'var(--nm-text)',
              border: value === option ? 'none' : '1px solid var(--nm-border)'
            }}
          >
            {option}
          </button>
        ))}
      </div>
    </div>
  );
}
