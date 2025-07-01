module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  extends: [
    "eslint:recommended",
    "plugin:import/errors",
    "plugin:import/warnings",
    "plugin:import/typescript",
    "google",
    "plugin:@typescript-eslint/recommended",
  ],
  parser: "@typescript-eslint/parser",
  parserOptions: {
    project: ["tsconfig.json", "tsconfig.dev.json"],
    sourceType: "module",
  },
  ignorePatterns: [
    "/lib/**/*", // Ignore built files.
    "/generated/**/*", // Ignore generated files.
  ],
  plugins: [
    "@typescript-eslint",
    "import",
  ],
  rules: {
    "quotes": ["error", "double"],
    "import/no-unresolved": 0,
    "indent": ["error", 2],
    "max-len": "off", // ✅ Disable max line length complaints
    "comma-dangle": ["error", "always-multiline"], // ✅ Enforce trailing commas where valid
    "object-curly-spacing": ["error", "always"], // ✅ Enforce spacing inside braces
    "@typescript-eslint/no-explicit-any": "warn", // ✅ Warn on `any`, don’t block
  },
};
