import re

with open(r"E:\Niosmess V2\pulse_flutter\lib\screens\main_shell_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

# Replace PageView with PageTransitionSwitcher
old_body = """        final Widget body = PageView(
          controller: _pageController,
          onPageChanged: (int index) {
            final String targetTab = _tabs[index];
            if (targetTab != widget.tab) {
              context.go('/main/$targetTab');
            }
          },
          children: pages,
        );"""

new_body = """        final Widget body = PageTransitionSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (
            Widget child,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.scaled,
              fillColor: Colors.transparent,
              child: child,
            );
          },
          child: KeyedSubtree(
            key: ValueKey<int>(currentIndex),
            child: pages[currentIndex],
          ),
        );"""

content = content.replace(old_body, new_body)

if "import 'package:animations/animations.dart';" not in content:
    content = "import 'package:animations/animations.dart';\n" + content

with open(r"E:\Niosmess V2\pulse_flutter\lib\screens\main_shell_screen.dart", "w", encoding="utf-8") as f:
    f.write(content)
