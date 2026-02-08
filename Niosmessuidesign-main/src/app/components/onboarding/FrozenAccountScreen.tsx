import { motion } from 'motion/react';
import { Snowflake, AlertTriangle } from 'lucide-react';
import { Screen } from '../../App';

interface FrozenAccountScreenProps {
  onNavigate: (screen: Screen) => void;
}

export function FrozenAccountScreen({ onNavigate }: FrozenAccountScreenProps) {
  return (
    <div className="w-full h-full flex items-center justify-center" style={{ background: 'var(--nm-bg)' }}>
      <motion.div
        initial={{ opacity: 0, scale: 0.95 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ duration: 0.4, ease: [0.22, 1, 0.36, 1] }}
        className="flex flex-col items-center text-center max-w-md px-8"
      >
        {/* Frozen fox with ice effect */}
        <div className="relative mb-8">
          <motion.div
            animate={{
              rotate: [0, -5, 5, -5, 0],
            }}
            transition={{
              duration: 2,
              repeat: Infinity,
              ease: "easeInOut"
            }}
            className="text-8xl filter brightness-90"
          >
            🦊
          </motion.div>
          
          {/* Ice particles */}
          <motion.div
            className="absolute inset-0 flex items-center justify-center"
            animate={{
              rotate: [0, 360],
            }}
            transition={{
              duration: 20,
              repeat: Infinity,
              ease: "linear"
            }}
          >
            <Snowflake className="absolute -top-4 -left-4 w-8 h-8 text-blue-300 opacity-70" />
            <Snowflake className="absolute -top-2 right-0 w-6 h-6 text-blue-400 opacity-60" />
            <Snowflake className="absolute bottom-0 -left-2 w-7 h-7 text-blue-200 opacity-80" />
            <Snowflake className="absolute -bottom-4 right-4 w-5 h-5 text-blue-300 opacity-50" />
          </motion.div>

          {/* Glow effect */}
          <div
            className="absolute inset-0 -z-10 blur-3xl opacity-40"
            style={{ background: 'linear-gradient(135deg, #60a5fa, #93c5fd)' }}
          />
        </div>

        <div
          className="inline-flex items-center gap-2 px-4 py-2 rounded-full mb-4"
          style={{
            background: 'var(--nm-surface)',
            border: '1px solid #60a5fa'
          }}
        >
          <AlertTriangle className="w-5 h-5 text-blue-400" />
          <span className="font-medium text-blue-400">Аккаунт заморожен</span>
        </div>

        <h2 className="text-3xl font-bold mb-4" style={{ color: 'var(--nm-text)' }}>
          Доступ временно ограничен
        </h2>

        <p className="text-lg mb-6" style={{ color: 'var(--nm-text-secondary)' }}>
          Ваш аккаунт был заморожен по следующей причине:
        </p>

        <div
          className="w-full p-6 rounded-2xl mb-8"
          style={{
            background: 'var(--nm-surface)',
            border: '1px solid var(--nm-border)'
          }}
        >
          <p style={{ color: 'var(--nm-text)' }}>
            Обнаружена подозрительная активность. Пожалуйста, подтвердите свою личность через email или обратитесь в поддержку.
          </p>
        </div>

        <div className="flex flex-col gap-3 w-full">
          <button
            className="w-full px-8 py-4 rounded-xl font-medium transition-all duration-300 hover:scale-[1.02] active:scale-[0.98]"
            style={{
              background: 'var(--nm-accent)',
              color: 'white',
              boxShadow: `0 8px 32px var(--nm-shadow)`
            }}
          >
            Связаться с поддержкой
          </button>

          <button
            onClick={() => onNavigate('login')}
            className="w-full px-8 py-4 rounded-xl font-medium transition-all duration-300 hover:scale-[1.02] active:scale-[0.98]"
            style={{
              background: 'var(--nm-surface)',
              color: 'var(--nm-text)',
              border: '1px solid var(--nm-border)'
            }}
          >
            Вернуться к входу
          </button>
        </div>
      </motion.div>
    </div>
  );
}
