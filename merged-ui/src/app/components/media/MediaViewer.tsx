import { motion } from 'motion/react';
import { X, Download, Share2, ChevronLeft, ChevronRight, ZoomIn, ZoomOut } from 'lucide-react';
import { Screen } from '../../App';
import { useState } from 'react';

interface MediaViewerProps {
  media: any;
  onNavigate: (screen: Screen) => void;
}

export function MediaViewer({ media, onNavigate }: MediaViewerProps) {
  const [zoom, setZoom] = useState(1);

  if (!media) {
    onNavigate('chat');
    return null;
  }

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      className="fixed inset-0 z-50 flex items-center justify-center"
      style={{ background: 'rgba(10, 5, 20, 0.95)' }}
    >
      {/* Header */}
      <div className="absolute top-0 left-0 right-0 p-4 flex items-center justify-between z-10">
        <div className="flex items-center gap-4">
          <button
            onClick={() => onNavigate('chat')}
            className="p-2 rounded-xl transition-all duration-200 hover:scale-110 active:scale-95"
            style={{
              background: 'var(--nm-surface)',
              color: 'var(--nm-text)'
            }}
          >
            <X className="w-6 h-6" />
          </button>

          <div>
            <p className="font-medium" style={{ color: 'var(--nm-text)' }}>
              Изображение
            </p>
            <p className="text-sm" style={{ color: 'var(--nm-text-secondary)' }}>
              5 февраля 2026
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <button
            className="p-2 rounded-xl transition-all duration-200 hover:scale-110 active:scale-95"
            style={{
              background: 'var(--nm-surface)',
              color: 'var(--nm-text)'
            }}
          >
            <Download className="w-5 h-5" />
          </button>

          <button
            className="p-2 rounded-xl transition-all duration-200 hover:scale-110 active:scale-95"
            style={{
              background: 'var(--nm-surface)',
              color: 'var(--nm-text)'
            }}
          >
            <Share2 className="w-5 h-5" />
          </button>
        </div>
      </div>

      {/* Media content */}
      <div className="relative w-full h-full flex items-center justify-center p-20">
        <motion.div
          animate={{ scale: zoom }}
          transition={{ duration: 0.2 }}
          className="max-w-full max-h-full"
        >
          {media.type === 'image' && (
            <img
              src={media.url}
              alt="Media"
              className="max-w-full max-h-full rounded-2xl"
              style={{
                boxShadow: `0 24px 64px var(--nm-shadow)`
              }}
            />
          )}
        </motion.div>

        {/* Navigation arrows */}
        <button
          className="absolute left-8 top-1/2 -translate-y-1/2 p-3 rounded-xl transition-all duration-200 hover:scale-110 active:scale-95"
          style={{
            background: 'var(--nm-surface)',
            color: 'var(--nm-text)'
          }}
        >
          <ChevronLeft className="w-6 h-6" />
        </button>

        <button
          className="absolute right-8 top-1/2 -translate-y-1/2 p-3 rounded-xl transition-all duration-200 hover:scale-110 active:scale-95"
          style={{
            background: 'var(--nm-surface)',
            color: 'var(--nm-text)'
          }}
        >
          <ChevronRight className="w-6 h-6" />
        </button>
      </div>

      {/* Zoom controls */}
      <div className="absolute bottom-8 left-1/2 -translate-x-1/2 flex items-center gap-2 p-2 rounded-xl"
        style={{
          background: 'var(--nm-surface)',
          border: '1px solid var(--nm-border)'
        }}
      >
        <button
          onClick={() => setZoom(Math.max(0.5, zoom - 0.25))}
          disabled={zoom <= 0.5}
          className="p-2 rounded-lg transition-all duration-200 hover:scale-110 active:scale-95 disabled:opacity-30"
          style={{ color: 'var(--nm-text)' }}
        >
          <ZoomOut className="w-5 h-5" />
        </button>

        <span className="px-4 font-medium" style={{ color: 'var(--nm-text)' }}>
          {Math.round(zoom * 100)}%
        </span>

        <button
          onClick={() => setZoom(Math.min(3, zoom + 0.25))}
          disabled={zoom >= 3}
          className="p-2 rounded-lg transition-all duration-200 hover:scale-110 active:scale-95 disabled:opacity-30"
          style={{ color: 'var(--nm-text)' }}
        >
          <ZoomIn className="w-5 h-5" />
        </button>
      </div>
    </motion.div>
  );
}
