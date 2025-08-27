// services/client.service.ts
import { poolPromise } from '../../db';
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
import emailService from '../nodemailer/emailservice';

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
        const result = await pool.query(
            'SELECT * FROM sp_upsert_client($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)',
            [clientId, agentId, firstName, surname, lastName, phoneNumber, email, address, nationalId, dateOfBirth, isClient, insuranceType, notes]
        );

        return result.rows[0].client_id;
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
        const result = await pool.query(
            'SELECT * FROM sp_get_clients($1, $2, $3, $4)',
            [agentId, searchTerm, filterType, insuranceType]
        );

        return result.rows;
    }

    /**
     * Get single client with details
     */
    public async getClient(
        clientId: string,
        agentId: string
    ): Promise<{ client: ClientWithPolicy[]; appointments: Appointment[] }> {
        const pool = await poolPromise;
        
        // Get client details
        const clientResult = await pool.query(
            'SELECT * FROM sp_get_client($1, $2)',
            [clientId, agentId]
        );

        // Get appointments
        const appointmentsResult = await pool.query(
            'SELECT * FROM sp_get_client_appointments($1, $2)',
            [clientId, agentId]
        );

        return {
            client: clientResult.rows,
            appointments: appointmentsResult.rows,
        };
    }

    public async convertToClient(clientId: string, agentId: string): Promise<number> {
        const pool = await poolPromise;

        try {
            // 1️⃣ Convert prospect to client in DB
            const result = await pool.query(
                'SELECT * FROM sp_convert_to_client($1, $2)',
                [clientId, agentId]
            );

            const rowsAffected = result.rows[0]?.rows_affected || 0;

            // 2️⃣ Fetch client info for email
            const clientResult = await pool.query(
                `SELECT first_name, surname, last_name, email 
                 FROM clients 
                 WHERE client_id = $1`,
                [clientId]
            );
            const client = clientResult.rows[0];

            // 3️⃣ Fetch agent email dynamically
            const agentResult = await pool.query(
                `SELECT first_name, last_name, email 
                 FROM agent 
                 WHERE agent_id = $1`,
                [agentId]
            );
            const agent = agentResult.rows[0];

            // 4️⃣ Send email asynchronously (errors do not block function)
            if (agent?.email && client) {
                emailService.sendMail(
                    agent.email,
                    'Prospect Converted to Client',
                    `Client ${client.first_name} ${client.surname} was successfully converted to a client.`,
                    `<h3>Client Conversion</h3>
                    <p>Client Name: ${client.first_name} ${client.surname}</p>
                    <p>Email: ${client.email}</p>
                    <p>Converted By: ${agent.first_name} ${agent.last_name}</p>
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
        const result = await pool.query(
            'SELECT * FROM sp_delete_client($1, $2)',
            [clientId, agentId]
        );

        return result.rows[0].rows_affected;
    }

    /**
     * Get client statistics
     */
   public async getClientStatistics(agentId: string): Promise<ClientStatistics> {
    const pool = await poolPromise;
    const result = await pool.query(
        'SELECT * FROM sp_get_client_statistics($1)',
        [agentId]
    );

    const dbResult = result.rows[0];
    
    // Convert BIGINT to number for the interface
    return {
        TotalContacts: Number(dbResult.total_contacts),
        TotalClients: Number(dbResult.total_clients),
        TotalProspects: Number(dbResult.total_prospects),
        TodayBirthdays: Number(dbResult.today_birthdays)
    };
}
    /**
     * Get today's birthdays
     */
   public async getTodaysBirthdays(agentId: string): Promise<Birthday[]> {
    const pool = await poolPromise;

    // 1. Fetch today's birthdays
    const result = await pool.query(
        'SELECT * FROM sp_get_today_birthdays($1)',
        [agentId]
    );

    // Map database results to Birthday interface format
    const birthdays: Birthday[] = result.rows.map(row => ({
        ClientId: row.client_id,
        AgentId: agentId,
        FirstName: row.first_name,
        Surname: row.surname,
        LastName: row.last_name,
        PhoneNumber: row.phone_number,
        Email: row.email,
        Address: '', // Not returned by this SP
        NationalId: '', // Not returned by this SP
        DateOfBirth: row.date_of_birth,
        IsClient: true, // Assuming these are clients
        InsuranceType: row.insurance_type,
        Notes: '',
        CreatedDate: new Date(),
        ModifiedDate: new Date(),
        IsActive: true,
        Age: row.age
    }));

    // 2. Fetch agent email dynamically
    const agentResult = await pool.query(
        `SELECT email, first_name, last_name 
         FROM agent 
         WHERE agent_id = $1`,
        [agentId]
    );

    const agent = agentResult.rows[0];
    const agentEmail = agent?.email;

    if (birthdays.length > 0 && agentEmail) {
        // 3. Construct email content
        let emailText = `🎉 Today's Client Birthdays for ${agent.first_name} ${agent.last_name}:\n\n`;
        birthdays.forEach(b => {
            emailText += `• ${b.FirstName} ${b.Surname} (${b.Age} years old) - DOB: ${b.DateOfBirth}\n`;
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
            emailText += `• ${b.FirstName} ${b.Surname} (${b.Age} years old) - DOB: ${b.DateOfBirth}\n`;
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
        const result = await pool.query(
            'SELECT * FROM sp_get_all_clients($1, $2, $3, $4, $5, $6)',
            [agentId, searchTerm, insuranceType, isClient, pageNumber, pageSize]
        );

        return result.rows;
    }

    /**
     * Search clients
     */
    public async searchClients(agentId: string, searchTerm: string): Promise<Client[]> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_search_clients($1, $2)',
            [agentId, searchTerm]
        );

        return result.rows;
    }

    /**
     * Get clients by insurance type
     */
    public async getClientsByInsuranceType(
        agentId: string,
        insuranceType: string
    ): Promise<Client[]> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_get_clients_by_insurance_type($1, $2)',
            [agentId, insuranceType]
        );

        return result.rows;
    }

    /**
     * Get client with full details including policies
     */
    public async getClientWithPolicies(
        clientId: string,
        agentId: string
    ): Promise<any> {
        const pool = await poolPromise;
        
        // Get client details
        const clientResult = await pool.query(
            'SELECT * FROM sp_get_client_with_policies_client($1, $2)',
            [clientId, agentId]
        );

        // Get policies
        const policiesResult = await pool.query(
            'SELECT * FROM sp_get_client_with_policies_policies($1, $2)',
            [clientId, agentId]
        );

        // Get recent appointments
        const appointmentsResult = await pool.query(
            'SELECT * FROM sp_get_client_with_policies_appointments($1, $2)',
            [clientId, agentId]
        );

        // Get active reminders
        const remindersResult = await pool.query(
            'SELECT * FROM sp_get_client_with_policies_reminders($1, $2)',
            [clientId, agentId]
        );

        return {
            client: clientResult.rows[0] || null,
            policies: policiesResult.rows || [],
            recentAppointments: appointmentsResult.rows || [],
            activeReminders: remindersResult.rows || []
        };
    }

    /**
     * Create new client
     */
    public async createClient(clientData: CreateClientRequest): Promise<ClientResponse> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_create_client($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)',
            [
                clientData.AgentId,
                clientData.FirstName,
                clientData.Surname,
                clientData.LastName,
                clientData.PhoneNumber,
                clientData.Email,
                clientData.Address,
                clientData.NationalId,
                clientData.DateOfBirth,
                clientData.IsClient || false,
                clientData.InsuranceType,
                clientData.Notes
            ]
        );

        return result.rows[0];
    }

    /**
     * Update existing client
     */
    public async updateClient(clientData: UpdateClientRequest): Promise<ClientResponse> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_update_client($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)',
            [
                clientData.ClientId,
                clientData.AgentId,
                clientData.FirstName,
                clientData.Surname,
                clientData.LastName,
                clientData.PhoneNumber,
                clientData.Email,
                clientData.Address,
                clientData.NationalId,
                clientData.DateOfBirth,
                clientData.InsuranceType,
                clientData.Notes
            ]
        );

        return result.rows[0];
    }

    /**
     * Get enhanced client statistics
     */
    public async getEnhancedClientStatistics(agentId: string): Promise<ClientStatistics> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_get_enhanced_client_statistics($1)',
            [agentId]
        );

        return result.rows[0];
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