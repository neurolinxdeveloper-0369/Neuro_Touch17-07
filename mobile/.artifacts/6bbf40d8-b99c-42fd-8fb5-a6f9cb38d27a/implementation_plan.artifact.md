# Implementation Plan - Back Gesture & Navigation Polish

This plan addresses the back gesture behavior and improves the bottom navigation bar's compatibility with different system navigation modes (Gesture vs. Button bar).

## User Review Required

> [!IMPORTANT]
> - **Back Gesture Change**: Swiping back from any main tab (Settings, Notifications, etc.) will now navigate you to the Home Dashboard instead of closing the app. Only swiping back from the Home tab will prompt an exit.
> - **Layout Adjustment**: The bottom navigation pill's vertical position will now dynamically adjust based on the device's system navigation style to ensure it never overlaps with buttons or gestures.

## Proposed Changes

### [Component] Main Shell & Navigation

#### [MODIFY] [main_shell.dart](file:///B:/IoT_Neuro%20Touch/IoT_Neuro%20Touch/mobile/lib/presentation/shell/main_shell.dart)
- **Back Gesture Handling**:
    - Wrap the `Scaffold` in a `PopScope`.
    - Set `canPop` to `true` only if `currentIndex == 0`.
    - Implement `onPopInvoked` to switch the active branch to Home (index 0) if the user tries to pop from a different tab.
- **Adaptive Bottom Spacing**:
    - Update `_BottomNav` to use `MediaQuery.paddingOf(context).bottom`.
    - Implement a safe-aware margin that adds a fixed gap (e.g., 20px) on top of whatever space the system navigation occupies. This ensures the "pill" always floats cleanly whether the user has Gesture Navigation or 3-Button Navigation enabled.
- **Visual Polish**:
    - Ensure the `_NavItem` icons and labels are vertically centered within the pill.

---

## Verification Plan

### Manual Verification
- [ ] **Back Gesture (Root Tabs)**: Go to the Settings tab, swipe back. Verify it switches to the Home tab.
- [ ] **App Exit**: On the Home tab, swipe back. Verify the app closes (expected behavior for the root).
- [ ] **System Nav Compatibility**:
    - Switch Android to "3-Button Navigation". Verify the pill floats above the buttons.
    - Switch Android to "Gesture Navigation". Verify the pill floats above the gesture bar.
