# Web Support Setup - Summary

## What Was Added

### ✅ 1. Flutter Web Platform
- Enabled web support in Flutter config
- Generated `web/` directory with all necessary files
- Added Firebase Web SDK to `web/index.html`

### ✅ 2. Platform-Specific Code

**Auth Service** (`lib/services/auth_service.dart`)
- Web: Uses Firebase `signInWithPopup()` for Google Sign-In
- Mobile: Uses existing `google_sign_in` package
- Same authorization check (munenevincent49@gmail.com) applies to both

**Export Service** (`lib/services/export_service.dart`)
- Web: Downloads CSV file using `dart:html` blob download
- Mobile: Uses existing `share_plus` package
- Both export the same data

### ✅ 3. Web Layout Wrapper
- Created `lib/widgets/web_layout_wrapper.dart`
- On web: Centers app in 480px wide container with shadow
- On mobile: No wrapper applied (unchanged)
- Applied to ALL screens (sign in, main app, employee mode)

### ✅ 4. Build & Deploy Tools
- `build_web.sh` - Builds production web version
- `DEPLOY_WEB.md` - Complete deployment instructions
- Configured for GitHub Pages with base href `/cannonbutchery_tracker/`

---

## Testing Locally

```bash
# Run on web browser
flutter run -d chrome

# Or use edge
flutter run -d edge
```

---

## Files Changed

```
lib/
  main.dart                      # Added WebLayoutWrapper
  services/
    auth_service.dart            # Platform-specific Google Sign-In
    export_service.dart          # Platform-specific CSV export
  widgets/
    web_layout_wrapper.dart      # NEW - Web centering layout

web/
  index.html                     # Firebase Web SDK added
  (other generated files)

build_web.sh                     # NEW - Build script
DEPLOY_WEB.md                    # NEW - Deploy instructions
WEB_SETUP_SUMMARY.md            # NEW - This file
```

---

## Next Steps

1. **Test locally**
   ```bash
   flutter run -d chrome
   ```

2. **Deploy to GitHub Pages**
   - Follow instructions in `DEPLOY_WEB.md`
   - Remember to add your GitHub Pages domain to Firebase authorized domains

3. **Update Firestore rules** (if not done yet)
   - Config collection: readable by anyone (employee PIN)
   - Products collection: readable by anyone (employees need this)
   - Sales collection: read/write by anyone (employees log sales)
   - Everything else: requires authorized email

---

## Known Limitations

- Employee mode works on web (PIN authentication)
- Owner mode requires Google account with authorized email
- CSV export downloads single combined file on web (vs 3 files on mobile)
- Offline persistence works differently on web (browser storage limits)
