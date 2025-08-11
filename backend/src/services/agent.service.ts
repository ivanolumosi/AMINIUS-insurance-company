// services/agent.service.ts
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
     * Authenticate agent by email (returns stored hash for comparison)
     */
    public async authenticateAgent(email: string): Promise<Agent | null> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('Email', sql.NVarChar(100), email)
            .execute('sp_AuthenticateAgent');

        return result.recordset.length ? result.recordset[0] : null;
    }

    /**
     * Login agent
     */
    public async loginAgent(email: string, password: string): Promise<LoginResponse> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('Email', sql.NVarChar(100), email)
            .input('Password', sql.NVarChar(200), password)
            .execute('sp_LoginAgent');

        return result.recordset[0];
    }

    /**
     * Register new agent
     */
    public async registerAgent(registerData: RegisterRequest): Promise<RegisterResponse> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('FirstName', sql.NVarChar(50), registerData.FirstName)
            .input('LastName', sql.NVarChar(50), registerData.LastName)
            .input('Email', sql.NVarChar(100), registerData.Email)
            .input('Phone', sql.NVarChar(20), registerData.Phone)
            .input('PasswordHash', sql.NVarChar(256), registerData.PasswordHash)
            .input('Avatar', sql.NVarChar(sql.MAX), registerData.Avatar)
            .execute('sp_RegisterAgent');

        return result.recordset[0];
    }

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
            .input('Email', sql.NVarChar(100), email)
            .execute('sp_RequestPasswordReset');

        return result.recordset[0];
    }

    /**
     * Complete password reset
     */
    public async resetPassword(agentId: string, newPasswordHash: string): Promise<PasswordResponse> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('NewPasswordHash', sql.NVarChar(256), newPasswordHash)
            .execute('sp_ResetPassword');

        return result.recordset[0];
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
}