import { motion } from 'motion/react';
import { ArrowLeft, Snowflake } from 'lucide-react';
import { Screen } from '../../App';

interface FrozenAccountScreenProps {
  onNavigate: (screen: Screen) => void;
  reason?: string | null;
}

export function FrozenAccountScreen({ onNavigate, reason }: FrozenAccountScreenProps) {
  return (
    <div className="w-full h-full flex items-center justify-center" style={{ background: 'var(--nm-bg)' }}>
      <motion.div
        initial={{ opacity: 0, scale: 0.9 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ duration: 0.4, ease: [0.22, 1, 0.36, 1] }}
        className="w-full max-w-md px-8 text-center"
      >
        <button
          onClick={() => onNavigate('login')}
          className="flex items-center gap-2 mb-8 transition-all duration-200 hover:gap-3"
          style={{ color: 'var(--nm-text-secondary)' }}
        >
          <ArrowLeft className="w-5 h-5" />
          <span>Назад</span>
        </button>

        <div className="flex justify-center mb-6">
          <div className="text-7xl">??</div>
          <Snowflake className="w-6 h-6 -ml-4 -mt-2" style={{ color: 'var(--nm-accent)' }} />
        </div>

        <h2 className="text-3xl font-bold mb-2" style={{ color: 'var(--nm-text)' }}>
          Аккаунт заморожен
        </h2>
        <p className="mb-6" style={{ color: 'var(--nm-text-secondary)' }}>
          Ваш аккаунт временно ограничен
        </p>

        <div
          className="p-4 rounded-xl text-left"
          style={{ background: 'var(--nm-surface)', border: '1px solid var(--nm-border)' }}
        >
          <p className="text-sm" style={{ color: 'var(--nm-text-secondary)' }}>
            Причина
          </p>
          <p className="text-base" style={{ color: 'var(--nm-text)' }}>
            {reason || 'Свяжитесь с поддержкой для уточнения'}
          </p>
        </div>
      </motion.div>
    </div>
  );
}
