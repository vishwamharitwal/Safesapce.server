# Security Fixes Plan - Top 5 CRITICAL

## Scope
Fix the 5 most critical security vulnerabilities before Play Store launch.
Some fixes are Flutter-only, some require Supabase backend changes.

---

## Fix 1: Enable R8 Obfuscation + Remove Hardcoded Secrets

### 1a. Enable R8 in build.gradle.kts
**File**: `android/app/build.gradle.kts`

Add to release buildType:
```kotlin
buildTypes {
    release {
        isMinifyEnabled = true
        isShrinkResources = true
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro"
        )
        signingConfig = signingConfigs.getByName("release")
    }
}
```

### 1b. Remove hardcoded secrets from app_config.dart
**File**: `lib/core/config/app_config.dart`

Change all `defaultValue` to empty strings so missing `--dart-define` crashes in release:
- `supabaseUrl` → `defaultValue: ''`
- `supabaseAnonKey` → `defaultValue: ''`
- `signalingServerUrl` → `defaultValue: ''`
- `googleWebClientId` → `defaultValue: ''`

### 1c. Update .gitignore
**File**: `.gitignore`

Add missing entries:
```
.env.*
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
```

### 1d. Create proguard-rules.pro
**File**: `android/app/proguard-rules.pro` (NEW)

Minimal rules to keep Flutter/Supabase classes:
```
-keep class io.flutter.** { *; }
-keep class com.supabase.** { *; }
-keep class io.flutter.plugins.** { *; }
```

---

## Fix 2: RLS on Connections Table (Backend SQL)

This is a Supabase backend change. Provide SQL to run in Supabase SQL Editor:

```sql
-- Enable RLS on connections table
ALTER TABLE connections ENABLE ROW LEVEL SECURITY;

-- Users can read their own connections
CREATE POLICY "Users can read own connections" ON connections
  FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

-- Users can insert connections where they are the sender
CREATE POLICY "Users can send connection requests" ON connections
  FOR INSERT WITH CHECK (auth.uid() = sender_id);

-- Only receiver can accept (update status)
CREATE POLICY "Receiver can update connection" ON connections
  FOR UPDATE USING (auth.uid() = receiver_id);

-- Users can delete their own connections
CREATE POLICY "Users can delete own connections" ON connections
  FOR DELETE USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

-- RLS for thoughts delete (owner only)
CREATE POLICY "Users can delete own thoughts" ON thoughts
  FOR DELETE USING (auth.uid() = user_id);

-- Rating RPC function (atomic update, no race condition)
CREATE OR REPLACE FUNCTION submit_rating(target_id UUID, stars INT, tag TEXT DEFAULT NULL)
RETURNS VOID AS $$
BEGIN
  UPDATE profiles SET
    rating = CASE 
      WHEN total_talks = 0 THEN stars::FLOAT
      ELSE (rating * total_talks + stars) / (total_talks + 1)
    END,
    total_talks = total_talks + 1
  WHERE id = target_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

Also add Flutter-side RPC call for rating:
**File**: `lib/features/session/presentation/pages/post_session_screen.dart`

Replace the read-modify-write pattern with:
```dart
await client.rpc('submit_rating', params: {
  'target_id': widget.partnerId,
  'stars': _starRating,
  'tag': _selectedTag,
});
```

---

## Fix 3: Age Verification + Data Deletion

### 3a. Add age check at signup
**File**: `lib/features/auth/presentation/pages/signup_screen.dart`

Add date of birth field to signup form. Block users under 13.
For 13-17, show parental consent notice.

### 3b. Add Delete Account button
**File**: `lib/features/profile/presentation/pages/profile_screen.dart`

Add "Delete Account" button in settings that:
1. Shows confirmation dialog
2. Calls Supabase RPC `delete_user_account`
3. Signs out and navigates to login

### 3c. Supabase RPC for account deletion (Backend)
```sql
CREATE OR REPLACE FUNCTION delete_user_account()
RETURNS VOID AS $$
DECLARE
  uid UUID := auth.uid();
BEGIN
  DELETE FROM thought_comments WHERE user_id = uid;
  DELETE FROM thoughts WHERE user_id = uid;
  DELETE FROM messages WHERE sender_id = uid;
  DELETE FROM user_ratings WHERE rater_id = uid;
  DELETE FROM connections WHERE sender_id = uid OR receiver_id = uid;
  DELETE FROM profiles WHERE id = uid;
  -- Note: auth.users deletion requires admin/service_role
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## Fix 4: Server-Side Profanity/Crisis Filtering

### 4a. Supabase Edge Function (Backend)
Create Edge Function `validate-content` that:
1. Receives content + content_type (thought/comment/message)
2. Runs profanity filter server-side
3. Runs crisis detection server-side
4. Returns sanitized content or rejection reason

### 4b. Supabase Database Trigger
Create trigger on `thoughts`, `thought_comments`, `messages` tables:
```sql
CREATE OR REPLACE FUNCTION validate_content_trigger()
RETURNS TRIGGER AS $$
BEGIN
  -- Check length
  IF length(NEW.content) > 2000 THEN
    RAISE EXCEPTION 'Content too long';
  END IF;
  
  -- Check for crisis keywords (basic server-side check)
  IF NEW.content ~* '(suicide|kill myself|end my life|want to die|no reason to live)' THEN
    -- Log for moderator review but still allow (or block based on policy)
    INSERT INTO crisis_flags (user_id, content_type, content, created_at)
    VALUES (NEW.user_id, TG_TABLE_NAME, NEW.content, now());
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

### 4c. Flutter-side: Add profanity filter to chat
**File**: `lib/features/chat/presentation/pages/chat_room_screen.dart`

Add before `_supabase.from('messages').insert(...)`:
```dart
final filter = ProfanityFilter();
final filterError = filter.validate(text);
if (filterError != null) {
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(filterError)),
    );
  }
  return;
}
```

### 4d. Flutter-side: Block posting on crisis detection
**Files**: `thoughts_screen.dart`, `comment_sheet.dart`, `chat_room_screen.dart`

Change crisis handling from "show dialog + still post" to "show dialog + BLOCK post":
```dart
if (CrisisManager.isCrisis(content)) {
  CrisisManager.showCrisisDialog(context);
  return; // ← ADD THIS LINE to block the post
}
```

---

## Fix 5: Socket.IO Auth + Remove Secrets from Git

### 5a. Add JWT to Socket.IO handshake
**File**: `lib/features/session/data/signaling_service.dart`

In `connect()` method, pass Supabase JWT:
```dart
final jwt = Supabase.instance.client.auth.currentSession?.accessToken;
socket = io.io(serverUrl, <String, dynamic>{
  'transports': ['websocket'],
  'autoConnect': false,
  'auth': {'token': jwt ?? ''},
  // ... rest of options
});
```

### 5b. Remove TURN hardcoded credentials
**File**: `lib/features/session/data/signaling_service.dart`

Remove default TURN credentials. Fetch from server on connect:
```dart
// Remove hardcoded openrelay credentials
// Fetch ephemeral TURN credentials from your signaling server
static Map<String, dynamic> _rtcConfig = {
  'iceServers': [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
  ],
  'sdpSemantics': 'unified-plan',
  'iceCandidatePoolSize': 10,
};

Future<void> _fetchTurnCredentials() async {
  // Call your server to get time-limited TURN creds
  final response = await http.get(Uri.parse('$serverUrl/turn-credentials'));
  final data = jsonDecode(response.body);
  _rtcConfig['iceServers'].addAll(data['iceServers']);
}
```

### 5c. Remove secrets from git
User must run manually:
```bash
git rm --cached .env
git rm --cached android/app/google-services.json
git commit -m "Remove tracked secrets"
```

---

## Files Modified (Flutter side)
1. `android/app/build.gradle.kts` - R8 obfuscation
2. `lib/core/config/app_config.dart` - Remove hardcoded defaults
3. `.gitignore` - Add missing entries
4. `android/app/proguard-rules.pro` - NEW file
5. `lib/features/session/presentation/pages/post_session_screen.dart` - Use RPC for rating
6. `lib/features/chat/presentation/pages/chat_room_screen.dart` - Add profanity filter
7. `lib/features/community/presentation/pages/thoughts_screen.dart` - Block crisis posts
8. `lib/features/community/presentation/widgets/comment_sheet.dart` - Block crisis posts
9. `lib/features/session/data/signaling_service.dart` - Socket.IO auth + TURN creds

## Files NOT Modified (require manual backend work)
- Supabase RLS policies (SQL to run in dashboard)
- Supabase RPC functions (SQL to run in dashboard)
- Supabase Edge Functions (deploy via CLI)
- Git operations (user must run manually)
