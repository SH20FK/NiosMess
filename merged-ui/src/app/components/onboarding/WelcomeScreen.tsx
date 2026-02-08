import { motion } from 'motion/react';
import { Sparkles } from 'lucide-react';
import { Screen } from '../../App';

interface WelcomeScreenProps {
  onNavigate: (screen: Screen) => void;
}

export function WelcomeScreen({ onNavigate }: WelcomeScreenProps) {
  return (
    <div className="w-full h-full flex items-center justify-center" style={{ background: 'var(--nm-bg)' }}>
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.6, ease: [0.22, 1, 0.36, 1] }}
        className="flex flex-col items-center text-center max-w-md px-8"
      >
        {/* Fox mascot */}
        <motion.div
          initial={{ scale: 0.8, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          transition={{ delay: 0.2, duration: 0.6, ease: [0.22, 1, 0.36, 1] }}
          className="relative mb-8"
        >
          <div className="text-9xl relative">
            🦊
            <motion.div
              className="absolute -top-2 -right-2"
              animate={{
                y: [-5, 5, -5],
                rotate: [0, 10, 0],
              }}
              transition={{
                duration: 3,
                repeat: Infinity,
                ease: "easeInOut"
              }}
            >
              <Sparkles className="w-8 h-8" style={{ color: 'var(--nm-accent)' }} />
            </motion.div>
          </div>
          
          {/* Glow effect */}
          <motion.div
            className="absolute inset-0 -z-10 blur-3xl"
            style={{ background: 'var(--nm-glow)' }}
            animate={{
              opacity: [0.3, 0.6, 0.3],
              scale: [1, 1.1, 1],
            }}
            transition={{
              duration: 4,
              repeat: Infinity,
              ease: "easeInOut"
            }}
          />
        </motion.div>

        <motion.h1
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.3, duration: 0.6 }}
          className="text-5xl font-bold mb-4"
          style={{ color: 'var(--nm-text)' }}
        >
          NiosMess
        </motion.h1>

        <motion.p
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.4, duration: 0.6 }}
          className="text-lg mb-12"
          style={{ color: 'var(--nm-text-secondary)' }}
        >
          Премиум мессенджер нового поколения
        </motion.p>

        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.5, duration: 0.6 }}
          className="flex flex-col gap-4 w-full"
        >
          <button
            onClick={() => onNavigate('register')}
            className="px-8 py-4 rounded-2xl font-medium transition-all duration-300 hover:scale-[1.02] active:scale-[0.98]"
            style={{
              background: 'var(--nm-accent)',
              color: 'white',
              boxShadow: `0 8px 32px var(--nm-shadow)`
            }}
          >
            Начать
          </button>

          <button
            onClick={() => onNavigate('login')}
            className="px-8 py-4 rounded-2xl font-medium transition-all duration-300 hover:scale-[1.02] active:scale-[0.98]"
            style={{
              background: 'var(--nm-surface)',
              color: 'var(--nm-text)',
              border: '1px solid var(--nm-border)'
            }}
          >
            Уже есть аккаунт
          </button>
        </motion.div>
      </motion.div>
    </div>
  );
}
