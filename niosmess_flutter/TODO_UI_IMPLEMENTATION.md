# NIOSMESS UI Implementation TODO

## Progress

### Phase 1: Design System ✅
- [x] Create NiosColors with exact HEX values from spec
- [x] Create NiosGradients class with 6 gradient presets
- [x] Add typography constants (sizes, weights)
- [x] Add spacing and radius constants
- [x] Add shadow constants

### Phase 2: Core Widgets ✅
- [x] GradientIconButton - Circular gradient icon button
- [x] ThemePreviewCard - Mini chat preview for themes
- [x] SettingsRow - Settings list item
- [x] FloatingBottomNav - Floating nav bar with pill indicator
- [x] ProfileHeader - Avatar with camera overlay
- [x] ChatListItem - Chat row with online indicator and badge
- [x] NiosSearchBar - Pill-shaped search bar
- [x] SectionLabel - Uppercase section header

### Phase 3: Screens ✅
- [x] SettingsMainHubScreen - Main settings with profile, themes, rows
- [x] Update ChatListScreen - With search bar and FloatingBottomNav
- [ ] Update ProfileScreen - Scrolled state with larger text (optional)

### Phase 4: Integration 🔄
- [x] Fix imports in chat_list_screen.dart
- [ ] Fix imports in other existing files (theme.dart, settings screens, etc.)
- [ ] Test compilation
- [ ] Run app and verify UI


## Files Created/Modified

### New Files:
1. `lib/ui/nios_ui.dart` - Complete rewrite with NiosColors, NiosGradients, NiosPalette
2. `lib/ui/widgets/nios_design_widgets.dart` - All new design widgets
3. `lib/features/settings/settings_main_hub_screen.dart` - New settings screen

### Files to Update:
1. `lib/core/theme.dart` - Update to use new NiosPalette
2. `lib/features/chats/chat_list_screen.dart` - Use new widgets
3. `lib/features/profile/profile_screen.dart` - Use new ProfileHeader
4. All other files using old NiosPalette - Fix imports

## Color Reference (from spec)

| Token | HEX |
|-------|-----|
| bg_primary | #0E1621 |
| bg_surface | #17212B |
| bg_surface_alt | #1E2A36 |
| accent_blue | #2B7AE8 |
| text_white | #FFFFFF |
| text_grey | #8A9AA8 |
| text_muted | #6C7A89 |
| green_online | #4CAF50 |

## Gradients (from spec)

1. **gradient_blue**: #2B7AE8 → #5BA3F0
2. **gradient_orange**: #FF9500 → #FFB800
3. **gradient_purple**: #8B5CF6 → #D946EF
4. **gradient_green**: #10B981 → #34D399
5. **gradient_pink**: #EC4899 → #F472B6
6. **gradient_red**: #EF4444 → #F87171
