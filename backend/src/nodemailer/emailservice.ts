// src/services/EmailService.ts
import nodemailer, { Transporter } from "nodemailer";
import dotenv from "dotenv";

dotenv.config();

class EmailService {
  private transporter: Transporter;

  constructor() {
    if (process.env.SMTP_HOST && process.env.SMTP_PORT) {
      // Generic SMTP setup
      this.transporter = nodemailer.createTransport({
        host: process.env.SMTP_HOST,
        port: Number(process.env.SMTP_PORT),
        secure: Number(process.env.SMTP_PORT) === 465, // true for 465, false for 587
        auth: {
          user: process.env.EMAIL_USER,
          pass: process.env.EMAIL_PASS?.replace(/\s+/g, ""), // strip spaces if Gmail App Password
        },
      });
    } else {
      // Gmail service setup
      this.transporter = nodemailer.createTransport({
        service: "gmail",
        auth: {
          user: process.env.EMAIL_USER,
          pass: process.env.EMAIL_PASS?.replace(/\s+/g, ""),
        },
      });
    }
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
      console.error("❌ Email sending failed:", error);
      throw error;
    }
  }
}

export default new EmailService();
