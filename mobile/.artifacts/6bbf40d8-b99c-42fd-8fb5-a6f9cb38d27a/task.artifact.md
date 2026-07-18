# Responsive & Adaptive UI Refactor Task List

- [ ] Core Utilities
    - [ ] Create `responsive_layout.dart` with breakpoints and adaptive builder
    - [ ] Update `extensions.dart` with responsive context getters
- [ ] Navigation & Shell Refactor
    - [ ] Update `MainShell` to support `NavigationRail` for wide screens
    - [ ] Improve `SafeArea` and `Edge-to-Edge` support in `main_shell.dart`
    - [ ] Migrate local constants to Theme-based styling in `main_shell.dart`
- [ ] Dashboard Screen Refactor
    - [ ] Decompose `DashboardScreen` into smaller sub-widgets
    - [ ] Implement `GridView` for rooms on tablets/landscape
    - [ ] Remove fixed width/height multipliers for fonts and spacing
    - [ ] Full migration to `Theme.of(context)` for colors and typography
- [ ] Add Device Screen Refactor
    - [ ] Implement `ConstrainedBox` for large screens
    - [ ] Clean up local styling and use Theme
- [ ] Verification
    - [ ] Verify layout on different screen sizes (simulated or logic-based)
    - [ ] Check for safe area regressions
