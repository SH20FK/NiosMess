import { motion } from 'motion/react';
import { AlertCircle, RefreshCw } from 'lucide-react';

interface ErrorStateProps {
  onRetry?: () => void;
}

export function ErrorState({ onRetry }: ErrorStateProps) {
  return (
    <div className="w-full h-full flex items-center justify-center" style={{ background: 'var(--nm-bg)' }}>
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4 }}
        className="flex flex-col items-center text-center max-w-md px-8"
      >
        {/* Sad fox */}
        <div className="relative mb-6">
          <motion.div
            animate={{
              rotate: [0, -10, 10, 0],
            }}
            transition={{
              duration: 3,
              repeat: Infinity,
              ease: "easeInOut"
            }}
            className="text-8xl grayscale opacity-70"
          >
            🦊
          </motion.div>
        </div>

        {/* Error icon */}
        <div
          className="w-16 h-16 rounded-full flex items-center justify-center mb-4"
          style={{
            background: 'var(--nm-surface)',
            border: '2px solid #ef4444'
          }}
        >
          <AlertCircle className="w-8 h-8 text-red-500" />
        </div>

        <h2 className="text-2xl font-bold mb-2" style={{ color: 'var(--nm-text)' }}>
          Что-то пошло не так
        </h2>

        <p className="mb-8" style={{ color: 'var(--nm-text-secondary)' }}>
          Произошла ошибка при загрузке данных. Пожалуйста, попробуйте еще раз.
        </p>

        {onRetry && (
          <button
            onClick={onRetry}
            className="flex items-center gap-2 px-6 py-3 rounded-xl font-medium transition-all duration-200 hover:scale-105"
            style={{
              background: 'var(--nm-accent)',
              color: 'white',
              boxShadow: `0 8px 32px var(--nm-shadow)`
            }}
          >
            <RefreshCw className="w-5 h-5" />
            Попробовать снова
          </button>
        )}
      </motion.div>
    </div>
  );
}
