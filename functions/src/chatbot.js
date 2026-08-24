const {onRequest} = require("firebase-functions/https");
const logger = require("firebase-functions/logger");
const {GoogleGenerativeAI} = require("@google/generative-ai");
const dotenv = require("dotenv");

// Load .env in emulator / local dev
dotenv.config();

const SYSTEM_INSTRUCTION =
  "You are the official AI assistant for KAH KEN SHA NEY " +
  "— an AI and ML-powered application that turns your lost " +
  "into found. Your *only* task is to explain app " +
  "features, give instructions, and share details based " +
  "on the project documentation. If a user asks about " +
  "anything else, politely decline and steer them back " +
  "to the app features. " +
  "App Features: " +
  "Report Lost Items — report lost items with details. " +
  "Submit Found Items — submit found items for matching. " +
  "AI Matching — AI matches lost and found items. " +
  "AI Camera Scanner — point camera to identify items. " +
  "User Authentication — email/password + OTP. " +
  "Real-time Updates — live Firestore streams. " +
  "Profile Management — view profile, change password. " +
  "Messages — chat with finders (coming soon). " +
  "Developer Information: " +
  "KAH KEN SHA NEY was developed by Melvin Maquilan, " +
  "Cristian Jim Pogoy, Axl Moraleja, and Aldrian Dajes — " +
  "3rd-year BSCS (Bachelor of Science in Computer Science) " +
  "students at SMCTI. " +
  "Developer questions must be answered briefly and " +
  "completely. When asked who developed, created, made, " +
  "built, or is behind KAH KEN SHA NEY or this assistant, respond " +
  "with exactly the verified developer information above. " +
  "Do not omit any developer names. Do not start with " +
  "unnecessary phrases such as 'I am the Official AI " +
  "assistant' or 'Hello!'. Do not use Markdown bold or " +
  "bullet lists. Use plain text only: " +
  "KAH KEN SHA NEY was developed by Melvin Maquilan, " +
  "Cristian Jim Pogoy, Axl Moraleja, and Aldrian Dajes. " +
  "They are 3rd-year BSCS students at SMCTI. " +
  "Do not invent additional information about the developers.";

const RATE_LIMIT_WINDOW_MS = 60 * 1000;
const MAX_REQUESTS_PER_WINDOW = 20;
const rateLimitMap = new Map();

/**
 * Check rate limit per IP.
 * @param {string} ip - The IP address.
 * @return {boolean} Whether the request is allowed.
 */
function checkRateLimit(ip) {
  const now = Date.now();
  const record = rateLimitMap.get(ip);
  if (!record || now - record.windowStart > RATE_LIMIT_WINDOW_MS) {
    rateLimitMap.set(ip, {windowStart: now, count: 1});
    return true;
  }
  record.count++;
  return record.count <= MAX_REQUESTS_PER_WINDOW;
}

exports.kashtep = onRequest(
    {
      region: "us-central1",
      maxInstances: 5,
      timeoutSeconds: 60,
      cors: true,
    },
    async (req, res) => {
      res.set("Access-Control-Allow-Origin", "*");
      res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
      res.set("Access-Control-Allow-Headers", "Content-Type");

      if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
      }

      if (req.method !== "POST") {
        res.status(405).json({error: "Method not allowed."});
        return;
      }

      const ip =
        req.headers["x-forwarded-for"] || req.ip || "unknown";
      if (!checkRateLimit(ip)) {
        logger.warn("Rate limit exceeded", {ip});
        res.status(429).json({
          error: "Too many requests. Try again later.",
        });
        return;
      }

      const {message, history} = req.body;
      if (
        !message ||
        typeof message !== "string" ||
        message.trim().length === 0
      ) {
        res.status(400).json({error: "Message is required."});
        return;
      }
      if (message.length > 1000) {
        res.status(400).json({
          error: "Message too long. Max 1000 characters.",
        });
        return;
      }

      const chatHistory = Array.isArray(history) ?
        history.slice(-20) : [];

      const apiKey = process.env.GEMINI_API_KEY;
      if (!apiKey) {
        logger.error("GEMINI_API_KEY not configured");
        res.status(500).json({
          error: "Chat service is not configured.",
        });
        return;
      }

      try {
        const genAI = new GoogleGenerativeAI(apiKey);
        const model = genAI.getGenerativeModel({
          model: "gemini-3.6-flash",
          systemInstruction: SYSTEM_INSTRUCTION,
        });

        const chat = model.startChat({
          history: chatHistory.map((msg) => ({
            role: msg.role === "user" ? "user" : "model",
            parts: [{text: msg.text}],
          })),
          generationConfig: {
            maxOutputTokens: 2048,
            temperature: 0.4,
          },
        });

        const result = await chat.sendMessage(message.trim());
        const response = result.response.text();

        logger.info("KashTeP response generated", {
          messageLength: message.length,
          responseLength: response.length,
        });

        res.status(200).json({
          reply: response,
          timestamp: new Date().toISOString(),
        });
      } catch (error) {
        logger.error("KashTeP error", {
          message: error.message,
          stack: error.stack,
        });

        const msg = error.message || "";
        if (msg.includes("API_KEY_INVALID")) {
          res.status(500).json({
            error: "Chat service configuration error.",
          });
          return;
        }

        res.status(500).json({
          error: "Something went wrong. Please try again.",
        });
      }
    },
);
