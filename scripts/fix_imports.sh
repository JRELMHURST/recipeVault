#!/bin/zsh
set -euo pipefail

echo "🔧 Updating import paths across lib/**/*.dart …"

# Helper: run a sed replacement across all Dart files
replace() {
  local from="$1"
  local to="$2"
  # BSD sed on macOS: -i '' for in-place
  find lib -type f -name "*.dart" -print0 | xargs -0 sed -i '' "s#${from}#${to}#g"
  echo "  • ${from}  →  ${to}"
}

# ──────────────────────────────────────────────────────────────────────────────
# DATA LAYER (package: imports)
# ──────────────────────────────────────────────────────────────────────────────
replace 'package:recipe_vault/services/' 'package:recipe_vault/data/services/'
replace 'package:recipe_vault/model/'     'package:recipe_vault/data/models/'
replace 'package:recipe_vault/models/'    'package:recipe_vault/data/models/'

# Vault repository anywhere (old or misplaced)
replace 'package:recipe_vault/vault_repository.dart' \
        'package:recipe_vault/data/repositories/vault_repository.dart'
replace 'package:recipe_vault/features/recipe_vault/vault_repository.dart' \
        'package:recipe_vault/data/repositories/vault_repository.dart'

# ──────────────────────────────────────────────────────────────────────────────
# DATA LAYER (relative imports to package:)
# ──────────────────────────────────────────────────────────────────────────────
# ../model/* or model/*  →  package:.../data/models/*
replace "import '../model/"   "import 'package:recipe_vault/data/models/"
replace "import 'model/"      "import 'package:recipe_vault/data/models/"

# ../services/* or services/* → package:.../data/services/*
replace "import '../services/" "import 'package:recipe_vault/data/services/"
replace "import 'services/"     "import 'package:recipe_vault/data/services/"

# ──────────────────────────────────────────────────────────────────────────────
# FEATURES (screens/* → features/*)
# ──────────────────────────────────────────────────────────────────────────────
replace 'package:recipe_vault/screens/recipe_vault/' 'package:recipe_vault/features/recipe_vault/'
replace 'package:recipe_vault/screens/home_screen/'  'package:recipe_vault/features/home/'
replace 'package:recipe_vault/screens/shared/'       'package:recipe_vault/features/shared/'
replace 'package:recipe_vault/screens/results_screen.dart' 'package:recipe_vault/features/results/results_screen.dart'

# Relative → package for features
replace "import 'screens/recipe_vault/" "import 'package:recipe_vault/features/recipe_vault/"
replace "import '../screens/recipe_vault/" "import 'package:recipe_vault/features/recipe_vault/"
replace "import 'screens/home_screen/"    "import 'package:recipe_vault/features/home/"
replace "import '../screens/home_screen/" "import 'package:recipe_vault/features/home/"
replace "import 'screens/shared/"         "import 'package:recipe_vault/features/shared/"
replace "import '../screens/shared/"      "import 'package:recipe_vault/features/shared/"
replace "import 'screens/results_screen.dart" "import 'package:recipe_vault/features/results/results_screen.dart"
replace "import '../screens/results_screen.dart" "import 'package:recipe_vault/features/results/results_screen.dart"

# Settings moved under features/settings
replace 'package:recipe_vault/settings/' 'package:recipe_vault/features/settings/'
replace "import 'settings/"              "import 'package:recipe_vault/features/settings/"
replace "import '../settings/"           "import 'package:recipe_vault/features/settings/"

# ──────────────────────────────────────────────────────────────────────────────
# BILLING (rev_cat → billing)
# ──────────────────────────────────────────────────────────────────────────────
replace 'package:recipe_vault/rev_cat/' 'package:recipe_vault/billing/'
replace "import 'rev_cat/"              "import 'package:recipe_vault/billing/"
replace "import '../rev_cat/"           "import 'package:recipe_vault/billing/"

# ──────────────────────────────────────────────────────────────────────────────
# AUTH moves
# ──────────────────────────────────────────────────────────────────────────────
replace 'package:recipe_vault/login/'                 'package:recipe_vault/auth/'
replace 'package:recipe_vault/access_controller.dart' 'package:recipe_vault/auth/access_controller.dart'
replace 'package:recipe_vault/auth_service.dart'      'package:recipe_vault/auth/auth_service.dart'

# Relative → package for auth
replace "import 'login/"                 "import 'package:recipe_vault/auth/"
replace "import '../login/"              "import 'package:recipe_vault/auth/"
replace "import 'access_controller.dart'" "import 'package:recipe_vault/auth/access_controller.dart"
replace "import '../access_controller.dart'" "import 'package:recipe_vault/auth/access_controller.dart"
replace "import 'auth_service.dart'"     "import 'package:recipe_vault/auth/auth_service.dart"
replace "import '../auth_service.dart'"  "import 'package:recipe_vault/auth/auth_service.dart"

# ──────────────────────────────────────────────────────────────────────────────
# APP layer moves
# ──────────────────────────────────────────────────────────────────────────────
replace 'package:recipe_vault/boot_screen.dart'      'package:recipe_vault/app/boot_screen.dart'
replace 'package:recipe_vault/app_router.dart'       'package:recipe_vault/app/app_router.dart'
replace 'package:recipe_vault/recipe_vault_app.dart' 'package:recipe_vault/app/recipe_vault_app.dart'
replace 'package:recipe_vault/firebase_options.dart' 'package:recipe_vault/app/firebase_options.dart'

# Relative → package for app pieces (main/app files sometimes used relative)
replace "import 'boot_screen.dart'"       "import 'package:recipe_vault/app/boot_screen.dart'"
replace "import '../boot_screen.dart'"    "import 'package:recipe_vault/app/boot_screen.dart'"
replace "import 'app_router.dart'"        "import 'package:recipe_vault/app/app_router.dart'"
replace "import '../app_router.dart'"     "import 'package:recipe_vault/app/app_router.dart'"
replace "import 'recipe_vault_app.dart'"  "import 'package:recipe_vault/app/recipe_vault_app.dart'"
replace "import '../recipe_vault_app.dart'" "import 'package:recipe_vault/app/recipe_vault_app.dart'"
replace "import 'firebase_options.dart'"  "import 'package:recipe_vault/app/firebase_options.dart'"
replace "import '../firebase_options.dart'" "import 'package:recipe_vault/app/firebase_options.dart'"
replace "import 'app_bootstrap.dart'"     "import 'package:recipe_vault/app/app_bootstrap.dart'"
replace "import '../app_bootstrap.dart'"  "import 'package:recipe_vault/app/app_bootstrap.dart'"

# Core files sometimes imported relatively from app/*
replace "import 'core/"  "import 'package:recipe_vault/core/"
replace "import '../core/" "import 'package:recipe_vault/core/"

# Navigation files sometimes imported relatively from app/*
replace "import 'navigation/"  "import 'package:recipe_vault/navigation/"
replace "import '../navigation/" "import 'package:recipe_vault/navigation/"

# Features referenced relatively from app/*
replace "import 'features/"     "import 'package:recipe_vault/features/"
replace "import '../features/"  "import 'package:recipe_vault/features/"

# Data referenced relatively from app/*
replace "import 'data/"         "import 'package:recipe_vault/data/"
replace "import '../data/"      "import 'package:recipe_vault/data/"

echo "✅ Import path updates complete."

# Optional: show what changed
git status --porcelain

# Commit the changes
git add -A
git commit -m "refactor: update imports to new folder structure (app/auth/billing/data/features)"
echo "✅ Changes committed."