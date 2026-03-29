# BlinkMac — Launch Checklist

## Pre-Launch

### Code & Build
- [x] `BlinkMac.xcodeproj` generated via XcodeGen
- [x] Release build succeeds (`xcodebuild -configuration Release`)
- [ ] Testflight build uploaded (if applicable)
- [ ] Code signing configured (Developer ID or App Store distribution)

### App Store Connect
- [ ] App Store Connect account set up (paid developer program)
- [ ] New app entry created with correct bundle ID (`com.blinkmac.app`)
- [ ] Primary language set to English
- [ ] Category selected: **Photo & Video → Lifestyle**
- [ ] Pricing: Free (with optional future IAP for cloud storage)

### Metadata
- [ ] Tagline written: **"Your life, one moment at a time."**
- [ ] Short description (170 chars): written in App Store Connect
- [ ] Full description: uploaded from `BlinkMac/Marketing/APPSTORE.md`
- [ ] Keywords: uploaded from `APPSTORE.md`
- [ ] Privacy Policy URL: added (required)
- [ ] Support URL: added
- [ ] Marketing URL: added (optional)

### Screenshots & Preview
- [ ] 1280×800 Mac screenshot (main — calendar view, dark theme)
- [ ] 2560×1600 Mac Retina screenshot (hero/featured)
- [ ] 1920×1080 screenshot showing monthly reel
- [ ] 1920×1080 screenshot showing shared album
- [ ] App preview video (15–30s, H.264, dark cinematic aesthetic)
- [ ] All screenshots use real content (not placeholder gray boxes)

### Accessibility
- [ ] All buttons have `.accessibilityLabel`
- [ ] All images with semantic meaning have `.accessibilityLabel`
- [ ] VoiceOver navigation tested — all interactive elements reachable
- [ ] Color contrast meets WCAG 2.1 AA for text
- [ ] Dynamic Type supported (macOS Ventura+)

### Legal
- [ ] Privacy Policy published (required — even for local-only apps)
- [ ] Entitlements configured for App Sandbox (if distributing via App Store)
- [ ] Camera usage description in Info.plist: `"BlinkMac needs camera access to record your daily moments"`
- [ ] Microphone usage description in Info.plist: `"BlinkMac needs microphone access to capture audio with your videos"`

---

## Launch Day

- [ ] Final build uploaded to App Store Connect
- [ ] Build processing complete (check App Store Connect)
- [ ] Submission reviewed and submitted for review
- [ ] Release date set (manual or automatic upon approval)
- [ ] TestFlight external tester group notified (if using beta)

---

## Post-Launch

- [ ] Monitor App Store Connect for review status
- [ ] Check for rejection issues — address promptly
- [ ] Announce launch (optional: social media, dev community)
- [ ] Set up analytics (optional: App Store Connect analytics, Mixpanel)
- [ ] Create feedback loop: collect user reviews, file bug reports

---

## Version History

| Version | Date | Notes |
|---------|------|-------|
| 1.0 | TBD | Initial App Store release |
| 1.1 | — | Shared albums with iCloud |
| 1.2 | — | Smart categorization |
