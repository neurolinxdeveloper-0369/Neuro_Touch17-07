# Implementation Plan - Set Dashboard Icons to White

The user wants the icons in the dashboard to be displayed in white by default. Currently, some icons use brand colors (like blue or green) in dark mode, which results in low contrast against the dark blue card backgrounds.

## User Review Required

> [!NOTE]
> This change will make all primary icons in the dashboard cards (Rooms, Devices, Summary) white in both light and dark modes, as the cards themselves are dark blue in both modes.

## Proposed Changes

### [Dashboard UI]

#### [MODIFY] [dashboard_screen.dart](file:///B:/IoT_Neuro Touch/IoT_Neuro Touch/mobile/lib/presentation/dashboard/dashboard_screen.dart)
- Update `_SummaryCard` to always use `Colors.white` for icons.
- Update `_RoomCard` to always use `Colors.white` for icons.
- Update `_DeviceListItem` to always use `Colors.white` for icons.
- Ensure all icons inside cards have consistent white color regardless of the theme mode.

## Verification Plan

### Manual Verification
1. Open the dashboard in the mobile app.
2. Verify that icons in "Online", "Total Load", and "Automations" cards are white.
3. Verify that icons in "Rooms" cards are white.
4. Verify that icons in "Devices" list are white.
5. Switch between Dark and Light modes and ensure icons remain white and legible.
