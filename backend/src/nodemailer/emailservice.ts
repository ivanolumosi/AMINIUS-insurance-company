import nodemailer, { Transporter } from 'nodemailer';
import dotenv from 'dotenv';

dotenv.config();

class EmailService {
  private transporter: Transporter;

  constructor() {
    this.transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASS,
      },
    });
  }

  async sendMail(to: string, subject: string, text: string, html?: string) {
    try {
      const info = await this.transporter.sendMail({
        from: `"AminiUs Insurance App" <${process.env.EMAIL_USER}>`,
        to,
        subject,
        text,
        html,
      });

      console.log(`✅ Email sent: ${info.messageId}`);
      return info;
    } catch (error) {
      console.error(`❌ Email sending failed:`, error);
      throw error;
    }
  }
}

export default new EmailService();
