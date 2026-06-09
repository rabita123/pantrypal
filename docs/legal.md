# PantryPal — Legal Documents

**Privacy Policy:** https://sites.google.com/view/pantrypal-app/privacy-policy
**Terms of Service:** https://sites.google.com/view/pantrypal-app/terms-of-service

---

## Privacy Policy

**Effective Date:** May 30, 2026
**Last Updated:** June 6, 2026

### 1. Overview

PantryPal ("we", "us", or "our") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, and safeguard information when you use the PantryPal mobile application ("App"). By using the App, you agree to the practices described in this policy.

### 2. Information We Collect

#### 2.1 Information You Provide
- Pantry items, food inventory, and expiry dates you manually enter.
- Receipt images you capture or upload for scanning.
- Fridge photos you capture when using the AI fridge analysis feature.

#### 2.2 Information Collected Automatically
- **Camera data (receipt scan):** When you scan a receipt, the image is sent to our secure Supabase cloud servers for processing via Claude AI. If your device is offline, processing falls back to on-device ML Kit OCR and no image is uploaded.
- **Camera data (fridge scan & recipe generation):** Fridge photos and pantry data are sent to our secure Supabase cloud servers for processing via Claude AI. See Section 5 for details.
- **Local notifications:** We use your device's notification system to send expiry reminders. No notification data is shared externally.
- **Purchase data:** If you subscribe to PantryPal Premium, your subscription is managed by RevenueCat. RevenueCat may collect purchase identifiers and subscription status. See their privacy policy at https://www.revenuecat.com/privacy.
- **App usage data:** We do not collect analytics, crash reports, or usage telemetry beyond what is described in this policy.

#### 2.3 Information We Do NOT Collect
- We do not collect your name, email address, or any account credentials for core features.
- We do not collect location data.
- We do not collect contacts, microphone input, or health data.
- We do not use advertising networks or tracking SDKs.

### 3. How We Use Your Information

| Data | Where Processed | Purpose |
|---|---|---|
| Manually entered pantry data | On-device only | Display inventory, send expiry reminders |
| Receipt photos (scan feature) | Supabase servers + Claude AI (primary); on-device ML Kit (offline fallback) | Extract food items from receipt |
| Fridge photos (AI fridge scan) | Supabase servers + Claude AI | Identify food items in your fridge |
| Pantry contents (AI recipe generation) | Supabase servers + Claude AI | Generate personalised recipe suggestions |
| Subscription status | RevenueCat servers | Manage Premium access |

### 4. AI Features and Data Processing

When you use AI-powered features (AI Fridge Scan, Generate Recipe), the relevant data (fridge image or pantry item list) is transmitted over an encrypted HTTPS connection to our Supabase Edge Functions, which use Anthropic Claude AI to generate a response. This data is:

- Used solely to generate your requested result.
- Not stored on our servers after the response is returned.
- Not used to train AI models.
- Not shared with any third party beyond the processing pipeline described above.

You can choose not to use AI features; all core pantry tracking and receipt scanning works entirely on-device.

### 5. Third-Party Services

| Service | Purpose | Data Sent |
|---|---|---|
| Google ML Kit (on-device) | Offline fallback OCR for receipts | Nothing — on-device only |
| Supabase Edge Functions | Receipt scanning, fridge analysis, recipe generation | Receipt photos, fridge images, pantry lists |
| Anthropic Claude AI | Receipt OCR, fridge analysis, recipe generation | Receipt photos, fridge images, pantry lists (via Supabase) |
| RevenueCat | Subscription management | Purchase identifiers |
| Flutter Local Notifications | Expiry reminder notifications | Nothing — on-device only |

### 6. Data Storage and Security

- All pantry data is stored on-device using encrypted local device storage.
- Data sent for AI features is transmitted over HTTPS and is not retained on our servers.
- Subscription data is managed by RevenueCat under their security standards.
- If you delete the App, all locally stored data is permanently removed from your device.

### 7. Children's Privacy

PantryPal is not directed at children under 13. We do not knowingly collect personal information from children. If you believe a child has provided personal data through the App, please contact us so we can remove it.

### 8. Your Rights

- **Access:** View all your pantry data directly within the App.
- **Deletion:** Delete individual items within the App, or uninstall the App to remove all local data.
- **AI data:** AI feature data is not retained on our servers; there is nothing to delete after the response is delivered.
- **Subscription:** Manage or cancel your subscription at any time through your Apple ID account settings.

### 9. Changes to This Policy

We may update this Privacy Policy from time to time. We will notify you of significant changes by updating the "Last Updated" date above. Continued use of the App after changes constitutes acceptance of the updated policy.

### 10. Contact Us

**Email:** tasmin.saira@gmail.com

---

## Terms and Conditions

**Effective Date:** May 30, 2026
**Last Updated:** June 6, 2026

### 1. Acceptance of Terms

By downloading, installing, or using PantryPal ("App"), you agree to be bound by these Terms and Conditions ("Terms"). If you do not agree to these Terms, do not use the App.

### 2. License

We grant you a limited, non-exclusive, non-transferable, revocable license to use the App for personal, non-commercial purposes on a device you own or control, subject to these Terms and the Apple App Store terms of service.

### 3. Description of Service

PantryPal is a personal pantry management tool that helps you:
- Track food items and their expiry dates.
- Scan grocery receipts using your device camera to populate your pantry.
- Scan product barcodes to add items.
- Use AI to identify food items from a fridge photo (Premium).
- Discover and generate personalised recipes using AI (Premium).
- Manage a smart shopping list.
- Plan kids' meals.
- Receive local push notifications when items are nearing expiry.

The App is provided for personal use only and is not intended for commercial food inventory management.

### 4. User Responsibilities

You agree to:
- Use the App only for lawful purposes.
- Not attempt to reverse-engineer, decompile, or modify the App.
- Not use the App in any way that could damage, disable, or impair the App or our servers.
- Not attempt to circumvent subscription restrictions or access Premium features without a valid subscription.

### 5. Accuracy of Information

PantryPal uses on-device OCR and AI to parse receipts and analyse fridge contents. Results may not always be accurate due to image quality, receipt formatting, lighting conditions, and the inherent limitations of AI models. You are responsible for reviewing and correcting any auto-populated pantry data. We make no guarantee of accuracy of scanned or AI-generated results.

**You should not rely solely on this App to make food safety decisions.** Always use your own judgement when determining whether food is safe to consume.

### 6. Subscription and Payment Terms

#### 6.1 Premium Subscription

PantryPal offers an optional Premium subscription that unlocks additional features including AI-powered fridge scanning, AI recipe generation, and unlimited pantry items. A free tier with core features is available without a subscription.

#### 6.2 Pricing

Subscription prices are displayed in the App before purchase, in your local currency as determined by the Apple App Store. Prices may vary by region and are subject to change. Available plans may include weekly, monthly, and annual billing options.

#### 6.3 Free Trial

Where offered, a free trial period will be clearly indicated before purchase. If you do not cancel before the end of the free trial period, your subscription will automatically convert to a paid subscription at the displayed price.

#### 6.4 Billing and Renewal

- Subscriptions are billed through your Apple ID account via the Apple App Store.
- Subscriptions automatically renew at the end of each billing period unless cancelled at least 24 hours before the renewal date.
- Your Apple ID account will be charged for renewal within 24 hours prior to the end of the current period.
- You can manage and cancel your subscription at any time in your Apple ID Account Settings (Settings → [your name] → Subscriptions).

#### 6.5 Cancellations and Refunds

- You may cancel your subscription at any time. Cancellation takes effect at the end of the current billing period; you retain Premium access until then.
- We do not offer refunds for partial subscription periods. All purchases are final unless required by applicable law.
- Refund requests for exceptional circumstances may be submitted to Apple directly, as all payments are processed by the Apple App Store.

#### 6.6 Price Changes

We reserve the right to change subscription pricing at any time. You will be notified of price changes in advance and given the opportunity to cancel before the new price takes effect.

### 7. Disclaimer of Warranties

THE APP IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT.

We do not warrant that:
- The App will be uninterrupted or error-free.
- Expiry date reminders will always be delivered on time (delivery depends on your device's notification settings).
- Receipt scanning or AI analysis will be accurate.
- AI-generated recipes are nutritionally appropriate for all users.

### 8. Limitation of Liability

TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, WE SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES ARISING OUT OF OR RELATED TO YOUR USE OF THE APP, INCLUDING BUT NOT LIMITED TO LOSS OF DATA, FOODBORNE ILLNESS, OR FOOD WASTE, EVEN IF WE HAVE BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.

Our total liability to you for any claims arising from these Terms or the App shall not exceed the total amount you paid for the App or a Premium subscription in the twelve (12) months preceding the claim.

### 9. Intellectual Property

All content, design, code, and branding within PantryPal are owned by us or our licensors and are protected by applicable intellectual property laws. You may not reproduce, distribute, or create derivative works without our express written permission.

### 10. Termination

We reserve the right to discontinue the App at any time without notice. You may stop using the App at any time by deleting it from your device. Upon termination, your license to use the App immediately ceases. Active subscriptions will continue until the end of the paid period.

### 11. Governing Law

These Terms are governed by and construed in accordance with the laws of your country of residence, without regard to conflict of law principles. Any disputes shall be resolved in the courts of competent jurisdiction in your location.

### 12. Changes to Terms

We may update these Terms from time to time. We will notify you of significant changes by updating the "Last Updated" date above. Continued use of the App after changes constitutes acceptance of the updated Terms.

### 13. Contact Us

**Email:** tasmin.saira@gmail.com

---

*PantryPal — Reduce food waste, one pantry at a time.*
