
# 🧾 RecipeVault

**RecipeVault** is a Flutter-based app that transforms cooking screenshots into clean, organised, and categorised recipe cards using OCR and GPT formatting. Built for speed, ease, and no faff.

---

## 🚀 Features

- 📸 Upload multiple screenshots (up to 10)
- 🤖 Google Vision OCR + GPT formatting
- 🗂️ Categorise and filter recipes (e.g. Breakfast, Main, Dessert, Favourites)
- ❤️ Favourite recipes
- 🔍 Grid/List/Compact views
- 🧠 Local storage via Hive
- ☁️ Firebase sync for persistence (Firestore & Storage)
- 🔐 Google Sign-In authentication

---

## 🛠 Getting Started

To run this app locally:

1. **Clone the repo**
   ```bash
   git clone https://github.com/your-username/recipe_vault.git
   cd recipe_vault

	2.	Install dependencies

flutter pub get


	3.	Configure Firebase
	•	Add your google-services.json (Android) and GoogleService-Info.plist (iOS)
	•	Use flutterfire configure to generate firebase_options.dart
	4.	Run the app

flutter run



⸻

📦 Tech Stack
	•	Flutter + Dart
	•	Firebase (Auth, Firestore, Storage, Functions)
	•	Google Cloud Vision API
	•	OpenAI GPT (for recipe formatting)
	•	Hive (local storage)
	•	flutter_speed_dial, go_router, image_picker, flutter_image_compress

⸻

📁 Project Structure

lib/
├── core/                # Theme, global constants
├── model/               # Data models
├── screens/             # UI screens
├── services/            # Firebase, image processing, OCR, GPT etc.
├── widgets/             # Shared UI components
functions/               # Firebase Cloud Functions


⸻

📄 License

MIT

⸻

🧠 Credits

Made with flavour by Cheeky Badger Creations.