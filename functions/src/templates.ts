function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

type EmailPurpose = 'verification' | 'reset' | 'change';

function copyFor(purpose: EmailPurpose, appName: string): {
  subject: string;
  heading: string;
  intro: string;
  securityNote: string;
} {
  switch (purpose) {
    case 'verification':
      return {
        subject: `${appName}: your verification code`,
        heading: `Welcome to ${appName}`,
        intro: `Thanks for creating an account with ${appName}! Use the code below to verify your email address.`,
        securityNote: `If you did not create an account with ${appName}, you can safely ignore this email.`,
      };
    case 'reset':
      return {
        subject: `${appName}: your password reset code`,
        heading: 'Password reset code',
        intro: `We received a request to reset the password for your ${appName} account. Use the code below to continue.`,
        securityNote:
          'If you did not request a password reset, you can safely ignore this email. Your password will not be changed unless you use this code.',
      };
    case 'change':
      return {
        subject: `${appName}: confirm your password change`,
        heading: 'Confirm password change',
        intro: `We received a request to change the password for your ${appName} account. Use the code below to continue.`,
        securityNote:
          'If you did not request a password change, you can safely ignore this email. Your password will not be changed unless you use this code.',
      };
  }
}

export interface TemplateOptions {
  appName: string;
  recipientName: string;
  otp: string;
  purpose: EmailPurpose;
  expiresInMinutes: number;
}

export function renderEmailTemplate(
  opts: TemplateOptions
): { subject: string; text: string; html: string } {
  const appName = escapeHtml(opts.appName);
  const name = escapeHtml(opts.recipientName);
  const otp = escapeHtml(opts.otp);
  const copy = copyFor(opts.purpose, opts.appName);

  const text = [
    copy.heading,
    '',
    `Hi ${name},`,
    '',
    copy.intro,
    '',
    `Your code: ${opts.otp}`,
    '',
    `This code expires in ${opts.expiresInMinutes} minutes and can only be used once. Never share it with anyone.`,
    '',
    copy.securityNote,
    '',
    `- ${appName}`,
  ].join('\n');

  const html = `<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
  </head>
  <body style="margin:0;padding:0;background:#F8FAFC;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#F8FAFC;padding:32px 16px;">
      <tr>
        <td align="center">
          <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:480px;background:#ffffff;border-radius:16px;box-shadow:0 4px 16px rgba(15,23,42,0.08);overflow:hidden;">
            <tr>
              <td style="background:linear-gradient(135deg,#3B82F6,#1E40AF);padding:28px 32px;">
                <div style="color:#ffffff;font-size:20px;font-weight:700;letter-spacing:0.5px;">${appName}</div>
              </td>
            </tr>
            <tr>
              <td style="padding:32px;">
                <h1 style="margin:0 0 8px;color:#0F172A;font-size:22px;font-weight:700;">${copy.heading}</h1>
                <p style="margin:0 0 24px;color:#475569;font-size:15px;line-height:1.6;">Hi ${name},</p>
                <p style="margin:0 0 24px;color:#475569;font-size:15px;line-height:1.6;">${copy.intro}</p>
                <div style="background:#EEF2FF;border:1px solid #C7D2FE;border-radius:12px;padding:16px;text-align:center;font-size:32px;font-weight:700;letter-spacing:10px;color:#1E40AF;">${otp}</div>
                <p style="margin:24px 0 0;color:#64748B;font-size:13px;line-height:1.6;">This code expires in ${opts.expiresInMinutes} minutes and can only be used once. Never share it with anyone.</p>
                <p style="margin:16px 0 0;color:#64748B;font-size:13px;line-height:1.6;">${copy.securityNote}</p>
              </td>
            </tr>
            <tr>
              <td style="padding:20px 32px;border-top:1px solid #E2E8F0;color:#94A3B8;font-size:12px;text-align:center;">
                &copy; ${new Date().getFullYear()} ${appName}. All rights reserved.
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>`;

  return { subject: copy.subject, text, html };
}
