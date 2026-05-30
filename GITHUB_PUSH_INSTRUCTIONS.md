# How to Push to GitHub from Replit (Mobile-Friendly)

Complete step-by-step. Takes about 5 minutes.

---

## PART A — Create a GitHub Repository (do this on your phone browser)

1. Open **github.com** in your mobile browser and log in.
2. Tap the **"+"** icon (top right) → **"New repository"**.
3. Fill in:
   - **Repository name:** `dopamine-detox-app`
   - **Visibility:** Private (recommended — protects your code)
   - ❌ Do NOT tick "Add a README" or any other checkbox
4. Tap **"Create repository"**.
5. On the next screen, copy the URL shown — it will look like:
   ```
   https://github.com/YOUR_USERNAME/dopamine-detox-app.git
   ```
   Keep this tab open.

---

## PART B — Generate a GitHub Personal Access Token

GitHub requires a token (password) for pushing from external tools.

1. Go to: **github.com → your profile photo → Settings**
2. Scroll all the way down → **"Developer settings"** (left sidebar)
3. **Personal access tokens → Tokens (classic) → Generate new token (classic)**
4. Fill in:
   - **Note:** `Replit Push`
   - **Expiration:** 90 days (or No expiration)
   - **Scopes:** tick ✅ **repo** (the very first checkbox — this covers all sub-items)
5. Scroll down → **"Generate token"**
6. **COPY the token immediately** — GitHub will never show it again.
   It looks like: `ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

---

## PART C — Push from Replit (use the Shell tab)

In Replit, tap **"Shell"** at the bottom of the screen, then run these
commands one by one. Replace the placeholders with your real values.

```bash
# 1. Go into the Flutter project folder
cd flutter_dopamine_detox

# 2. Initialise git
git init

# 3. Set your GitHub identity (use your real name & email)
git config user.name "Your Name"
git config user.email "you@example.com"

# 4. Stage all files
git add .

# 5. First commit
git commit -m "Initial commit — Dopamine Detox Flutter app"

# 6. Rename branch to main
git branch -M main

# 7. Add your GitHub repo as remote
#    Replace YOUR_USERNAME and YOUR_TOKEN with your real values
git remote add origin https://YOUR_TOKEN@github.com/YOUR_USERNAME/dopamine-detox-app.git

# 8. Push!
git push -u origin main
```

**Example of step 7 with real values:**
```bash
git remote add origin https://ghp_AbCdEfGhIjKlMnOpQrStUv@github.com/rahul123/dopamine-detox-app.git
```

If it succeeds you will see:
```
Branch 'main' set up to track remote branch 'main' from 'origin'.
```

---

## PART D — Trigger the Build & Download your APK/AAB

1. Go to **github.com/YOUR_USERNAME/dopamine-detox-app**
2. Tap the **"Actions"** tab
3. You will see **"Flutter Build — APK & AAB"** already running
   (it starts automatically on every push)
4. Tap the running job → wait ~10–15 minutes for it to finish
5. When it shows a green ✅, scroll down to **"Artifacts"**
6. Tap to download:
   - `DopamineDetox_YYYYMMDD_HHMM.apk` → install on your Android phone
   - `DopamineDetox_YYYYMMDD_HHMM.aab` → upload to Google Play Console

---

## PART E — Install APK directly on your Android phone

1. Download the `.apk` from GitHub Actions to your phone
2. Open your phone **Settings → Security → Install unknown apps**
   → allow your browser
3. Tap the downloaded `.apk` file → Install

---

## PART F — Add Keystore secrets (for Play Store signed build)

After your first successful build, add your signing credentials so the
AAB is properly signed for Play Store submission.

In GitHub → your repo → **Settings → Secrets and variables → Actions**
→ **New repository secret** — add these one by one:

| Secret name | Value |
|---|---|
| `KEYSTORE_BASE64` | Output of: `base64 android/keystore/upload-keystore.jks` |
| `KEY_STORE_PASSWORD` | Your keystore password |
| `KEY_PASSWORD` | Your key password |
| `KEY_ALIAS` | `upload` |

Then push any small change (e.g. edit a comment) to trigger a new build.
The next AAB will be fully signed with your upload key.

---

## Troubleshooting

| Error | Fix |
|---|---|
| `remote: Invalid credentials` | Re-check your token — regenerate if needed |
| `failed to push some refs` | Run `git pull origin main --rebase` first |
| Build fails on `flutter pub get` | Check pubspec.yaml has no tab characters |
| `Keystore file not found` | KEYSTORE_BASE64 secret not set — first build uses debug signing (still works for testing) |
