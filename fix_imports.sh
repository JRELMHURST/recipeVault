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

# ── Data layer moves ────────────────────────────────────────────────────────
replace 'package:recipe_vault/services/' 'package:recipe_vault/data/services/'
replace 'package:recipe_vault/model/'     'package:recipe_vault/data/models/'
replace 'package:recipe_vault/models/'    'package:recipe_vault/data/models/'
replace 'package:recipe_vault/vault_repository.dart' 'package:recipe_vault/data/repositories/vault_repository.dart'

# ── Features (from screens/* → features/*) ─────────────────────────────────
replace 'package:recipe_vault/screens/recipe_vault/' 'package:recipe_vault/features/recipe_vault/'
replace 'package:recipe_vault/screens/home_screen/'  'package:recipe_vault/features/home/'
replace 'package:recipe_vault/screens/shared/'       'package:recipe_vault/features/shared/'
replace 'package:recipe_vault/screens/results_screen.dart' 'package:recipe_vault/features/results/results_screen.dart'

# Settings moved under features/settings
replace 'package:recipe_vault/settings/' 'package:recipe_vault/features/settings/'

# ── Billing (rev_cat → billing) ────────────────────────────────────────────
replace 'package:recipe_vault/rev_cat/' 'package:recipe_vault/billing/'

# ── Auth moves ─────────────────────────────────────────────────────────────
replace 'package:recipe_vault/login/'              'package:recipe_vault/auth/'
replace 'package:recipe_vault/access_controller.dart' 'package:recipe_vault/auth/access_controller.dart'
replace 'package:recipe_vault/auth_service.dart'      'package:recipe_vault/auth/auth_service.dart'

# ── App layer moves ────────────────────────────────────────────────────────
replace 'package:recipe_vault/boot_screen.dart'      'package:recipe_vault/app/boot_screen.dart'
replace 'package:recipe_vault/app_router.dart'       'package:recipe_vault/app/app_router.dart'
replace 'package:recipe_vault/recipe_vault_app.dart' 'package:recipe_vault/app/recipe_vault_app.dart'
replace 'package:recipe_vault/firebase_options.dart' 'package:recipe_vault/app/firebase_options.dart'

echo "✅ Import path updates complete."

# Optional: show what changed
git status --porcelain

# Commit the changes
git add -A
git commit -m "refactor: update imports to new folder structure (app/auth/billing/data/features)"
echo "✅ Changes committed."