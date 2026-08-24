/**
 * Cloud Functions entry point.
 *
 * Firebase uses the `main` field in package.json to find this file. Every
 * exported trigger below is what gets deployed. The OTP/auth functions are
 * compiled from TypeScript (src/index.ts -> lib/index.js) by the `build`
 * step configured in firebase.json's predeploy hooks.
 */

const {setGlobalOptions} = require("firebase-functions");

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({maxInstances: 10});

// ── Auth / OTP Cloud Functions (compiled from src/index.ts) ─────────────
// Re-exports must be explicit so the Firebase CLI discovers every trigger.
const auth = require("./lib/index");
exports.sendSignupOtp = auth.sendSignupOtp;
exports.verifySignupOtp = auth.verifySignupOtp;
exports.sendPasswordResetOtp = auth.sendPasswordResetOtp;
exports.verifyPasswordResetOtp = auth.verifyPasswordResetOtp;
exports.sendChangePasswordOtp = auth.sendChangePasswordOtp;
exports.verifyChangePasswordOtp = auth.verifyChangePasswordOtp;
exports.changePassword = auth.changePassword;
exports.resetPassword = auth.resetPassword;

// ── KashTeP Chatbot Cloud Function ──────────────────────────────────────
const {kashtep} = require("./src/chatbot");
exports.kashtep = kashtep;
