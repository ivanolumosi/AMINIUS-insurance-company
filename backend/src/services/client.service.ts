// services/client.service.ts
import { poolPromise } from '../../db';
import * as sql from 'mssql';
import { 
    Client,
    ClientWithPolicy,
    ClientWithDetails,
    CreateClientRequest,
    UpdateClientRequest,
    ClientSearchFilters,
    ClientStatistics,
    ClientResponse,
    Birthday,
    Appointment
} from '../interfaces/client';
import emailService from '../nodemailer/emailservice'
export class ClientService {

    /**
     * Create or update client
     */
    public async upsertClient(
        clientId: string | null,
        agentId: string,
        firstName: string,
        surname: string,
        lastName: string,
        phoneNumber: string,
        email: string,
        address: string,
        nationalId: string,
        dateOfBirth: Date,
        isClient: boolean,
        insuranceType: string,
        notes?: string
    ): Promise<string> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('ClientId', sql.UniqueIdentifier, clientId)
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('FirstName', sql.NVarChar(50), firstName)
            .input('Surname', sql.NVarChar(50), surname)
            .input('LastName', sql.NVarChar(50), lastName)
            .input('PhoneNumber', sql.NVarChar(20), phoneNumber)
            .input('Email', sql.NVarChar(100), email)
            .input('Address', sql.NVarChar(500), address)
            .input('NationalId', sql.NVarChar(20), nationalId)
            .input('DateOfBirth', sql.Date, dateOfBirth)
            .input('IsClient', sql.Bit, isClient)
            .input('InsuranceType', sql.NVarChar(50), insuranceType)
            .input('Notes', sql.NVarChar(sql.MAX), notes)
            .execute('sp_UpsertClient');

        return result.recordset[0].ClientId;
    }

    /**
     * Get all clients with filters
     */
    public async getClients(
        agentId: string,
        searchTerm?: string,
        filterType: 'all' | 'clients' | 'prospects' = 'all',
        insuranceType?: string
    ): Promise<ClientWithPolicy[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('SearchTerm', sql.NVarChar(100), searchTerm)
            .input('FilterType', sql.NVarChar(20), filterType)
            .input('InsuranceType', sql.NVarChar(50), insuranceType)
            .execute('sp_GetClients');

        return result.recordset;
    }

    /**
     * Get single client with details
     */
  public async getClient(
    clientId: string,
    agentId: string
): Promise<{ client: ClientWithPolicy[]; appointments: Appointment[] }> {
    const pool = await poolPromise;
    const result = await pool.request()
        .input('ClientId', sql.UniqueIdentifier, clientId)
        .input('AgentId', sql.UniqueIdentifier, agentId)
        .execute('sp_GetClient');

    const recordsets = result.recordsets as sql.IRecordSet<any>[]; // Narrow type

    return {
        client: recordsets[0] as ClientWithPolicy[],
        appointments: recordsets[1] as Appointment[],
    };
}



   public async convertToClient(clientId: string, agentId: string): Promise<number> {
    const pool = await poolPromise;

    try {
        // 1️⃣ Convert prospect to client in DB
        const result = await pool.request()
            .input('ClientId', sql.UniqueIdentifier, clientId)
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .execute('sp_ConvertToClient');

        const rowsAffected = result.recordset[0]?.RowsAffected || 0;

        // 2️⃣ Fetch client info for email
        const clientResult = await pool.request()
            .input('ClientId', sql.UniqueIdentifier, clientId)
            .query(`SELECT FirstName, Surname, LastName, Email FROM Clients WHERE ClientId = @ClientId`);
        const client = clientResult.recordset[0];

        // 3️⃣ Fetch agent email dynamically
        const agentResult = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .query(`SELECT FirstName, LastName, Email FROM Agent WHERE AgentId = @AgentId`);
        const agent = agentResult.recordset[0];

        // 4️⃣ Send email asynchronously (errors do not block function)
        if (agent?.Email && client) {
            emailService.sendMail(
                agent.Email,
                'Prospect Converted to Client',
                `Client ${client.FirstName} ${client.Surname} was successfully converted to a client.`,
                `<h3>Client Conversion</h3>
                <p>Client Name: ${client.FirstName} ${client.Surname}</p>
                <p>Email: ${client.Email}</p>
                <p>Converted By: ${agent.FirstName} ${agent.LastName}</p>
                <p>Date & Time: ${new Date().toLocaleString('en-KE', { timeZone: 'Africa/Nairobi' })}</p>`
            ).catch(err => console.error('Email sending failed (non-blocking):', err));
        }

        return rowsAffected;

    } catch (error) {
        console.error('Failed to convert prospect to client:', error);
        return 0; // return 0 to indicate no rows affected
    }
}


    /**
     * Delete client (soft delete)
     */
    public async deleteClient(clientId: string, agentId: string): Promise<number> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('ClientId', sql.UniqueIdentifier, clientId)
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .execute('sp_DeleteClient');

        return result.recordset[0].RowsAffected;
    }

    /**
     * Get client statistics
     */
    public async getClientStatistics(agentId: string): Promise<ClientStatistics> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .execute('sp_GetClientStatistics');

        return result.recordset[0];
    }

    /**
     * Get today's birthdays
     */
  public async getTodaysBirthdays(agentId: string): Promise<Birthday[]> {
    const pool = await poolPromise;

    // 1. Fetch today's birthdays
    const result = await pool.request()
        .input('AgentId', sql.UniqueIdentifier, agentId)
        .execute('sp_GetTodayBirthdays');

    const birthdays: Birthday[] = result.recordset;

    // 2. Fetch agent email dynamically
    const agentResult = await pool.request()
        .input('AgentId', sql.UniqueIdentifier, agentId)
        .query(`SELECT Email, FirstName, LastName FROM Agent WHERE AgentId = @AgentId`);

    const agent = agentResult.recordset[0];
    const agentEmail = agent?.Email;

    if (birthdays.length > 0 && agentEmail) {
        // 3. Construct email content
        let emailText = `🎉 Today's Client Birthdays for ${agent.FirstName} ${agent.LastName}:\n\n`;
        birthdays.forEach(b => {
            emailText += `• ${b.FirstName} ${b.Surname} (${b.Age} years old) - DOB: ${b.DateOfBirth.toDateString()}\n`;
        });

        const subject = `Today's Client Birthdays - ${birthdays.length} 🎂`;

        // 4. Send email asynchronously (non-blocking)
        emailService.sendMail(agentEmail, subject, emailText)
            .then(info => console.log('Birthday email sent:', info.messageId))
            .catch(err => console.error('Birthday email failed (but function continues):', err));
    } else {
        console.log('No birthdays today or agent email not found.');
    }

    return birthdays;
}
  public async sendBirthdayReminders(agentId: string, agentEmail: string) {
    try {
        // 1. Get today's birthdays
        const birthdays: Birthday[] = await this.getTodaysBirthdays(agentId);

        if (birthdays.length === 0) {
            console.log('No birthdays today.');
            return;
        }

        // 2. Construct email content
        let emailText = `🎉 Today's Birthdays for your clients:\n\n`;
        birthdays.forEach(b => {
            emailText += `• ${b.FirstName} ${b.Surname} (${b.Age} years old) - DOB: ${b.DateOfBirth.toDateString()}\n`;
        });

        const subject = `Today's Client Birthdays - ${birthdays.length} 🎂`;

        // 3. Send email asynchronously
        emailService.sendMail(agentEmail, subject, emailText)
            .then(info => console.log('Birthday email sent successfully:', info.messageId))
            .catch(err => console.error('Birthday email failed, but main function continues:', err));

    } catch (error) {
        console.error('Error fetching birthdays or sending email:', error);
    }
}

    /**
     * Get all clients with advanced filters and pagination
     */
    public async getAllClients(
        agentId: string,
        searchTerm?: string,
        insuranceType?: string,
        isClient?: boolean,
        pageNumber: number = 1,
        pageSize: number = 50
    ): Promise<Client[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('SearchTerm', sql.NVarChar(100), searchTerm)
            .input('InsuranceType', sql.NVarChar(50), insuranceType)
            .input('IsClient', sql.Bit, isClient)
            .input('PageNumber', sql.Int, pageNumber)
            .input('PageSize', sql.Int, pageSize)
            .execute('sp_GetAllClients');

        return result.recordset;
    }

    /**
     * Search clients
     */
    public async searchClients(agentId: string, searchTerm: string): Promise<Client[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('SearchTerm', sql.NVarChar(100), searchTerm)
            .execute('sp_SearchClients');

        return result.recordset;
    }

    /**
     * Get clients by insurance type
     */
    public async getClientsByInsuranceType(
        agentId: string,
        insuranceType: string
    ): Promise<Client[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('InsuranceType', sql.NVarChar(50), insuranceType)
            .execute('sp_GetClientsByInsuranceType');

        return result.recordset;
    }

    /**
     * Get client with full details including policies
     */
    public async getClientWithPolicies(
    clientId: string,
    agentId: string
): Promise<any> {
    const pool = await poolPromise;
    const result = await pool.request()
        .input('ClientId', sql.UniqueIdentifier, clientId)
        .input('AgentId', sql.UniqueIdentifier, agentId)
        .execute('sp_GetClientWithPolicies');

    const recordsets = result.recordsets as sql.IRecordSet<any>[]; // Narrow to array

    return {
        client: recordsets[0]?.[0] || null,
        policies: recordsets[1] || [],
        recentAppointments: recordsets[2] || [],
        activeReminders: recordsets[3] || []
    };
}

    /**
     * Create new client
     */
    public async createClient(clientData: CreateClientRequest): Promise<ClientResponse> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, clientData.AgentId)
            .input('FirstName', sql.NVarChar(50), clientData.FirstName)
            .input('Surname', sql.NVarChar(50), clientData.Surname)
            .input('LastName', sql.NVarChar(50), clientData.LastName)
            .input('PhoneNumber', sql.NVarChar(20), clientData.PhoneNumber)
            .input('Email', sql.NVarChar(100), clientData.Email)
            .input('Address', sql.NVarChar(500), clientData.Address)
            .input('NationalId', sql.NVarChar(20), clientData.NationalId)
            .input('DateOfBirth', sql.Date, clientData.DateOfBirth)
            .input('IsClient', sql.Bit, clientData.IsClient || false)
            .input('InsuranceType', sql.NVarChar(50), clientData.InsuranceType)
            .input('Notes', sql.NVarChar(sql.MAX), clientData.Notes)
            .execute('sp_CreateClient');

        return result.recordset[0];
    }

    /**
     * Update existing client
     */
    public async updateClient(clientData: UpdateClientRequest): Promise<ClientResponse> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('ClientId', sql.UniqueIdentifier, clientData.ClientId)
            .input('AgentId', sql.UniqueIdentifier, clientData.AgentId)
            .input('FirstName', sql.NVarChar(50), clientData.FirstName)
            .input('Surname', sql.NVarChar(50), clientData.Surname)
            .input('LastName', sql.NVarChar(50), clientData.LastName)
            .input('PhoneNumber', sql.NVarChar(20), clientData.PhoneNumber)
            .input('Email', sql.NVarChar(100), clientData.Email)
            .input('Address', sql.NVarChar(500), clientData.Address)
            .input('NationalId', sql.NVarChar(20), clientData.NationalId)
            .input('DateOfBirth', sql.Date, clientData.DateOfBirth)
            .input('InsuranceType', sql.NVarChar(50), clientData.InsuranceType)
            .input('Notes', sql.NVarChar(sql.MAX), clientData.Notes)
            .execute('sp_UpdateClient');

        return result.recordset[0];
    }

    /**
     * Get enhanced client statistics
     */
    public async getEnhancedClientStatistics(agentId: string): Promise<ClientStatistics> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .execute('sp_GetEnhancedClientStatistics');

        return result.recordset[0];
    }

    /**
     * Calculate age utility function
     */
    public calculateAge(dateOfBirth: Date): number {
        const today = new Date();
        const birthDate = new Date(dateOfBirth);
        let age = today.getFullYear() - birthDate.getFullYear();
        const monthDiff = today.getMonth() - birthDate.getMonth();
        
        if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDate.getDate())) {
            age--;
        }
        
        return age;
    }

    /**
     * Format client name utility function
     */
    public formatClientName(firstName: string, surname: string, lastName: string): string {
        return `${firstName} ${surname} ${lastName}`.trim();
    }
}