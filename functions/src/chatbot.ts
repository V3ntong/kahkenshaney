import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { GoogleGenerativeAI } from '@google/generative-ai';

/**
 * KashTeP — the in-app assistant.
 *
 * Exposed as a *callable* function (matching `ChatService`'s
 * `httpsCallable('kashtep')` client call) and verified through Firebase
 * Auth, so the Gemini API key never leaves the server and App Check /
 * Callable token verification happens on the platform's standard path.
 *
 * NOTE: this replaces the old `src/chatbot.js`, which declared an `onRequest`
 * HTTP function and was never compiled into `lib/` (tsconfig has no
 * `allowJs`), so it was never deployed — the callable therefore always
 * resolved to NOT_FOUND for clients.
 */

const SYSTEM_INSTRUCTION =
  'You are the official AI assistant for KAH KEN SHA NEY ' +
  '— an AI and ML-powered application that turns your lost ' +
  'into found. Your *only* task is to explain app ' +
  'features, give instructions, and share details based ' +
  'on the project documentation. If a user asks about ' +
  'anything else, politely decline and steer them back ' +
  'to the app features. ' +
  'App Features: ' +
  'Report Lost Items — report lost items with details. ' +
  'Submit Found Items — submit found items for matching. ' +
  'AI Matching — AI matches lost and found items. ' +
  'AI Camera Scanner — point camera to identify items. ' +
  'User Authentication — email/password + OTP. ' +
  'Real-time Updates — live Firestore streams. ' +
  'Profile Management — view profile, change password. ' +
  'Messages — chat with finders (coming soon). ' +
  'Developer Information: ' +
  'KAH KEN SHA NEY was developed by Melvin Maquilan, ' +
  'Cristian Jim Pogoy, Axl Moraleja, and Aldrian Dajes — ' +
  '3rd-year BSCS (Bachelor of Science in Computer Science) ' +
  'students at SMCTI. ' +
  'Developer questions must be answered briefly and ' +
  'completely. When asked who developed, created, made, ' +
  'built, or is behind KAH KEN SHA NEY or this assistant, respond ' +
  'with exactly the verified developer information above. ' +
  'Do not omit any developer names. Do not start with ' +
  "unnecessary phrases such as 'I am the Official AI " +
  "assistant' or 'Hello!'. Do not use Markdown bold or " +
  'bullet lists. Use plain text only: ' +
  'KAH KEN SHA NEY was developed by Melvin Maquilan, ' +
  'Cristian Jim Pogoy, Axl Moraleja, and Aldrian Dajes. ' +
  'They are 3rd-year BSCS students at SMCTI. ' +
  'Do not invent additional information about the developers.';

const RATE_LIMIT_WINDOW_MS = 60 * 1000;
const MAX_REQUESTS_PER_WINDOW = 20;
const MAX_MESSAGE_CHARS = 1000;
const MAX_HISTORY_TURNS = 20;
const MAX_TURN_CHARS = 4000;

const rateLimitMap = new Map<string, { windowStart: number; count: number }>();

/** Fixed-window rate limit keyed by caller (uid, falling back to IP). */
function checkRateLimit(key: string): boolean {
  const now = Date.now();
  const record = rateLimitMap.get(key);
  if (!record || now - record.windowStart > RATE_LIMIT_WINDOW_MS) {
    rateLimitMap.set(key, { windowStart: now, count: 1 });
    return true;
  }
  record.count += 1;
  return record.count <= MAX_REQUESTS_PER_WINDOW;
}

type Turn = { role: 'user' | 'model'; text: string };

/**
 * Normalizes the client-supplied history: keeps only usable turns, enforces
 * user/model alternation (a Gemini chat requires it) and drops a trailing
 * user turn, because the incoming `message` is sent as the next user turn.
 */
function sanitizeHistory(raw: unknown): Turn[] {
  if (!Array.isArray(raw)) return [];

  const turns: Turn[] = [];
  for (const entry of raw) {
    if (turns.length >= MAX_HISTORY_TURNS) break;
    if (typeof entry !== 'object' || entry === null) continue;
    const candidate = entry as { role?: unknown; text?: unknown };
    if (typeof candidate.text !== 'string') continue;
    const text = candidate.text.trim();
    if (text.length === 0) continue;

    const role: Turn['role'] = candidate.role === 'model' ? 'model' : 'user';
    const last = turns[turns.length - 1];
    if (last && last.role === role) {
      // Consecutive same-role turns — replace rather than send an invalid
      // conversation shape to Gemini.
      turns[turns.length - 1] = { role, text: text.slice(0, MAX_TURN_CHARS) };
    } else {
      turns.push({ role, text: text.slice(0, MAX_TURN_CHARS) });
    }
  }

  const lastTurn = turns[turns.length - 1];
  if (lastTurn && lastTurn.role === 'user') {
    // The pending message is about to be appended as a user turn, so the
    // trailing user entry would break Gemini's alternation requirement.
    turns.pop();
  }
  return turns;
}

/**
 * Callable: KashTeP chatbot proxy.
 *
 * Requires an authenticated caller. Returns `{ reply, timestamp }`.
 */
export const kashtep = onCall(
  {
    region: 'us-central1',
    secrets: ['GEMINI_API_KEY'],
    cors: true,
    timeoutSeconds: 60,
    maxInstances: 10,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'You must be signed in to use the assistant.');
    }

    const rateKey = uid;
    if (!checkRateLimit(rateKey)) {
      throw new HttpsError(
        'resource-exhausted',
        'Too many requests. Please wait a moment and try again.'
      );
    }

    const message =
      typeof request.data?.message === 'string' ? request.data.message.trim() : '';
    if (message.length === 0) {
      throw new HttpsError('invalid-argument', 'Message is required.');
    }
    if (message.length > MAX_MESSAGE_CHARS) {
      throw new HttpsError(
        'invalid-argument',
        `Message too long. Max ${MAX_MESSAGE_CHARS} characters.`
      );
    }

    const history = sanitizeHistory(request.data?.history);

    const apiKey = (process.env.GEMINI_API_KEY ?? '').trim();
    if (!apiKey) {
      // Surfaced to the client as a retryable configuration error instead of
      // a generic failure.
      throw new HttpsError(
        'failed-precondition',
        'The assistant is not configured yet. Please try again later.'
      );
    }

    try {
      const genAI = new GoogleGenerativeAI(apiKey);
      const model = genAI.getGenerativeModel({
        model: (process.env.GEMINI_MODEL ?? 'gemini-3.6-flash').trim(),
        systemInstruction: SYSTEM_INSTRUCTION,
      });

      const chat = model.startChat({
        history: history.map((turn) => ({
          role: turn.role,
          parts: [{ text: turn.text }],
        })),
        generationConfig: {
          maxOutputTokens: 2048,
          temperature: 0.4,
        },
      });

      const result = await chat.sendMessage(message);
      const response = result.response.text();

      return {
        reply: response,
        timestamp: new Date().toISOString(),
      };
    } catch (error) {
      const err = error as { message?: string; status?: number };
      const text = err?.message ?? '';
      console.error('[kashtep] Gemini error:', text);

      if (text.includes('API_KEY_INVALID') || err?.status === 403) {
        throw new HttpsError(
          'failed-precondition',
          'The assistant is not configured correctly. Please try again later.'
        );
      }
      if (err?.status === 429) {
        throw new HttpsError(
          'resource-exhausted',
          'The assistant is busy right now. Please try again in a moment.'
        );
      }
      if (err?.status === 503 || err?.status === 500) {
        throw new HttpsError(
          'unavailable',
          'The assistant is temporarily unavailable. Please try again shortly.'
        );
      }
      throw new HttpsError('internal', 'Something went wrong. Please try again.');
    }
  }
);
