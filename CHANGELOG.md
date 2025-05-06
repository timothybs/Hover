# Changelog

All notable changes to this project will be documented here.

---

## [Unreleased]

### Added
- Inline “💵 Pay Cash” flow with change due logic and confirmation
- Shared `PaymentSuccessView` used across Tap to Pay, Cash, and Open Banking
- Email receipt integration via Resend
- QR code rendering for Open Banking redirect URL

### Changed
- Switched from `NavigationPath + enum` to simple `isPresented` navigation model
- Cash tendering UI is now embedded directly in `CheckoutView`
- Tap to Pay cancellation gracefully resets screen
- Success screen auto-dismisses after countdown or manual reset

### Fixed
- Black screen routing bug caused by `.navigationDestination` in a lazy container
- `.dismiss()` crash by removing environment usage when pushing via path
- PaymentIntent status polling for Open Banking now fully functional
