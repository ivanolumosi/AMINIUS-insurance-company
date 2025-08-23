import crypto from 'crypto';
import bcrypt from 'bcryptjs';
import { poolPromise } from '../../db';
import * as sql from 'mssql';
import { 
    Agent, 
    AgentProfile, 
    AgentSettings,
    LoginRequest,
    LoginResponse,
    RegisterRequest,
    RegisterResponse,
    ChangePasswordRequest,
    PasswordResponse,
    PasswordResetRequest,
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
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('FirstName', sql.NVarChar(50), firstName)
            .input('LastName', sql.NVarChar(50), lastName)
            .input('Email', sql.NVarChar(100), email)
            .input('Phone', sql.NVarChar(20), phone)
            .input('PasswordHash', sql.NVarChar(200), passwordHash)
            .input('Avatar', sql.NVarChar(sql.MAX), avatar)
            .execute('sp_UpsertAgent');

        return result.recordset[0].AgentId;
    }

    /**
     * Get agent profile with settings
     */
    public async getAgent(agentId: string): Promise<AgentProfile | null> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .execute('sp_GetAgent');

        return result.recordset.length ? result.recordset[0] : null;
    }

    /**
     * Update agent settings
     */
    public async updateAgentSettings(
        agentId: string,
        settings: Partial<AgentSettings>
    ): Promise<void> {
        const pool = await poolPromise;
        await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('DarkMode', sql.Bit, settings.DarkMode || null)
            .input('EmailNotifications', sql.Bit, settings.EmailNotifications || null)
            .input('SmsNotifications', sql.Bit, settings.SmsNotifications || null)
            .input('WhatsappNotifications', sql.Bit, settings.WhatsappNotifications || null)
            .input('PushNotifications', sql.Bit, settings.PushNotifications || null)
            .input('SoundEnabled', sql.Bit, settings.SoundEnabled || null)
            .execute('sp_UpdateAgentSettings');
    }

     /**
     * Authenticate agent by email
     */
    public async authenticateAgent(email: string): Promise<Agent | null> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input("Email", sql.NVarChar(100), email)
            .execute("sp_AuthenticateAgent");

        return result.recordset.length ? result.recordset[0] : null;
    }

    /**
     * Login agent
     */
    public async loginAgent(email: string, password: string): Promise<LoginResponse> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input("Email", sql.NVarChar(100), email)
            .input("Password", sql.NVarChar(200), password)
            .execute("sp_LoginAgent");

        const response: LoginResponse = result.recordset[0];

        if (response?.Success && response.AgentId) {
            // Fetch agent info dynamically
            const agentResult = await pool.request()
                .input("AgentId", sql.UniqueIdentifier, response.AgentId)
                .query("SELECT FirstName, Email FROM Agent WHERE AgentId = @AgentId");

            const agent = agentResult.recordset[0];

            // Send login notification email
            try {
                const loginTime = new Date().toLocaleString("en-KE", { timeZone: "Africa/Nairobi" });
                await emailService.sendMail(
                    agent.Email,
                    "Login Notification - Aminius App",
                    `Hi ${agent.FirstName},\n\nYou logged in on ${loginTime}. If this wasn't you, please secure your account immediately.`,
                    `<h3>Login Notification</h3><p>Hi ${agent.FirstName},</p><p>You logged in on <strong>${loginTime}</strong>.</p>`
                );
                console.log(`✅ Login email sent to ${agent.Email}`);
            } catch (err) {
                console.error("❌ Failed to send login email:", err);
            }
        }

        return response;
    }

    /**
     * Register agent
     */
    public async registerAgent(registerData: RegisterRequest): Promise<RegisterResponse> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input("FirstName", sql.NVarChar(50), registerData.FirstName)
            .input("LastName", sql.NVarChar(50), registerData.LastName)
            .input("Email", sql.NVarChar(100), registerData.Email)
            .input("Phone", sql.NVarChar(20), registerData.Phone)
            .input("PasswordHash", sql.NVarChar(256), registerData.PasswordHash)
            .input("Avatar", sql.NVarChar(sql.MAX), registerData.Avatar)
            .execute("sp_RegisterAgent");

        const response: RegisterResponse = result.recordset[0];

        if (response?.Success && response.AgentId) {
            // Fetch agent info dynamically
            const agentResult = await pool.request()
                .input("AgentId", sql.UniqueIdentifier, response.AgentId)
                .query("SELECT FirstName, Email FROM Agent WHERE AgentId = @AgentId");

            const agent = agentResult.recordset[0];

            // Send welcome email with signup time
            try {
                const signUpTime = new Date().toLocaleString("en-KE", { timeZone: "Africa/Nairobi" });
                await emailService.sendMail(
                    agent.Email,
                    "Welcome to Aminius App!",
                    `Hi ${agent.FirstName},\n\nThanks for signing up on ${signUpTime}! We're glad to have you.`,
                    `<h1>Welcome, ${agent.FirstName}!</h1><p>You signed up on <strong>${signUpTime}</strong>. 🚀</p>`
                );
                console.log(`✅ Welcome email sent to ${agent.Email}`);
            } catch (err) {
                console.error(`❌ Failed to send welcome email:`, err);
            }
        }

        return response;
    }

    // /**
    //  * Register new agent
    //  */
    // public async registerAgent(registerData: RegisterRequest): Promise<RegisterResponse> {
    //     const pool = await poolPromise;
    //     const result = await pool.request()
    //         .input('FirstName', sql.NVarChar(50), registerData.FirstName)
    //         .input('LastName', sql.NVarChar(50), registerData.LastName)
    //         .input('Email', sql.NVarChar(100), registerData.Email)
    //         .input('Phone', sql.NVarChar(20), registerData.Phone)
    //         .input('PasswordHash', sql.NVarChar(256), registerData.PasswordHash)
    //         .input('Avatar', sql.NVarChar(sql.MAX), registerData.Avatar)
    //         .execute('sp_RegisterAgent');

    //     return result.recordset[0];
    // }

    /**
     * Change password
     */
    public async changePassword(
        agentId: string,
        oldPasswordHash: string,
        newPasswordHash: string
    ): Promise<PasswordResponse> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('OldPasswordHash', sql.NVarChar(256), oldPasswordHash)
            .input('NewPasswordHash', sql.NVarChar(256), newPasswordHash)
            .execute('sp_ChangePassword');

        return result.recordset[0];
    }

    /**
     * Request password reset
     */
  public async requestPasswordReset(email: string): Promise<PasswordResetResponse> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input("Email", sql.NVarChar(100), email)
            .execute("sp_RequestPasswordReset");

        const response: PasswordResetResponse = result.recordset[0];

        if (response?.Success && response.AgentId && response.Email) {
            // Compose password reset email
            const resetTime = new Date().toLocaleString("en-KE", { timeZone: "Africa/Nairobi" });
            
            // Here, you can generate a reset token or use a temporary link
            // For demonstration, we'll just mention the agent ID
            const resetLink = `https://yourfrontend.com/reset-password?agentId=${response.AgentId}`;

            try {
                await emailService.sendMail(
                    response.Email,
                    "Password Reset Request - Aminius App",
                    `Hi,\n\nA password reset was requested for your account on ${resetTime}. Use the following link to reset your password:\n${resetLink}\n\nIf you did not request this, please ignore this email.`,
                    `<p>Hi,</p>
                     <p>A password reset was requested for your account on <strong>${resetTime}</strong>.</p>
                     <p>Click <a href="${resetLink}">here</a> to reset your password.</p>
                     <p>If you did not request this, please ignore this email.</p>`
                );
                console.log(`✅ Password reset email sent to ${response.Email}`);
            } catch (err) {
                console.error("❌ Failed to send password reset email:", err);
            }
        }

        return response;
    }

    /**
     * Complete password reset
     */
    public async resetPassword(agentId: string, newPasswordHash: string): Promise<PasswordResponse> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input("AgentId", sql.UniqueIdentifier, agentId)
            .input("NewPasswordHash", sql.NVarChar(256), newPasswordHash)
            .execute("sp_ResetPassword");

        const response: PasswordResponse = result.recordset[0];

        if (response?.Success) {
            // Fetch agent email to notify them about the password change
            const agentResult = await pool.request()
                .input("AgentId", sql.UniqueIdentifier, agentId)
                .query("SELECT FirstName, Email FROM Agent WHERE AgentId = @AgentId");

            const agent = agentResult.recordset[0];
            const changeTime = new Date().toLocaleString("en-KE", { timeZone: "Africa/Nairobi" });

            if (agent?.Email) {
                try {
                    await emailService.sendMail(
                        agent.Email,
                        "Password Successfully Reset - Aminius App",
                        `Hi ${agent.FirstName},\n\nYour password was successfully changed on ${changeTime}. If this wasn't you, contact support immediately.`,
                        `<p>Hi ${agent.FirstName},</p>
                         <p>Your password was successfully changed on <strong>${changeTime}</strong>.</p>
                         <p>If this wasn't you, please contact support immediately.</p>`
                    );
                    console.log(`✅ Password change notification sent to ${agent.Email}`);
                } catch (err) {
                    console.error("❌ Failed to send password change notification email:", err);
                }
            }
        }

        return response;
    }

public async sendTemporaryPassword(email: string): Promise<{ Success: boolean; Message: string }> {
  const pool = await poolPromise;

  // Check if agent exists
  const agentResult = await pool.request()
    .input('Email', sql.NVarChar(100), email)
    .execute('sp_AuthenticateAgent');

  const agent = agentResult.recordset[0];
  if (!agent) return { Success: false, Message: 'Email not found' };

  // Generate random temp password
  const tempPassword = crypto.randomBytes(4).toString('hex'); // 8 characters

  // Hash temp password
  const tempHash = await bcrypt.hash(tempPassword, 10);

  // Update agent password in DB
  await pool.request()
    .input('AgentId', sql.UniqueIdentifier, agent.AgentId)
    .input('NewPasswordHash', sql.NVarChar(256), tempHash)
    .execute('sp_ResetPassword');

  // Send email with temporary password
  await emailService.sendMail(
    email,
    'Temporary Password for AminiUs App',
    `Hi ${agent.FirstName},\n\nYour temporary password is: ${tempPassword}\n\nPlease log in and set a new password immediately.`,
    `<p>Hi ${agent.FirstName},</p>
     <p>Your temporary password is: <strong>${tempPassword}</strong></p>
     <p>Please log in and set a new password immediately.</p>`
  );

  return { Success: true, Message: 'Temporary password sent to email' };
}

    /**
     * Get insurance companies
     */
    public async getInsuranceCompanies(): Promise<InsuranceCompany[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .execute('sp_GetInsuranceCompanies');

        return result.recordset;
    }

    /**
     * Get policy types
     */
    public async getPolicyTypes(): Promise<PolicyType[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .execute('sp_GetPolicyTypes');

        return result.recordset;
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
    const result = await pool.request()
        .input('AgentId', sql.UniqueIdentifier, agentId)
        .execute('GetNavbarBadgeCounts');

    if (!result.recordset.length) {
        return { clients: 0, policies: 0, reminders: 0, appointments: 0 };
    }

    const row = result.recordset[0];
    return {
        clients: row.ClientsCount ?? 0,
        policies: row.PoliciesCount ?? 0,
        reminders: row.RemindersCount ?? 0,
        appointments: row.AppointmentsCount ?? 0
    };
}


}