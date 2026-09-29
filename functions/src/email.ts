import * as nodemailer from 'nodemailer';
import { renderAdminInviteTemplate, renderEmailTemplate } from './templates';

const APP_NAME = (process.env.APP_NAME ?? 'KAH KEN SHA NEY').trim();
const MAIL_FROM = (process.env.MAIL_FROM ?? 'no-reply@localhost').trim();

/** Set to "true" by the Firebase Functions emulator. */
const IS_EMULATOR = process.env.FUNCTIONS_EMULATOR === 'true';

let transporter: nodemailer.Transporter | null = null;

function getTransporter(): nodemailer.Transporter {
  if (transporter) return transporter;

  const host = (process.env.SMTP_HOST ?? '').trim();
  if (!host) {
    const missing: string[] = [];
    if (!process.env.SMTP_HOST) missing.push('SMTP_HOST');
    if (!process.env.SMTP_PORT) missing.push('SMTP_PORT');
    if (!process.env.SMTP_USER) missing.push('SMTP_USER');
    if (!process.env.SMTP_PASS) missing.push('SMTP_PASS');

    if (IS_EMULATOR) {
      // Development fallback so the OTP flow is exercisable end-to-end
      // without an SMTP server: print the email (including the code) to the
      // emulator log. Production deployments never hit this branch because
      // FUNCTIONS_EMULATOR is not set there.
      console.warn(
        `[email] SMTP is not configured; using the development logger ` +
          `transport. Missing: ${missing.join(', ')}. For real delivery, ` +
          `configure functions/.env (emulator) or Firebase secrets (production).`
      );
      transporter = {
        async sendMail(message: nodemailer.SendMailOptions) {
          console.log(
            '[dev-email] To: ' +
              String(message.to) +
              '\nSubject: ' +
              String(message.subject) +
              '\n\n' +
              String(message.text ?? '')
          );
          return { messageId: 'dev-transport' };
        },
      } as unknown as nodemailer.Transporter;
      return transporter;
    }

    console.error(
      `[email] SMTP is not configured. Missing: ${missing.join(', ')}. ` +
        'Set these via `firebase functions:secrets:set` for production or in ' +
        'functions/.env for the emulator. See functions/.env.example.'
    );
    throw new Error(
      'SMTP_HOST is not configured. See functions/.env.example and set ' +
        'SMTP_HOST, SMTP_PORT, SMTP_USER and SMTP_PASS.'
    );
  }

  const port = Number((process.env.SMTP_PORT ?? '587').trim());
  const secure = (process.env.SMTP_SECURE ?? 'false').trim() === 'true';

  const smtpUser = (process.env.SMTP_USER ?? '').trim();
  const smtpPass = (process.env.SMTP_PASS ?? '').trim();

  transporter = nodemailer.createTransport({
    host,
    port,
    secure,
    auth: smtpUser
      ? { user: smtpUser, pass: smtpPass }
      : undefined,
  });

  if (MAIL_FROM === 'no-reply@localhost') {
    console.warn(
      '[email] MAIL_FROM is still the default "no-reply@localhost". ' +
        'Many providers reject this sender; set a real domain in ' +
        'functions/.env or as a secret.'
    );
  }

  return transporter;
}

export interface SendOtpOptions {
  to: string;
  name: string;
  otp: string;
  purpose: 'verification' | 'reset' | 'change';
  expiresInMinutes: number;
}

/**
 * Sends the OTP email asynchronously via SMTP. Throw behaviour is intentional:
 * callers delete the OTP record and surface a friendly error when delivery
 * fails, so no unusable codes are ever persisted.
 */
export async function sendOtpEmail(options: SendOtpOptions): Promise<void> {
  const template = renderEmailTemplate({
    appName: APP_NAME,
    recipientName: options.name || 'there',
    otp: options.otp,
    purpose: options.purpose,
    expiresInMinutes: options.expiresInMinutes,
  });

  await getTransporter().sendMail({
    from: MAIL_FROM,
    to: options.to,
    subject: template.subject,
    text: template.text,
    html: template.html,
  });
}

export interface AdminInviteEmailOptions {
  to: string;
  invitedByEmail: string;
  expiresInDays: number;
}

/**
 * Sends the administrator invitation email. Throws on transport failure —
 * callers decide whether delivery failure should fail the whole invite
 * (it usually should not; the in-app prompt still works).
 */
export async function sendAdminInviteEmail(
  options: AdminInviteEmailOptions
): Promise<void> {
  const template = renderAdminInviteTemplate({
    appName: APP_NAME,
    invitedByEmail: options.invitedByEmail,
    expiresInDays: options.expiresInDays,
  });

  await getTransporter().sendMail({
    from: MAIL_FROM,
    to: options.to,
    subject: template.subject,
    text: template.text,
    html: template.html,
  });
}

export interface SendResolveEmailOptions {
  to: string;
  name: string;
  itemTitle: string;
  itemId: string;
  pickupDateTime?: string;
  pickupLocation?: string;
  appName: string;
}

/**
 * Sends an email when an item is resolved, with pickup details if available.
 * Escapes user-provided text for HTML safety.
 */
export async function sendResolveEmail(options: SendResolveEmailOptions): Promise<void> {
  const pickupDetails = options.pickupDateTime || options.pickupLocation
    ? `<p>You can pick it up ${[options.pickupDateTime ? `on ${escapeHtml(options.pickupDateTime)}` : '', options.pickupLocation ? `at ${escapeHtml(options.pickupLocation)}` : ''].filter(Boolean).join(' ')}.</p>`
    : '<p>Admin will contact you to arrange pickup.</p>';

  const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
    </head>
    <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
      <div style="background: linear-gradient(135deg, #2563EB, #1D4ED8); padding: 30px; border-radius: 12px 12px 0 0; text-align: center;">
        <h1 style="color: white; margin: 0; font-size: 24px;">${escapeHtml(options.appName)}</h1>
        <p style="color: rgba(255,255,255,0.9); margin: 10px 0 0;">Item Resolved</p>
      </div>
      <div style="background: #f8fafc; padding: 30px; border-radius: 0 0 12px 12px; border: 1px solid #e2e8f0; border-top: none;">
        <p>Hi ${escapeHtml(options.name)},</p>
        <p>The item <strong>"${escapeHtml(options.itemTitle)}"</strong> (Ref: ${escapeHtml(options.itemId)}) has been marked as resolved.</p>
        ${pickupDetails}
        <p>If you have any questions, you can contact the admin through the in-app chat.</p>
        <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 24px 0;">
        <p style="font-size: 12px; color: #64748b;">This is an automated message from ${escapeHtml(options.appName)}. Please do not reply to this email.</p>
      </div>
    </body>
    </html>
  `;

  const text = `
Hi ${options.name},

The item "${options.itemTitle}" (Ref: ${options.itemId}) has been marked as resolved.
${options.pickupDateTime ? `Pickup on: ${options.pickupDateTime}` : ''}${options.pickupLocation ? ` at ${options.pickupLocation}` : ''}
${!options.pickupDateTime && !options.pickupLocation ? 'Admin will contact you to arrange pickup.' : ''}

You can contact the admin through the in-app chat.

---
This is an automated message from ${options.appName}.
  `;

  await getTransporter().sendMail({
    from: MAIL_FROM,
    to: options.to,
    subject: `Item Resolved: ${options.itemTitle} (${options.appName})`,
    text,
    html,
  });
}

/**
 * Escapes HTML special characters to prevent XSS.
 */
function escapeHtml(text: string): string {
  return text
    .replace(/&/g, '&')
    .replace(/</g, '<')
    .replace(/>/g, '>')
    .replace(/"/g, '"')
    .replace(/'/g, '&#039;');
}
