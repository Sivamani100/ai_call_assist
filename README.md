# AI Call Assistant - Complete Setup Guide
## Exotel Edition - Indian Deployment

This guide will walk you through setting up the complete AI Call Assistant system. Follow each step carefully to ensure everything works properly.

## 📋 Prerequisites

Before starting, you'll need accounts for these services:

### 1. **Exotel** (Indian Virtual Number)
- Go to [exotel.com](https://exotel.com)
- Sign up with business email
- Complete KYC (PAN + business proof)
- Purchase a mobile DID (+91 number)
- Enable Media Streaming feature

### 2. **Anthropic Claude** (AI Conversations)
- Go to [console.anthropic.com](https://console.anthropic.com)
- Create account and get API key
- Ensure access to `claude-haiku-4-5` model

### 3. **Deepgram** (Speech-to-Text)
- Go to [deepgram.com](https://deepgram.com)
- Create account and get API key
- Ensure Nova-2 model access

### 4. **ElevenLabs** (Text-to-Speech)
- Go to [elevenlabs.io](https://elevenlabs.io)
- Create account and get API key
- Note the Voice ID for Rachel voice: `21m00Tcm4TlvDq8ikWAM`

### 5. **Supabase** (Database)
- Go to [supabase.com](https://supabase.com)
- Create new project
- Get project URL and anon key

### 6. **Firebase** (Push Notifications)
- Go to [console.firebase.google.com](https://console.firebase.google.com)
- Create project
- Add Android app with package `com.siva.ai_call_assistant`
- Download `google-services.json`
- Generate service account key for FCM

### 7. **Railway** (Backend Hosting)
- Go to [railway.app](https://railway.app)
- Create account and connect GitHub

---

## 🚀 Step 1: Set Up Database (Supabase)

1. **Create Tables**: Go to your Supabase project → SQL Editor → Run this SQL:

```sql
-- Run this complete SQL in Supabase SQL Editor
CREATE TABLE IF NOT EXISTS call_logs (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  exotel_call_sid     TEXT UNIQUE,
  caller_number       TEXT NOT NULL,
  caller_name         TEXT,
  caller_relationship TEXT DEFAULT 'unknown',
  is_known_contact    BOOLEAN DEFAULT false,
  call_start_time     TIMESTAMPTZ DEFAULT NOW(),
  call_duration_sec   INTEGER DEFAULT 0,
  call_type           TEXT DEFAULT 'routine',
  ai_summary          TEXT,
  full_transcript     JSONB,
  key_details         TEXT[],
  urgency_level       TEXT DEFAULT 'low',
  action_needed       TEXT,
  recommended_response TEXT,
  deadline            TEXT,
  should_call_back    BOOLEAN DEFAULT false,
  status              TEXT DEFAULT 'new',
  created_at          TIMESTAMPTZ DEFAULT NOW(),
  updated_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS fcm_tokens (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fcm_token   TEXT UNIQUE NOT NULL,
  device_id   TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS contacts (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone       TEXT UNIQUE NOT NULL,
  name        TEXT NOT NULL,
  is_vip      BOOLEAN DEFAULT false,
  notes       TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS settings (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key        TEXT UNIQUE NOT NULL,
  value      TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO settings (key, value) VALUES
  ('ai_mode', 'false'),
  ('owner_name', 'Siva'),
  ('exotel_number', '+918047123456'),
  ('ai_personality', 'professional')
ON CONFLICT (key) DO NOTHING;

CREATE INDEX IF NOT EXISTS idx_call_logs_status   ON call_logs(status);
CREATE INDEX IF NOT EXISTS idx_call_logs_created  ON call_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_call_logs_urgency  ON call_logs(urgency_level);
CREATE INDEX IF NOT EXISTS idx_contacts_phone     ON contacts(phone);

ALTER PUBLICATION supabase_realtime ADD TABLE call_logs;
```

2. **Add Sample Contacts** (optional):
```sql
-- Add some test contacts
INSERT INTO contacts (phone, name, is_vip, notes) VALUES
  ('+919876543210', 'Rahul Kumar', true, 'Colleague - Project Manager'),
  ('+919876543211', 'Priya Sharma', false, 'Client - Marketing Director')
ON CONFLICT (phone) DO NOTHING;
```

---

## 🚀 Step 2: Deploy Backend (Railway.app)

1. **Create GitHub Repository**:
   - Create new repo: `ai-call-assistant-backend`
   - Upload the `ai_call_backend/` folder contents
   - Include `.env.example` (rename to `.env` after setup)

2. **Railway Deployment**:
   - Go to Railway → New Project → Deploy from GitHub
   - Select your repository
   - Railway will auto-detect Python and deploy

3. **Environment Variables** (Railway → Project → Variables):
   ```
   EXOTEL_API_KEY=your_exotel_api_key
   EXOTEL_API_TOKEN=your_exotel_api_token
   EXOTEL_ACCOUNT_SID=your_exotel_account_sid
   EXOTEL_PHONE_NUMBER=+918047123456
   EXOTEL_SUBDOMAIN=your_exotel_account_sid

   ANTHROPIC_API_KEY=sk-ant-api03-your_key
   DEEPGRAM_API_KEY=your_deepgram_key
   ELEVENLABS_API_KEY=sk_your_elevenlabs_key
   ELEVENLABS_VOICE_ID=21m00Tcm4TlvDq8ikWAM

   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIs...your_key

   FIREBASE_CREDENTIALS_PATH=./firebase-credentials.json
   BACKEND_URL=https://your-railway-app.railway.app
   OWNER_NAME=Siva
   OWNER_PHONE=+919876543210
   PORT=8080
   ```

4. **Upload Firebase Credentials**:
   - Railway → Project → Files → Upload `firebase-credentials.json`
   - Place it in project root

5. **Verify Deployment**: Visit `https://your-app.railway.app/health`
   - Should return: `{"status": "ok", "service": "AI Call Assistant", "version": "1.0.0", "telephony": "Exotel"}`

---

## 🚀 Step 3: Configure Exotel

1. **Virtual Number Setup**:
   - Exotel Console → ExoPhones → Your number
   - Click "Applet" → Configure
   - Set webhook: `https://your-app.railway.app/incoming-call`
   - Fallback URL: Same as above

2. **Enable Media Streaming**:
   - Exotel Console → Settings → Products → Media Stream → Enable
   - Note: Requires Business account verification

3. **Test Webhook**: Call your Exotel number directly
   - Should hear AI greeting
   - Check Railway logs for webhook reception

---

## 🚀 Step 4: Configure Flutter App

1. **Update Constants** (`lib/core/constants.dart`):
   ```dart
   class AppConstants {
     static const String supabaseUrl    = 'https://your-project.supabase.co';
     static const String supabaseAnonKey = 'your-anon-key';
     static const String backendUrl      = 'https://your-railway-app.railway.app';
     static const String exotelNumber    = '+918047123456';  // Your Exotel number
   }
   ```

2. **Firebase Setup**:
   - Place `google-services.json` in `android/app/`
   - Firebase Console → Project Settings → Add Android app
   - Package name: `com.siva.ai_call_assistant`

3. **Build APK**:
   ```bash
   cd ai_call_assistant
   flutter pub get
   flutter build apk --release
   ```

4. **Install APK**: Transfer `build/app/outputs/flutter-apk/app-release.apk` to your Android phone

---

## 🚀 Step 5: Enable Call Forwarding

1. **Install App**: Install the APK on your Android phone

2. **Grant Permissions**: Open app → Allow all permissions

3. **Setup Forwarding**:
   - Open AI Call Assistant app
   - Go to Settings → Verify Exotel number is correct
   - Return to Home → Toggle "AI Mode: ON"
   - App will dial USSD: `*21*%2B918047123456%23`
   - Carrier enables forwarding

4. **Test Forwarding**:
   - Have someone call your real SIM number
   - Call should forward to Exotel → AI answers
   - Check app for notification and call log

---

## 🔄 How It Works

### Call Flow:
1. **Incoming Call**: Someone calls your SIM → Carrier forwards to Exotel
2. **AI Answers**: Exotel streams audio to backend → STT converts to text
3. **AI Conversation**: Claude processes conversation → Generates response
4. **AI Speaks**: ElevenLabs converts response to speech → Streams back
5. **Call Ends**: Backend saves transcript → Sends push notification
6. **App Updates**: Flutter app shows call log with full transcript

### Conversation Scenarios:
- **Spam Calls**: AI politely declines ("not interested, thank you")
- **Known Contacts**: AI greets by name ("Hi Rahul, how can I help?")
- **Urgent Calls**: AI flags as urgent, collects all details
- **Routine Calls**: AI gathers info, summarizes for you

### Reply System:
- **View Call**: Tap notification or call log → See full transcript
- **AI Reply**: Tap "Reply via AI" → Type message → AI calls back with your message
- **Mark Actions**: Mark as read, replied, blocked, or done

---

## 🧪 Testing Checklist

### Backend Tests:
- [ ] `curl https://your-app.railway.app/health` → Status OK
- [ ] Direct Exotel call → AI greeting works
- [ ] Webhook logs show call processing

### App Tests:
- [ ] App launches without errors
- [ ] Permissions granted (phone, contacts, notifications)
- [ ] AI Mode toggle works (USSD dialing)
- [ ] Forwarded call appears in app

### End-to-End Tests:
- [ ] Call real number → AI answers → Conversation works
- [ ] Notification received → Tap opens call details
- [ ] Transcript shows full conversation
- [ ] AI Reply → AI calls back with your message

---

## 🐛 Troubleshooting

### Common Issues:

**APK Build Fails:**
```bash
flutter clean
flutter pub get
flutter build apk --release
```

**No AI Greeting on Direct Call:**
- Check Railway logs for webhook errors
- Verify environment variables
- Test `/health` endpoint

**Forwarding Not Working:**
- Check USSD code: `*21*%2B918047123456%23`
- Verify carrier supports conditional forwarding
- Check forwarding status: `*#21#`

**No Push Notifications:**
- Verify Firebase credentials
- Check FCM token saved in Supabase
- Test with Firebase console

**AI Not Responding:**
- Check Deepgram API key and credits
- Verify Claude API access
- Check ElevenLabs voice ID

---

## 📱 User Guide

### Daily Use:
1. **Enable AI Mode**: Toggle ON when you want AI to answer calls
2. **Receive Calls**: Get notified when AI handles calls
3. **Review Calls**: Check transcripts and decide next actions
4. **Reply**: Use AI to call back with your message
5. **Manage Contacts**: Add important numbers for personalized greetings

### Call Types Handled:
- ✅ **Spam/Sales**: Politely declined
- ✅ **Known Contacts**: Personalized greeting
- ✅ **Urgent Matters**: Flagged for immediate attention
- ✅ **Routine Business**: Information collected and summarized

---

## 🎯 Expected Behavior

When someone calls your number:
1. **Phone doesn't ring** (forwarded to Exotel)
2. **AI answers immediately** with personalized greeting
3. **Natural conversation** flows back and forth
4. **Call ends gracefully** when appropriate
5. **Notification appears** on your phone
6. **App shows transcript** in chat format
7. **You decide** to reply via AI, call back yourself, or ignore

The system is now ready for production use! 🚀📞🤖
