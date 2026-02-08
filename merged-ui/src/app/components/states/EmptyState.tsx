import { motion } from 'motion/react';
import { LucideIcon } from 'lucide-react';

interface EmptyStateProps {
  icon?: LucideIcon;
  emoji?: string;
  title: string;
  description: string;
  action?: {
    label: string;
    onClick: () => void;
  };
}

export function EmptyState({ icon: Icon, emoji, title, description, action }: EmptyStateProps) {
  return (
    <div className="w-full h-full flex items-center justify-center p-8">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4 }}
        className="flex flex-col items-center text-center max-w-md"
      >
        {/* Icon or emoji */}
        <div className="relative mb-6">
          {emoji ? (
            <div className="text-8xl">{emoji}</div>
          ) : Icon ? (
            <div
              className="w-24 h-24 rounded-full flex items-center justify-center"
              style={{ background: 'var(--nm-surface)' }}
            >
              <Icon className="w-12 h-12" style={{ color: 'var(--nm-text-secondary)' }} />
            </div>
          ) : (
            <div className="text-8xl">🦊</div>
          )}

          {/* Glow effect */}
          <motion.div
            className="absolute inset-0 -z-10 blur-3xl"
            style={{ background: 'var(--nm-glow)' }}
            animate={{
              opacity: [0.1, 0.3, 0.1],
              scale: [1, 1.2, 1],
            }}
            transition={{
              duration: 3,
              repeat: Infinity,
              ease: "easeInOut"
            }}
          />
        </div>

        <h3 className="text-2xl font-bold mb-2" style={{ color: 'var(--nm-text)' }}>
          {title}
        </h3>

        <p className="mb-6" style={{ color: 'var(--nm-text-secondary)' }}>
          {description}
        </p>

        {action && (
          <button
            onClick={action.onClick}
            className="px-6 py-3 rounded-xl font-medium transition-all duration-200 hover:scale-105"
            style={{
              background: 'var(--nm-accent)',
              color: 'white',
              boxShadow: `0 8px 32px var(--nm-shadow)`
            }}
          >
            {action.label}
          </button>
        )}
      </motion.div>
    </div>
  );
}
