# E2E Test Infra: NiosGram & Settings M3 Expressive Overhaul

## Test Philosophy
- Opaque-box, requirement-driven. No dependency on implementation design.
- Methodology: Category-Partition + Boundary Value Analysis + Pairwise Combinations + Real-World Workload Testing across responsive screen sizes.

## Feature Inventory & Test Matrix
| # | Feature | Requirement | Tier 1 | Tier 2 | Tier 3 | Tier 4 |
|---|---------|-------------|:------:|:------:|:------:|:------:|
| 1 | NiosGram Canvas | Centered 720–800dp canvas on desktop, adaptive mobile | 5 | 5 | ✓ | ✓ |
| 2 | Expressive Post Card | 20–24dp corners, surfaceContainerLow, outlineVariant border, author badges | 5 | 5 | ✓ | ✓ |
| 3 | Media Viewport | Aspect-ratio container, 16dp inner radius, shimmer/blur loaders | 5 | 5 | ✓ | ✓ |
| 4 | Reactive Action Controls | Like/heart animation, comments counter, share, bookmark | 5 | 5 | ✓ | ✓ |
| 5 | Quick-Creation FAB | M3 cookie shape, tapping triggers creation flow | 5 | 5 | ✓ | ✓ |
| 6 | Settings Master-Detail | 2-pane on >=760dp, master 320–360dp with secondaryContainer highlight, detail pane | 5 | 5 | ✓ | ✓ |
| 7 | Settings Navigation | Router sync, direct URL deep linking, mobile stacked fallback | 5 | 5 | ✓ | ✓ |
| 8 | Grouped Settings Cards | surfaceContainerLow cards, 20dp radius across all 9 settings screens | 5 | 5 | ✓ | ✓ |
| 9 | Expressive Controls | Switch.adaptive, segmented buttons, tonal sliders, squircle leading containers | 5 | 5 | ✓ | ✓ |
| 10 | SVG Vector Illustrations | Empty feed states, media placeholders, section headers | 5 | 5 | ✓ | ✓ |

## Test Architecture
- **Location**: `pulse_flutter/test/e2e/` and `pulse_flutter/test/widgets/`
- **Invocation**: `flutter test test/widgets/` and `flutter test test/e2e/`
- **Runner**: Standard `flutter_test` harness with `ProviderScope`, `MaterialApp`, localization delegates, and responsive viewport sizing (`tester.binding.setSurfaceSize(Size(width, height))`).
- **Pass/Fail Semantics**: All test cases execute with 0 failures, 0 exceptions, 0 layout overflow errors.

## Test Tier Definitions
- **Tier 1 (Feature Coverage)**: Happy-path validation of each feature in isolation (>=5 test cases per feature).
- **Tier 2 (Boundary & Corner Cases)**: Extreme viewports (360x640 mobile up to 3840x2160 4K desktop), zero comments/likes, long text, missing media, rapid toggle interactions (>=5 per feature).
- **Tier 3 (Cross-Feature Combinations)**: Feed resizing during active scroll, theme switching while viewing settings master-detail, switching tabs with active detail pane selection.
- **Tier 4 (Real-World Application Scenarios)**: Complete user journeys (browsing feed, liking, bookmarking, opening settings, changing theme, adjusting font scale, inspecting sessions).
