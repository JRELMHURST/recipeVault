
# 🧾 RecipeVault

**RecipeVault** is a Flutter app that transforms screenshots of handwritten or printed recipes into clean, organised, and categorised recipe cards — using OCR, GPT formatting, and automatic translation. Built for home cooks who want speed, clarity, and no faff.

---

## 🚀 Features

- 📸 Upload 1–10 recipe screenshots
- 🔍 Google Cloud Vision OCR
- ✨ GPT-powered recipe formatting
- 🌍 Optional auto-translation to UK English
- 🗂️ Smart category assignment (e.g. Breakfast, Dessert)
- ❤️ Favourite and filter your recipes
- 🧠 Offline storage (Hive)
- ☁️ Cloud sync (Firestore & Storage)
- 🔐 Google Sign-In & Apple Sign-In
- 🧑‍🍳 Tiered access via RevenueCat (Free, Taster, Home Chef, Master Chef)
- ⭐ Special access override for family/testers (via Firestore)
- 🖼️ Add & crop images to recipes
- 🧭 Grid, list, and compact recipe views
- 🛠️ Developer tools & onboarding flows

---

## 🧑‍🍳 Subscription Tiers

| Tier         | Features                                                                 |
|--------------|--------------------------------------------------------------------------|
| **Free**     | Offline saving only                                                     |
| **Taster**   | 5 AI recipes + 1 translation (lifetime)                                 |
| **Home Chef**| 20 AI recipes/mo, 5 translations/mo, cloud sync, categories             |
| **Master Chef** | Unlimited recipes, translations, uploads, categories, and storage   |

---

## 🛠 Getting Started

To run this app locally:

```bash
git clone https://github.com/your-username/recipe_vault.git
cd recipe_vault
flutter pub get

📦 Firebase Setup
	1.	Add your Firebase config files:
	•	android/app/google-services.json
	•	ios/Runner/GoogleService-Info.plist
	2.	Run FlutterFire to generate firebase_options.dart:

flutterfire configure

	3.	Launch the app:

flutter run


⸻

📦 Tech Stack
	•	Flutter + Dart
	•	Firebase (Auth, Firestore, Storage, Functions)
	•	Google Cloud Vision API (Document Text Detection)
	•	OpenAI GPT (formatting + category tagging)
	•	RevenueCat (subscriptions)
	•	Hive (offline/local caching)
	•	GoRouter, Image Picker, Flutter Image Compress, Provider

⸻

📁 Project Structure

lib/
├── core/                # Themes, typography, constants
├── model/               # Data models (recipes, categories)
├── screens/             # Home, Vault, Onboarding, Settings
├── services/            # Firebase, Vision OCR, GPT, RevCat, storage
├── widgets/             # Reusable UI widgets (RecipeCard, TimelineStep, etc.)
├── rev_cat/             # RevenueCat logic & UI
functions/               # Firebase Cloud Functions (OCR, GPT, tiering)


⸻

🛡️ Firestore Structure
	•	users/{uid} → profile, tier, specialAccess, trial flags
	•	users/{uid}/recipes/{recipeId} → saved recipe cards
	•	global_recipes/{recipeId} → default shared recipes
	•	users/{uid}/hiddenGlobalRecipes/{id} → soft-hidden defaults

⸻

📄 License

MIT – free to use and modify.

⸻

🧠 Credits

Made by Cheeky Badger Creations 🇬🇧