import { motion } from 'motion/react';
import { useState } from 'react';
import { Sparkles } from 'lucide-react';

interface FoxBadgeProps {
  size?: 'sm' | 'md';
}

export function FoxBadge({ size = 'md' }: FoxBadgeProps) {
  const [showTooltip, setShowTooltip] = useState(false);

  const sizeClasses = {
    sm: 'w-4 h-4',
    md: 'w-5 h-5'
  };

  return (
    <div className="relative inline-block">
      <motion.button
        onHoverStart={() => setShowTooltip(true)}
        onHoverEnd={() => setShowTooltip(false)}
        onClick={() => setShowTooltip(!showTooltip)}
        whileHover={{ scale: 1.1 }}
        whileTap={{ scale: 0.95 }}
        className={`relative ${sizeClasses[size]} rounded-full flex items-center justify-center`}
      >
        <span className={size === 'sm' ? 'text-xs' : 'text-sm'}>🦊</span>
        
        {/* Particle effects */}
        <motion.div
          className="absolute inset-0"
          animate={{
            rotate: [0, 360],
          }}
          transition={{
            duration: 10,
            repeat: Infinity,
            ease: "linear"
          }}
        >
          <Sparkles 
            className="absolute -top-1 -right-1 w-2 h-2 opacity-60" 
            style={{ color: 'var(--nm-accent)' }} 
          />
        </motion.div>

        {/* Glow effect */}
        <motion.div
          className="absolute inset-0 -z-10 blur-sm rounded-full"
          style={{ background: 'var(--nm-glow)' }}
          animate={{
            opacity: [0.3, 0.6, 0.3],
            scale: [1, 1.2, 1],
          }}
          transition={{
            duration: 2,
            repeat: Infinity,
            ease: "easeInOut"
          }}
        />
      </motion.button>

      {/* Tooltip */}
      {showTooltip && (
        <motion.div
          initial={{ opacity: 0, y: 10, scale: 0.9 }}
          animate={{ opacity: 1, y: 0, scale: 1 }}
          exit={{ opacity: 0, y: 10, scale: 0.9 }}
          transition={{
            type: "spring",
            stiffness: 400,
            damping: 20
          }}
          className="absolute left-1/2 -translate-x-1/2 top-full mt-2 z-50 w-64 p-3 rounded-xl"
          style={{
            background: 'var(--nm-surface)',
            border: '1px solid var(--nm-border)',
            boxShadow: `0 8px 32px var(--nm-shadow)`
          }}
        >
          <p className="text-sm" style={{ color: 'var(--nm-text)' }}>
            Этот человек связан с разработкой напрямую или является спонсором NiosMess
          </p>
        </motion.div>
      )}
    </div>
  );
}
