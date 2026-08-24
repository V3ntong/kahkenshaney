import * as nodemailer from 'nodemailer';
import { renderEmailTemplate } from './templates';

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
