import { AnimatePresence, motion } from 'motion/react';
import { useState } from 'react';

interface FoxBadgeProps {
  size?: 'sm' | 'md';
  title?: string;
  text?: string;
  icon?: string;
}

export function FoxBadge({
  size = 'md',
  title = 'Бейдж',
  text = 'Этот человек связан с разработкой напрямую или является спонсором NiosMess',
  icon = '??'
}: FoxBadgeProps) {
  const [showTooltip, setShowTooltip] = useState(false);

  const sizeClasses = {
    sm: 'w-4 h-4 text-[10px]',
    md: 'w-5 h-5 text-xs'
  };

  return (
    <div className="relative inline-flex align-middle">
      <motion.button
        onHoverStart={() => setShowTooltip(true)}
        onHoverEnd={() => setShowTooltip(false)}
        onClick={() => setShowTooltip(!showTooltip)}
        whileHover={{ scale: 1.08 }}
        whileTap={{ scale: 0.96 }}
        className={`nm-badge ${sizeClasses[size]} rounded-full flex items-center justify-center`}
        aria-label={title}
      >
        <span className="nm-badge-icon" aria-hidden="true">{icon}</span>
        <span className="nm-badge-particles" aria-hidden="true"></span>
      </motion.button>

      <AnimatePresence>
        {showTooltip && (
          <motion.div
            initial={{ opacity: 0, y: 10, scale: 0.96 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 8, scale: 0.98 }}
            transition={{ type: 'spring', stiffness: 360, damping: 24, mass: 0.6 }}
            className="nm-badge-tooltip"
            role="tooltip"
          >
            <div className="nm-badge-tooltip-title">{title}</div>
            <div className="nm-badge-tooltip-text">{text}</div>
            <span className="nm-badge-tooltip-arrow" aria-hidden="true"></span>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
