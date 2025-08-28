import crypto from 'crypto';
import bcrypt from 'bcryptjs';
import { poolPromise } from '../../db';
import {
  Agent,
  AgentProfile,
  AgentSettings,
  LoginResponse,
  RegisterRequest,
  RegisterResponse,
  PasswordResponse,
  PasswordResetResponse,
  InsuranceCompany,
  PolicyType
} from '../interfaces/agent';
import emailService from '../nodemailer/emailservice';

export class AgentService {
  /**
   * Create or update agent profile
   */
  public async upsertAgent(
    agentId: string | null,
    firstName: string,
    lastName: string,
    email: string,
    phone: string,
    passwordHash: string,
    avatar?: string
  ): Promise<string> {
    const pool = await poolPromise;
    const result = await pool.query(
      'SELECT sp_upsert_agent($1,$2,$3,$4,$5,$6,$7) AS agent_id',
      [firstName, lastName, email, phone, passwordHash, avatar || null, agentId]
    );
    return result.rows[0].agent_id;
  }

  /**
   * Get agent profile with settings
   */
  public async getAgent(agentId: string): Promise<AgentProfile | null> {
    const pool = await poolPromise;
    const result = await pool.query('SELECT * FROM sp_get_agent($1)', [agentId]);
    return result.rows.length ? result.rows[0] : null;
  }

  /**
   * Update agent settings
   */
  public async updateAgentSettings(agentId: string, settings: Partial<AgentSettings>): Promise<void> {
    const pool = await poolPromise;
    await pool.query(
      'SELECT sp_update_agent_settings($1,$2,$3,$4,$5,$6,$7)',
      [
        agentId,
        settings.DarkMode ?? null,
        settings.EmailNotifications ?? null,
        settings.SmsNotifications ?? null,
        settings.WhatsappNotifications ?? null,
        settings.PushNotifications ?? null,
        settings.SoundEnabled ?? null
      ]
    );
  }

  /**
   * Authenticate agent by email
   */
  public async authenticateAgent(email: string): Promise<Agent | null> {
    const pool = await poolPromise;
    const result = await pool.query('SELECT * FROM sp_authenticate_agent($1)', [email]);
    return result.rows.length ? result.rows[0] : null;
  }

/**
 * Login agent
 */
public async loginAgent(email: string, password: string): Promise<LoginResponse> {
  const pool = await poolPromise;
  const result = await pool.query('SELECT * FROM sp_login_agent($1,$2)', [email, password]);

  if (result.rows.length === 0) {
    return { Success: false, Message: "Invalid email or password" };
  }

  const row = result.rows[0];

  // 🔄 Convert snake_case → PascalCase
  const agentProfile: AgentProfile = {
  AgentId: row.agent_profile.agent_id,
  FirstName: row.agent_profile.first_name,
  LastName: row.agent_profile.last_name,
  Email: row.agent_profile.email,
  Phone: row.agent_profile.phone,
  PasswordHash: "",   // 🔐 hide actual hash
  Avatar: row.agent_profile.avatar,
  CreatedDate: row.agent_profile.created_date,
  ModifiedDate: row.agent_profile.modified_date,
  IsActive: row.agent_profile.is_active,
  DarkMode: row.agent_profile.dark_mode,
  EmailNotifications: row.agent_profile.email_notifications,
  SmsNotifications: row.agent_profile.sms_notifications,
  WhatsappNotifications: row.agent_profile.whatsapp_notifications,
  PushNotifications: row.agent_profile.push_notifications,
  SoundEnabled: row.agent_profile.sound_enabled,
};


  // ✅ Normalize Postgres response → TypeScript interface
  const response: LoginResponse = {
    Success: row.success === 1,   // int → boolean
    Message: row.message,
    AgentId: row.agent_id,
    AgentProfile: agentProfile,
    // 🚨 Removed stored_password_hash for security
  };

  // ✅ Optional: send login email
  if (response.Success && response.AgentId) {
    const agentResult = await pool.query(
      'SELECT first_name, email FROM agent WHERE agent_id=$1',
      [response.AgentId]
    );
    const agent = agentResult.rows[0];

    try {
      const loginTime = new Date().toLocaleString('en-KE', { timeZone: 'Africa/Nairobi' });
      await emailService.sendMail(
        agent.email,
        'Login Notification - Aminius App',
        `Hi ${agent.first_name},\n\nYou logged in on ${loginTime}. If this wasn't you, please secure your account immediately.`,
        `<h3>Login Notification</h3><p>Hi ${agent.first_name},</p><p>You logged in on <strong>${loginTime}</strong>.</p>`
      );
    } catch (err) {
      console.error('❌ Failed to send login email:', err);
    }
  }

  return response;
}


  /**
   * Register agent
   */
  public async registerAgent(registerData: RegisterRequest): Promise<RegisterResponse> {
    const pool = await poolPromise;
    const result = await pool.query(
      'SELECT * FROM sp_register_agent($1,$2,$3,$4,$5,$6)',
      [
        registerData.FirstName,
        registerData.LastName,
        registerData.Email,
        registerData.Phone,
        registerData.PasswordHash,
        registerData.Avatar || null
      ]
    );

    const response: RegisterResponse = result.rows[0];

    if (response?.Success && response.AgentId) {
      const agentResult = await pool.query(
        'SELECT "FirstName","Email" FROM "Agent" WHERE "AgentId"=$1',
        [response.AgentId]
      );
      const agent = agentResult.rows[0];

      try {
        const signUpTime = new Date().toLocaleString('en-KE', { timeZone: 'Africa/Nairobi' });
        await emailService.sendMail(
          agent.email,
          'Welcome to Aminius App!',
          `Hi ${agent.firstname},\n\nThanks for signing up on ${signUpTime}! We're glad to have you.`,
          `<h1>Welcome, ${agent.firstname}!</h1><p>You signed up on <strong>${signUpTime}</strong>. 🚀</p>`
        );
      } catch (err) {
        console.error(`❌ Failed to send welcome email:`, err);
      }
    }

    return response;
  }

  /**
   * Change password
   */
  public async changePassword(agentId: string, oldPasswordHash: string, newPasswordHash: string): Promise<PasswordResponse> {
    const pool = await poolPromise;
    const result = await pool.query(
      'SELECT * FROM sp_change_password($1,$2,$3)',
      [agentId, oldPasswordHash, newPasswordHash]
    );
    return result.rows[0];
  }

  /**
   * Request password reset
   */
  public async requestPasswordReset(email: string): Promise<PasswordResetResponse> {
    const pool = await poolPromise;
    const result = await pool.query('SELECT * FROM sp_request_password_reset($1)', [email]);
    const response: PasswordResetResponse = result.rows[0];

    if (response?.Success && response.AgentId && response.Email) {
      const resetTime = new Date().toLocaleString('en-KE', { timeZone: 'Africa/Nairobi' });
      const resetLink = `https://yourfrontend.com/reset-password?agentId=${response.AgentId}`;

      try {
        await emailService.sendMail(
          response.Email,
          'Password Reset Request - Aminius App',
          `Hi,\n\nA password reset was requested for your account on ${resetTime}. Use the following link to reset your password:\n${resetLink}`,
          `<p>Hi,</p><p>A password reset was requested on <strong>${resetTime}</strong>.</p><p><a href="${resetLink}">Click here</a> to reset your password.</p>`
        );
      } catch (err) {
        console.error('❌ Failed to send password reset email:', err);
      }
    }

    return response;
  }

  /**
   * Complete password reset
   */
  public async resetPassword(agentId: string, newPasswordHash: string): Promise<PasswordResponse> {
    const pool = await poolPromise;
    const result = await pool.query('SELECT * FROM sp_reset_password($1,$2)', [agentId, newPasswordHash]);
    const response: PasswordResponse = result.rows[0];

    if (response?.Success) {
      const agentResult = await pool.query(
        'SELECT "FirstName","Email" FROM "Agent" WHERE "AgentId"=$1',
        [agentId]
      );
      const agent = agentResult.rows[0];
      const changeTime = new Date().toLocaleString('en-KE', { timeZone: 'Africa/Nairobi' });

      if (agent?.email) {
        try {
          await emailService.sendMail(
            agent.email,
            'Password Successfully Reset - Aminius App',
            `Hi ${agent.firstname},\n\nYour password was changed on ${changeTime}.`,
            `<p>Hi ${agent.firstname},</p><p>Your password was changed on <strong>${changeTime}</strong>.</p>`
          );
        } catch (err) {
          console.error('❌ Failed to send password change notification email:', err);
        }
      }
    }

    return response;
  }

/**
 * Get insurance companies
 */
public async getInsuranceCompanies(): Promise<InsuranceCompany[]> {
  const pool = await poolPromise;
  const result = await pool.query('SELECT * FROM sp_get_insurance_companies()');
  return result.rows;
}

/**
 * Get policy types
 */
public async getPolicyTypes(): Promise<PolicyType[]> {
  const pool = await poolPromise;
  const result = await pool.query('SELECT * FROM sp_get_policy_types()');
  return result.rows;
}


/**
 * Get navbar badge counts
 */
public async getNavbarBadgeCounts(agentId: string): Promise<{
  clients: number;
  policies: number;
  reminders: number;
  appointments: number;
}> {
  const pool = await poolPromise;
  
  try {
const result = await pool.query('SELECT * FROM sp_getnavbarbadgecounts($1)', [agentId]);

    if (!result.rows.length) {
      return { clients: 0, policies: 0, reminders: 0, appointments: 0 };
    }

    const row = result.rows[0];
    return {
      clients: row.clientscount ?? 0,
      policies: row.policiescount ?? 0,
      reminders: row.reminderscount ?? 0,
      appointments: row.appointmentscount ?? 0
    };
  } catch (error) {
    console.error('Error getting navbar badge counts:', error);
    // Return default values in case of error
    return { clients: 0, policies: 0, reminders: 0, appointments: 0 };
  }
}
  /**
 * Send temporary password
 */
public async sendTemporaryPassword(email: string): Promise<{ Success: boolean; Message: string }> {
  const pool = await poolPromise;

  const agentResult = await pool.query('SELECT * FROM sp_authenticate_agent($1)', [email]);
  const agent = agentResult.rows[0];
  if (!agent) return { Success: false, Message: 'Email not found' };

  const tempPassword = crypto.randomBytes(4).toString('hex');
  const tempHash = await bcrypt.hash(tempPassword, 10);

  await pool.query('SELECT sp_reset_password($1,$2)', [agent.agentid, tempHash]);

  await emailService.sendMail(
    email,
    'Temporary Password for Aminius App',
    `Hi ${agent.firstname},\n\nYour temporary password is: ${tempPassword}`,
    `<p>Hi ${agent.firstname},</p><p>Your temporary password is: <strong>${tempPassword}</strong></p>`
  );

  return { Success: true, Message: 'Temporary password sent to email' };
}

    }
  