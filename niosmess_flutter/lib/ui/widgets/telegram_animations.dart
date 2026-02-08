import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';

/// Hero-анимация для аватаров с улучшенным переходом
class TelegramHeroAvatar extends StatelessWidget {
  const TelegramHeroAvatar({
    super.key,
    required this.heroTag,
    required this.child,
    this.size = 48,
    this.onTap,
    this.placeholder,
  });

  final String heroTag;
  final Widget child;
  final double size;
  final VoidCallback? onTap;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: heroTag,
      transitionOnUserGestures: true,
      flightShuttleBuilder: (context, animation, direction, fromContext, toContext) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return Container(
              width: Tween<double>(begin: size, end: size * 2.5).evaluate(animation),
              height: Tween<double>(begin: size, end: size * 2.5).evaluate(animation),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
              ),
              clipBehavior: Clip.antiAlias,
              child: child,
            );
          },
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: size,
            height: size,
            child: ClipOval(child: child),
          ),
        ),
      ),
    );
  }
}

/// Slide-переход между экранами (iOS/Telegram стиль)
class TelegramPageRoute<T> extends PageRouteBuilder<T> {
  TelegramPageRoute({
    required this.builder,
    this.direction = AxisDirection.right,
    this.maintainState = true,
    this.fullscreenDialog = false,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            
            // Используем кривые оптимизированные для 120Hz
            final curve = NiosAnimations.easeOutQuint;
            
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            var offsetAnimation = animation.drive(tween);
            
            // Добавляем параллельную анимацию прозрачности
            final fadeAnimation = Tween(begin: 0.8, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: NiosAnimations.easeOutExpo,
              ),
            );

            return SlideTransition(
              position: offsetAnimation,
              child: FadeTransition(
                opacity: fadeAnimation,
                child: child,
              ),
            );
          },
          transitionDuration: NiosAnimations.normal,
          reverseTransitionDuration: NiosAnimations.fast,
          maintainState: maintainState,
          fullscreenDialog: fullscreenDialog,
        );

  final WidgetBuilder builder;
  final AxisDirection direction;
  final bool maintainState;
  final bool fullscreenDialog;
}

/// Fade-переход для модальных экранов
class TelegramFadeRoute<T> extends PageRouteBuilder<T> {
  TelegramFadeRoute({
    required this.builder,
    this.barrierColor,
    this.barrierDismissible = true,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final fadeAnimation = CurvedAnimation(
              parent: animation,
              curve: NiosAnimations.easeOutExpo,
            );
            
            final scaleAnimation = Tween(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: NiosAnimations.easeOutBack,
              ),
            );

            return FadeTransition(
              opacity: fadeAnimation,
              child: ScaleTransition(
                scale: scaleAnimation,
                child: child,
              ),
            );
          },
          transitionDuration: NiosAnimations.normal,
          barrierColor: barrierColor,
          barrierDismissible: barrierDismissible,
          opaque: false,
        );

  final WidgetBuilder builder;
  final Color? barrierColor;
  final bool barrierDismissible;
}

/// Анимация появления сообщения (slide up + fade)
class MessageAppearAnimation extends StatelessWidget {
  const MessageAppearAnimation({
    super.key,
    required this.child,
    required this.isOutgoing,
    this.delay = Duration.zero,
  });

  final Widget child;
  final bool isOutgoing;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: NiosAnimations.slow,
      curve: NiosAnimations.easeOutBack,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(
              isOutgoing ? (1 - value) * 20 : (1 - value) * -20,
              (1 - value) * 10,
            ),
            child: Transform.scale(
              scale: 0.95 + (value * 0.05),
              alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// Staggered анимация для списка
class StaggeredListAnimation extends StatelessWidget {
  const StaggeredListAnimation({
    super.key,
    required this.child,
    required this.index,
    this.delayMultiplier = 1.0,
  });

  final Widget child;
  final int index;
  final double delayMultiplier;

  @override
  Widget build(BuildContext context) {
    final delay = Duration(
      milliseconds: (index * 40 * delayMultiplier).toInt().clamp(0, 400),
    );

    return FutureBuilder(
      future: Future.delayed(delay),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Opacity(opacity: 0, child: child);
        }
        
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: NiosAnimations.normal,
          curve: NiosAnimations.easeOutExpo,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, (1 - value) * 16),
                child: child,
              ),
            );
          },
          child: child,
        );
      },
    );
  }
}

/// Ripple эффект для списка чатов (Telegram-style)
class TelegramListItem extends StatelessWidget {
  const TelegramListItem({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.borderRadius = 12.0,
    this.backgroundColor,
    this.selected = false,
  });

  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double borderRadius;
  final Color? backgroundColor;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Material(
      color: selected 
          ? colorScheme.primaryContainer 
          : (backgroundColor ?? Colors.transparent),
      borderRadius: BorderRadius.circular(borderRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        onLongPress: onLongPress != null ? () {
          HapticFeedback.mediumImpact();
          onLongPress!();
        } : null,
        borderRadius: BorderRadius.circular(borderRadius),
        splashColor: colorScheme.primary.withValues(alpha: 0.08),
        highlightColor: colorScheme.primary.withValues(alpha: 0.04),
        child: child,
      ),
    );
  }
}

/// Анимированный контейнер с пузырем сообщения
class TelegramMessageBubble extends StatelessWidget {
  const TelegramMessageBubble({
    super.key,
    required this.child,
    required this.isOutgoing,
    this.showTail = true,
    this.backgroundColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  });

  final Widget child;
  final bool isOutgoing;
  final bool showTail;
  final Color? backgroundColor;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bgColor = backgroundColor ?? (isOutgoing 
        ? colorScheme.primary 
        : colorScheme.surfaceContainerHighest);
    
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isOutgoing ? 16 : 4),
          bottomRight: Radius.circular(isOutgoing ? 4 : 16),
        ),
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          color: isOutgoing ? Colors.white : colorScheme.onSurface,
          fontSize: 15,
          height: 1.4,
        ),
        child: child,
      ),
    );
  }
}

/// Анимированный индикатор онлайн-статуса
class OnlineIndicator extends StatelessWidget {
  const OnlineIndicator({
    super.key,
    this.size = 12,
    this.borderWidth = 2,
  });

  final double size;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50), // Telegram green
        shape: BoxShape.circle,
        border: Border.all(
          color: colorScheme.surface,
          width: borderWidth,
        ),
      ),
    );
  }
}

/// Анимированный бейдж непрочитанных сообщений
class UnreadBadge extends StatelessWidget {
  const UnreadBadge({
    super.key,
    required this.count,
    this.minWidth = 20,
  });

  final int count;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayCount = count > 99 ? '99+' : count.toString();
    
    return Container(
      constraints: BoxConstraints(
        minWidth: minWidth,
        minHeight: minWidth,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(minWidth / 2),
      ),
      child: Text(
        displayCount,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Анимированная кнопка с haptic feedback
class TelegramIconButton extends StatelessWidget {
  const TelegramIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 40,
    this.iconSize = 24,
    this.backgroundColor,
    this.foregroundColor,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    Widget button = Material(
      color: backgroundColor ?? colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(size / 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onPressed();
        },
        borderRadius: BorderRadius.circular(size / 4),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: iconSize,
            color: foregroundColor ?? colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );

    if (tooltip != null) {
      button = Tooltip(
        message: tooltip,
        child: button,
      );
    }

    return button;
  }
}

/// Анимированный AppBar в стиле Telegram
class TelegramAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TelegramAppBar({
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    this.actions,
    this.avatar,
    this.onAvatarTap,
    this.elevation = 0,
  });

  final Widget? title;
  final Widget? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  final Widget? avatar;
  final VoidCallback? onAvatarTap;
  final double elevation;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return AppBar(
      elevation: elevation,
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      leading: leading,
      title: avatar != null || subtitle != null
          ? Row(
              children: [
                if (avatar != null) ...[
                  InkWell(
                    onTap: onAvatarTap,
                    customBorder: const CircleBorder(),
                    child: avatar!,
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (title != null)
                        DefaultTextStyle(
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                          child: title!,
                        ),
                      if (subtitle != null)
                        DefaultTextStyle(
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                          child: subtitle!,
                        ),
                    ],
                  ),
                ),
              ],
            )
          : title,
      actions: actions,
      centerTitle: false,
    );
  }
}

/// Разделитель дат в чате
class DateSeparator extends StatelessWidget {
  const DateSeparator({
    super.key,
    required this.date,
  });

  final String date;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            date,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// Анимированный индикатор набора текста
class TypingIndicator extends StatelessWidget {
  const TypingIndicator({
    super.key,
    this.dotSize = 6,
    this.dotSpacing = 3,
  });

  final double dotSize;
  final double dotSpacing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: AlwaysStoppedAnimation(index),
          builder: (context, child) {
            return Container(
              margin: EdgeInsets.only(right: index < 2 ? dotSpacing : 0),
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }
}

/// Анимированный прогресс отправки
class SendingIndicator extends StatelessWidget {
  const SendingIndicator({
    super.key,
    this.size = 16,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
      ),
    );
  }
}
