import { motion, AnimatePresence } from 'motion/react';
import { X, LogIn, UserPlus, Snowflake, MessageSquare, Settings, Plus, Image, Loader, AlertCircle } from 'lucide-react';
import { Screen } from '../App';

interface DemoNavProps {
  currentScreen: Screen;
  onNavigate: (screen: Screen) => void;
  onClose: () => void;
}

const screens = [
  { id: 'showcase' as Screen, label: 'Showcase Home', icon: '🏠', group: 'Demo' },
  { id: 'welcome' as Screen, label: 'Welcome', icon: '👋', group: 'Onboarding' },
  { id: 'register' as Screen, label: 'Register', icon: UserPlus, group: 'Onboarding' },
  { id: 'login' as Screen, label: 'Login', icon: LogIn, group: 'Onboarding' },
  { id: 'frozen' as Screen, label: 'Frozen Account', icon: Snowflake, group: 'Onboarding' },
  { id: 'main' as Screen, label: 'Main / Chat List', icon: MessageSquare, group: 'Main' },
  { id: 'settings' as Screen, label: 'Settings', icon: Settings, group: 'Main' },
  { id: 'create-group' as Screen, label: 'Create Group', icon: Plus, group: 'Modals' },
  { id: 'loading' as Screen, label: 'Loading State', icon: Loader, group: 'States' },
  { id: 'error' as Screen, label: 'Error State', icon: AlertCircle, group: 'States' },
];

export function DemoNav({ currentScreen, onNavigate, onClose }: DemoNavProps) {
  const groupedScreens = screens.reduce((acc, screen) => {
    if (!acc[screen.group]) {
      acc[screen.group] = [];
    }
    acc[screen.group].push(screen);
    return acc;
  }, {} as Record<string, typeof screens>);

  return (
    <AnimatePresence>
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        exit={{ opacity: 0 }}
        className="fixed inset-0 z-40 flex items-center justify-center p-4"
        style={{ background: 'rgba(10, 5, 20, 0.8)' }}
        onClick={onClose}
      >
        <motion.div
          initial={{ opacity: 0, scale: 0.9, y: 20 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          exit={{ opacity: 0, scale: 0.9, y: 20 }}
          transition={{ duration: 0.3, ease: [0.22, 1, 0.36, 1] }}
          onClick={(e) => e.stopPropagation()}
          className="w-full max-w-2xl max-h-[80vh] rounded-2xl overflow-hidden"
          style={{
            background: 'var(--nm-surface)',
            border: '1px solid var(--nm-border)',
            boxShadow: `0 24px 64px var(--nm-shadow)`
          }}
        >
          {/* Header */}
          <div className="p-6 border-b" style={{ borderColor: 'var(--nm-border)' }}>
            <div className="flex items-center justify-between">
              <div>
                <h2 className="text-2xl font-bold mb-1" style={{ color: 'var(--nm-text)' }}>
                  🦊 NiosMess Demo Navigation
                </h2>
                <p style={{ color: 'var(--nm-text-secondary)' }}>
                  Explore all screens and components
                </p>
              </div>
              <button
                onClick={onClose}
                className="p-2 rounded-xl transition-all duration-200 hover:scale-110 active:scale-95"
                style={{ background: 'var(--nm-surface-hover)', color: 'var(--nm-text)' }}
              >
                <X className="w-5 h-5" />
              </button>
            </div>
          </div>

          {/* Content */}
          <div className="p-6 overflow-y-auto max-h-[calc(80vh-120px)]">
            <div className="space-y-6">
              {Object.entries(groupedScreens).map(([group, items]) => (
                <div key={group}>
                  <h3 className="text-sm font-bold mb-3 uppercase tracking-wider" style={{ color: 'var(--nm-text-secondary)' }}>
                    {group}
                  </h3>
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
                    {items.map((screen) => {
                      const Icon = typeof screen.icon === 'string' ? null : screen.icon;
                      const isActive = currentScreen === screen.id;

                      return (
                        <motion.button
                          key={screen.id}
                          onClick={() => onNavigate(screen.id)}
                          whileHover={{ scale: 1.02, x: 4 }}
                          whileTap={{ scale: 0.98 }}
                          className="flex items-center gap-3 p-4 rounded-xl text-left transition-all duration-200"
                          style={{
                            background: isActive ? 'var(--nm-accent)' : 'var(--nm-surface-hover)',
                            color: isActive ? 'white' : 'var(--nm-text)',
                            border: `1px solid ${isActive ? 'transparent' : 'var(--nm-border)'}`,
                            boxShadow: isActive ? `0 8px 24px var(--nm-shadow)` : 'none'
                          }}
                        >
                          {Icon ? (
                            <Icon className="w-5 h-5 flex-shrink-0" />
                          ) : (
                            <span className="text-xl">{screen.icon}</span>
                          )}
                          <span className="font-medium">{screen.label}</span>
                        </motion.button>
                      );
                    })}
                  </div>
                </div>
              ))}
            </div>

            {/* Info */}
            <div
              className="mt-6 p-4 rounded-xl"
              style={{
                background: 'var(--nm-bg)',
                border: '1px solid var(--nm-border)'
              }}
            >
              <p className="text-sm" style={{ color: 'var(--nm-text-secondary)' }}>
                💡 <strong style={{ color: 'var(--nm-text)' }}>Tip:</strong> Use the Settings screen to change themes. 
                The app supports 7 premium themes with smooth transitions.
              </p>
            </div>
          </div>
        </motion.div>
      </motion.div>
    </AnimatePresence>
  );
}