# Deploying Cannon Butchery Tracker to GitHub Pages

## Prerequisites
- GitHub repository created (e.g., `cannonbutchery_tracker`)
- Flutter web configured (already done)

## First Time Setup

### 1. Build the app
```bash
./build_web.sh
```

### 2. Initialize git in build/web
```bash
cd build/web
git init
git add .
git commit -m "Initial deploy"
git branch -M gh-pages
```

### 3. Connect to GitHub
Replace `YOUR_USERNAME` with your GitHub username:
```bash
git remote add origin https://github.com/YOUR_USERNAME/cannonbutchery_tracker.git
git push -u origin gh-pages
```

### 4. Enable GitHub Pages
1. Go to your GitHub repository
2. Click **Settings** → **Pages**
3. Under **Source**, select:
   - Branch: `gh-pages`
   - Folder: `/ (root)`
4. Click **Save**

### 5. Configure Firebase Authentication
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project (cannonbutchery)
3. Navigate to **Authentication** → **Settings** → **Authorized domains**
4. Add: `YOUR_USERNAME.github.io`
5. Click **Add domain**

### 6. Access your app
Your app will be available at:
```
https://YOUR_USERNAME.github.io/cannonbutchery_tracker/
```

GitHub Pages takes 1-2 minutes to update after each push.

---

## Updating After Changes

Whenever you make changes to the app:

```bash
# 1. Make sure you're on main with latest changes
git checkout main
git pull origin main

# 2. Build web
flutter build web --release --base-href "/cannon_butchery/"

# 3. Copy build to temp (so it doesn't get deleted when switching branches)
cp -r build/web /tmp/web_deploy

# 4. Switch to gh-pages and deploy
git checkout gh-pages
cp -r /tmp/web_deploy/* .
git add .
git commit -m "Deploy: describe your changes"
git push origin gh-pages

# 5. Switch back to main
git checkout main
```

Wait 1-2 minutes, then refresh your app in the browser (Cmd+Shift+R for hard refresh).

**Note:** Your gh-pages is a branch in the main repo, not a separate directory. The temp copy step prevents build files from disappearing when switching branches.

---

## Troubleshooting

### "Firebase: No Firebase App '[DEFAULT]' has been created"
- Check that web/index.html has the Firebase scripts
- Verify Firebase config is correct
- Clear browser cache and try again

### Google Sign-In popup blocked
- Allow popups for your GitHub Pages domain
- Check browser console for errors

### 404 on GitHub Pages
- Verify the repository has a `gh-pages` branch
- Check GitHub Pages settings show the correct source
- Wait 2-3 minutes after first setup

### Permission denied accessing data
- Verify Firestore rules allow your email
- Check Firebase Console → Authentication → Authorized domains includes `YOUR_USERNAME.github.io`
- Make sure you're signed in with the authorized email (munenevincent49@gmail.com)
