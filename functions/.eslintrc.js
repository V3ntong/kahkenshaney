module.exports = {
  env: {
    es6: true,
    node: true,
  },
  parserOptions: {
    "ecmaVersion": 2022,
  },
  extends: [
    "eslint:recommended",
    "google",
  ],
  rules: {
    "no-restricted-globals": ["error", "name", "length"],
    "prefer-arrow-callback": "error",
    "quotes": ["error", "double", {"allowTemplateLiterals": true}],
  },
  ignorePatterns: [
    "lib/**",
    "node_modules/**",
    // TypeScript sources are compiled (and type-checked) by `npm run build`
    // via tsc during predeploy. ESLint here is configured for plain JS only,
    // so `.ts` files must be ignored or linting fails before deploy.
    "**/*.ts",
  ],
  overrides: [
    {
      files: ["**/*.spec.*"],
      env: {
        mocha: true,
      },
      rules: {},
    },
  ],
  globals: {},
};
