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
   * Create or update agent profile - Updated to match frontend expectations
   */
  public async upsertAgent(agentData: {
    agentId?: string | null;
    firstName: string;
    lastName: string;
    email: string;
    phone: string;
    passwordHash: string;
    avatar?: string;
  }): Promise<{ agentId: string }> {
    try {
      const pool = await poolPromise;
      
      // Explicitly cast all parameters to avoid function overload conflicts
      const result = await pool.query(`
        SELECT sp_upsert_agent(
          $1::VARCHAR(50),
          $2::VARCHAR(50), 
          $3::VARCHAR(100),
          $4::VARCHAR(20),
          $5::VARCHAR(200),
          $6::TEXT,
          $7::UUID
        ) AS agent_id
      `, [
        agentData.firstName, 
        agentData.lastName, 
        agentData.email, 
        agentData.phone, 
        agentData.passwordHash, 
        agentData.avatar || null, 
        agentData.agentId
      ]);
      
      console.log('Agent upsert successful:', result.rows[0].agent_id);
      return { agentId: result.rows[0].agent_id };
      
    } catch (error: any) {
      console.error('Error upserting agent:', error);
      
      // Handle specific PostgreSQL errors
      if (error.code === '23505') {
        throw new Error('Email already exists');
      } else if (error.code === '42725') {
        throw new Error('Database function error - please contact support');
      } else if (error.code === '23502') {
        throw new Error('Required field is missing');
      } else if (error.code === '23514') {
        throw new Error('Invalid data format');
      } else {
        throw new Error(`Failed to upsert agent: ${error.message || 'Unknown database error'}`);
      }
    }
  }

  /**
   * Get agent profile with settings - Updated to return consistent PascalCase
   */
  public async getAgent(agentId: string): Promise<AgentProfile | null> {
    try {
      const pool = await poolPromise;
      const result = await pool.query('SELECT * FROM sp_get_agent($1)', [agentId]);
      
      if (!result.rows.length) return null;
      
      const row = result.rows[0];
      
      // Convert snake_case to PascalCase to match frontend expectations - only valid AgentProfile properties
      const agentProfile: AgentProfile = {
        AgentId: row.agent_id || row.AgentId,
        FirstName: row.first_name || row.FirstName,
        LastName: row.last_name || row.LastName,
        Email: row.email || row.Email,
        Phone: row.phone || row.Phone,
        PasswordHash: "", // Never expose password hash
        Avatar: row.avatar || row.Avatar,
        CreatedDate: row.created_date || row.CreatedDate,
        ModifiedDate: row.modified_date || row.ModifiedDate,
        IsActive: row.is_active ?? row.IsActive ?? true,
        DarkMode: row.dark_mode ?? row.DarkMode ?? false,
        EmailNotifications: row.email_notifications ?? row.EmailNotifications ?? true,
        SmsNotifications: row.sms_notifications ?? row.SmsNotifications ?? false,
        WhatsappNotifications: row.whatsapp_notifications ?? row.WhatsappNotifications ?? false,
        PushNotifications: row.push_notifications ?? row.PushNotifications ?? true,
        SoundEnabled: row.sound_enabled ?? row.SoundEnabled ?? true
      };
      
      return agentProfile;
    } catch (error: any) {
      console.error('Error getting agent profile:', error);
      throw new Error(`Failed to get agent profile: ${error.message}`);
    }
  }

  /**
   * Update agent settings - Updated to return proper response
   */
  public async updateAgentSettings(agentId: string, settings: Partial<AgentSettings>): Promise<{ message: string }> {
    try {
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
      
      return { message: 'Settings updated successfully' };
    } catch (error: any) {
      console.error('Error updating agent settings:', error);
      throw new Error(`Failed to update settings: ${error.message}`);
    }
  }

  /**
   * Authenticate agent by email - Updated to return consistent format
   */
  public async authenticateAgent(email: string): Promise<AgentProfile | null> {
    try {
      const pool = await poolPromise;
      const result = await pool.query('SELECT * FROM sp_authenticate_agent($1)', [email]);
      
      if (!result.rows.length) return null;
      
      const row = result.rows[0];
      
      // Convert to consistent PascalCase format - only using properties that exist in AgentProfile
      const agentProfile: AgentProfile = {
        AgentId: row.agentid || row.agent_id || row.AgentId,
        FirstName: row.firstname || row.first_name || row.FirstName,
        LastName: row.lastname || row.last_name || row.LastName,
        Email: row.email || row.Email,
        Phone: row.phone || row.Phone,
        PasswordHash: "", // Never expose actual hash
        Avatar: row.avatar || row.Avatar,
        CreatedDate: row.createddate || row.created_date || row.CreatedDate,
        ModifiedDate: row.modifieddate || row.modified_date || row.ModifiedDate,
        IsActive: row.isactive ?? row.is_active ?? row.IsActive ?? true,
        DarkMode: row.darkmode ?? row.dark_mode ?? row.DarkMode ?? false,
        EmailNotifications: row.emailnotifications ?? row.email_notifications ?? row.EmailNotifications ?? true,
        SmsNotifications: row.smsnotifications ?? row.sms_notifications ?? row.SmsNotifications ?? false,
        WhatsappNotifications: row.whatsappnotifications ?? row.whatsapp_notifications ?? row.WhatsappNotifications ?? false,
        PushNotifications: row.pushnotifications ?? row.push_notifications ?? row.PushNotifications ?? true,
        SoundEnabled: row.soundenabled ?? row.sound_enabled ?? row.SoundEnabled ?? true
      };
      
      return agentProfile;
    } catch (error: any) {
      console.error('Error authenticating agent:', error);
      throw new Error(`Failed to authenticate agent: ${error.message}`);
    }
  }

  /**
   * Login agent - Updated to match frontend expectations
   */
  public async loginAgent(credentials: { email: string; password: string }): Promise<LoginResponse> {
    try {
      const pool = await poolPromise;
      const result = await pool.query('SELECT * FROM sp_login_agent($1,$2)', [credentials.email, credentials.password]);

      if (result.rows.length === 0) {
        return { Success: false, Message: "Invalid email or password" };
      }

      const row = result.rows[0];

      // Convert snake_case → PascalCase for consistent frontend consumption - only valid properties
      const agentProfile: AgentProfile = {
        AgentId: row.agent_profile?.agent_id || row.agent_id,
        FirstName: row.agent_profile?.first_name || row.first_name,
        LastName: row.agent_profile?.last_name || row.last_name,
        Email: row.agent_profile?.email || row.email,
        Phone: row.agent_profile?.phone || row.phone,
        PasswordHash: "", // Never expose actual hash
        Avatar: row.agent_profile?.avatar || row.avatar,
        CreatedDate: row.agent_profile?.created_date || row.created_date,
        ModifiedDate: row.agent_profile?.modified_date || row.modified_date,
        IsActive: row.agent_profile?.is_active ?? row.is_active ?? true,
        DarkMode: row.agent_profile?.dark_mode ?? row.dark_mode ?? false,
        EmailNotifications: row.agent_profile?.email_notifications ?? row.email_notifications ?? true,
        SmsNotifications: row.agent_profile?.sms_notifications ?? row.sms_notifications ?? false,
        WhatsappNotifications: row.agent_profile?.whatsapp_notifications ?? row.whatsapp_notifications ?? false,
        PushNotifications: row.agent_profile?.push_notifications ?? row.push_notifications ?? true,
        SoundEnabled: row.agent_profile?.sound_enabled ?? row.sound_enabled ?? true,
      };

      // Normalize Postgres response → TypeScript interface
      const response: LoginResponse = {
        Success: row.success === 1,
        Message: row.message,
        AgentId: row.agent_id,
        AgentProfile: agentProfile,
        // Token can be added here if you implement JWT
      };

      // Send login email notification
      if (response.Success && response.AgentId) {
        try {
          const loginTime = new Date().toLocaleString('en-KE', { timeZone: 'Africa/Nairobi' });
          await emailService.sendMail(
            agentProfile.Email,
            'Login Notification - Aminius App',
            `Hi ${agentProfile.FirstName},\n\nYou logged in on ${loginTime}. If this wasn't you, please secure your account immediately.`,
            `<h3>Login Notification</h3><p>Hi ${agentProfile.FirstName},</p><p>You logged in on <strong>${loginTime}</strong>.</p>`
          );
        } catch (err) {
          console.error('❌ Failed to send login email:', err);
        }
      }

      return response;
    } catch (error: any) {
      console.error('Error logging in agent:', error);
      throw new Error(`Login failed: ${error.message}`);
    }
  }

  /**
   * Register agent - Updated to handle frontend request structure
   */
  public async registerAgent(registerData: RegisterRequest): Promise<RegisterResponse> {
    try {
      const pool = await poolPromise;
      
      // Call the stored procedure with explicit type casting
      const result = await pool.query(`
        SELECT * FROM sp_register_agent(
          $1::VARCHAR(50),
          $2::VARCHAR(50),
          $3::VARCHAR(100),
          $4::VARCHAR(20),
          $5::VARCHAR(200),
          $6::TEXT
        )
      `, [
        registerData.FirstName,
        registerData.LastName,
        registerData.Email,
        registerData.Phone,
        registerData.PasswordHash,
        registerData.Avatar || null
      ]);

      if (result.rows.length === 0) {
        return {
          Success: false,
          Message: 'Registration failed - no response from database',
          AgentId: undefined
        };
      }

      const row = result.rows[0];
      
      // Convert the stored procedure response to match frontend interface
      const response: RegisterResponse = {
        Success: row.success === 1,
        Message: row.message || 'Registration processed',
        AgentId: row.agent_id || undefined
      };

      console.log('Registration response:', { 
        Success: response.Success, 
        Message: response.Message, 
        AgentId: response.AgentId 
      });

      // Send welcome email if registration was successful
      if (response.Success && response.AgentId) {
        try {
          const signUpTime = new Date().toLocaleString('en-KE', { timeZone: 'Africa/Nairobi' });
          await emailService.sendMail(
            registerData.Email,
            'Welcome to Aminius App!',
            `Hi ${registerData.FirstName},\n\nThanks for signing up on ${signUpTime}! We're glad to have you.`,
            `<h1>Welcome, ${registerData.FirstName}!</h1><p>You signed up on <strong>${signUpTime}</strong>.</p>`
          );
          console.log('Welcome email sent to:', registerData.Email);
        } catch (emailError: any) {
          console.error('Failed to send welcome email:', emailError.message || 'Email service error');
          // Don't fail the registration if email fails
        }
      }

      return response;
      
    } catch (error: any) {
      console.error('Error registering agent:', error);
      
      // Handle specific database errors with proper error codes
      if (error.code === '23505') {
        return {
          Success: false,
          Message: 'Email already exists',
          AgentId: undefined
        };
      } else if (error.code === '42804') {
        return {
          Success: false,
          Message: 'Database configuration error - please contact support',
          AgentId: undefined
        };
      } else if (error.code === '23502') {
        return {
          Success: false,
          Message: 'Required field is missing',
          AgentId: undefined
        };
      } else if (error.code === '23514') {
        return {
          Success: false,
          Message: 'Invalid data format provided',
          AgentId: undefined
        };
      } else if (error.code === '42725') {
        return {
          Success: false,
          Message: 'Database function configuration error',
          AgentId: undefined
        };
      } else {
        return {
          Success: false,
          Message: `Registration failed: ${error.message || 'Unknown database error'}`,
          AgentId: undefined
        };
      }
    }
  }

  /**
   * Change password - Updated to match frontend expectations
   */
  public async changePassword(
    agentId: string, 
    passwordData: { oldPasswordHash: string; newPasswordHash: string }
  ): Promise<PasswordResponse> {
    try {
      const pool = await poolPromise;
      const result = await pool.query(
        'SELECT * FROM sp_change_password($1,$2,$3)',
        [agentId, passwordData.oldPasswordHash, passwordData.newPasswordHash]
      );
      
      const row = result.rows[0];
      return {
        Success: row.success === 1 || row.Success,
        Message: row.message || row.Message || 'Password changed successfully'
      };
    } catch (error: any) {
      console.error('Error changing password:', error);
      throw new Error(`Failed to change password: ${error.message}`);
    }
  }

  /**
   * Request password reset - Updated to match frontend expectations
   */
  public async requestPasswordReset(request: { email: string }): Promise<PasswordResetResponse> {
    try {
      const pool = await poolPromise;
      const result = await pool.query('SELECT * FROM sp_request_password_reset($1)', [request.email]);
      const row = result.rows[0];
      
      const response: PasswordResetResponse = {
        Success: row.success === 1 || row.Success,
        Message: row.message || row.Message,
        AgentId: row.agent_id || row.AgentId,
        Email: row.email || row.Email
      };

      if (response.Success && response.AgentId && response.Email) {
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
    } catch (error: any) {
      console.error('Error requesting password reset:', error);
      throw new Error(`Failed to request password reset: ${error.message}`);
    }
  }

  /**
   * Complete password reset - Updated to match frontend expectations
   */
  public async resetPassword(agentId: string, newPasswordHash: string): Promise<PasswordResponse> {
    try {
      const pool = await poolPromise;
      const result = await pool.query('SELECT * FROM sp_reset_password($1,$2)', [agentId, newPasswordHash]);
      const row = result.rows[0];
      
      const response: PasswordResponse = {
        Success: row.success === 1 || row.Success,
        Message: row.message || row.Message || 'Password reset successfully'
      };

      if (response.Success) {
        const agentResult = await pool.query(
          'SELECT first_name, email FROM agent WHERE agent_id=$1',
          [agentId]
        );
        const agent = agentResult.rows[0];
        const changeTime = new Date().toLocaleString('en-KE', { timeZone: 'Africa/Nairobi' });

        if (agent?.email) {
          try {
            await emailService.sendMail(
              agent.email,
              'Password Successfully Reset - Aminius App',
              `Hi ${agent.first_name},\n\nYour password was changed on ${changeTime}.`,
              `<p>Hi ${agent.first_name},</p><p>Your password was changed on <strong>${changeTime}</strong>.</p>`
            );
          } catch (err) {
            console.error('❌ Failed to send password change notification email:', err);
          }
        }
      }

      return response;
    } catch (error: any) {
      console.error('Error resetting password:', error);
      throw new Error(`Failed to reset password: ${error.message}`);
    }
  }

  /**
   * Get insurance companies - Updated to return consistent PascalCase
   */
  public async getInsuranceCompanies(): Promise<InsuranceCompany[]> {
    try {
      const pool = await poolPromise;
      const result = await pool.query('SELECT * FROM sp_get_insurance_companies()');
      
      // Convert snake_case to PascalCase
      return result.rows.map(row => ({
        CompanyId: row.company_id || row.CompanyId,
        CompanyName: row.company_name || row.CompanyName
      }));
    } catch (error: any) {
      console.error('Error getting insurance companies:', error);
      throw new Error(`Failed to get insurance companies: ${error.message}`);
    }
  }

  /**
   * Get policy types - Updated to return consistent PascalCase
   */
  public async getPolicyTypes(): Promise<PolicyType[]> {
    try {
      const pool = await poolPromise;
      const result = await pool.query('SELECT * FROM sp_get_policy_types()');
      
      // Convert snake_case to PascalCase
      return result.rows.map(row => ({
        TypeId: row.type_id || row.TypeId,
        TypeName: row.type_name || row.TypeName
      }));
    } catch (error: any) {
      console.error('Error getting policy types:', error);
      throw new Error(`Failed to get policy types: ${error.message}`);
    }
  }

  /**
   * Get navbar badge counts - Updated to match frontend interface
   */
  public async getNavbarBadgeCounts(agentId: string): Promise<{
    clients: number;
    policies: number;
    reminders: number;
    appointments: number;
  }> {
    try {
      const pool = await poolPromise;
      const result = await pool.query('SELECT * FROM sp_getnavbarbadgecounts($1)', [agentId]);

      if (!result.rows.length) {
        return { clients: 0, policies: 0, reminders: 0, appointments: 0 };
      }

      const row = result.rows[0];
      return {
        clients: row.clientscount ?? row.clients_count ?? 0,
        policies: row.policiescount ?? row.policies_count ?? 0,
        reminders: row.reminderscount ?? row.reminders_count ?? 0,
        appointments: row.appointmentscount ?? row.appointments_count ?? 0
      };
    } catch (error: any) {
      console.error('Error getting navbar badge counts:', error);
      // Return default values in case of error
      return { clients: 0, policies: 0, reminders: 0, appointments: 0 };
    }
  }

  /**
   * Send temporary password
   */
  public async sendTemporaryPassword(email: string): Promise<{ Success: boolean; Message: string }> {
    try {
      const pool = await poolPromise;

      const agentResult = await pool.query('SELECT * FROM sp_authenticate_agent($1)', [email]);
      const agent = agentResult.rows[0];
      if (!agent) return { Success: false, Message: 'Email not found' };

      const tempPassword = crypto.randomBytes(4).toString('hex');
      const tempHash = await bcrypt.hash(tempPassword, 10);

      await pool.query('SELECT sp_reset_password($1,$2)', [agent.agentid || agent.agent_id, tempHash]);

      await emailService.sendMail(
        email,
        'Temporary Password for Aminius App',
        `Hi ${agent.firstname || agent.first_name},\n\nYour temporary password is: ${tempPassword}`,
        `<p>Hi ${agent.firstname || agent.first_name},</p><p>Your temporary password is: <strong>${tempPassword}</strong></p>`
      );

      return { Success: true, Message: 'Temporary password sent to email' };
    } catch (error: any) {
      console.error('Error sending temporary password:', error);
      throw new Error(`Failed to send temporary password: ${error.message}`);
    }
  }
}