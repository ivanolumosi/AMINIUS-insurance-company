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
    Appointment,
    Reminder,
    ClientPolicy,
    PagedClients,
    EnhancedClientStatistics
} from '../interfaces/client';
import emailService from '../nodemailer/emailservice';

/** Utility: normalize DB dates to ISO string */
const toIsoString = (date: any): string | null =>
    date ? new Date(date).toISOString() : null;

/** Utility: map DB row → Client DTO (PascalCase for frontend) */
const mapClient = (row: any): Client => ({
    ClientId: row.client_id,
    AgentId: row.agent_id,
    FirstName: row.first_name,
    Surname: row.surname,
    LastName: row.last_name,
    PhoneNumber: row.phone_number,
    Email: row.email,
    Address: row.address,
    NationalId: row.national_id,
    DateOfBirth: toIsoString(row.date_of_birth) as string,
    IsClient: row.isclient,
    InsuranceType: row.insurance_type,
    Notes: row.notes,
    CreatedDate: toIsoString(row.created_date) as string,
    ModifiedDate: toIsoString(row.modified_date) as string,
    IsActive: row.is_active,
    Age: row.age ? Number(row.age) : undefined,
    PolicyCount: row.policy_count ? Number(row.policy_count) : undefined,
    NextExpiryDate: toIsoString(row.next_expiry_date) as string | undefined
});

/** Utility: map DB row → ClientPolicy DTO */
const mapPolicy = (row: any): ClientPolicy => ({
    PolicyId: row.policy_id,
    ClientId: row.client_id,
    PolicyName: row.policy_name,
    PolicyType: row.policy_type,
    CompanyName: row.company_name,
    Status: row.status,
    StartDate: toIsoString(row.start_date) as string,
    EndDate: toIsoString(row.end_date) as string,
    DaysToExpiry: row.days_to_expiry ? Number(row.days_to_expiry) : undefined,
    Notes: row.notes,
    CreatedDate: toIsoString(row.created_date) as string,
    ModifiedDate: toIsoString(row.modified_date) as string,
    IsActive: row.is_active
});

/** Utility: map DB row → Appointment DTO */
const mapAppointment = (row: any): Appointment => ({
    AppointmentId: row.appointment_id,
    Title: row.title,
    AppointmentDate: toIsoString(row.appointment_date) as string,
    StartTime: row.start_time,
    EndTime: row.end_time,
    Type: row.type,
    Status: row.status,
    Location: row.location
});

/** Utility: map DB row → Reminder DTO */
const mapReminder = (row: any): Reminder => ({
    ReminderId: row.reminder_id,
    Title: row.title,
    ReminderDate: toIsoString(row.reminder_date) as string,
    ReminderTime: row.reminder_time,
    ReminderType: row.reminder_type,
    Priority: row.priority,
    Status: row.status
});

export class ClientService {
    /** Create or update client */
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
            'SELECT * FROM sp_upsert_client($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)',
            [clientId, agentId, firstName, surname, lastName, phoneNumber, email, address, nationalId, dateOfBirth, isClient, insuranceType, notes]
        );
        return result.rows[0].client_id;
    }

    /** Get all clients with filters */
    public async getClients(
        agentId: string,
        searchTerm?: string,
        filterType: 'all' | 'clients' | 'prospects' = 'all',
        insuranceType?: string
    ): Promise<ClientWithPolicy[]> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_get_clients($1,$2,$3,$4)',
            [agentId, searchTerm, filterType, insuranceType]
        );
        return result.rows.map(r => mapClient(r));
    }

    /** Get single client with details */
    public async getClient(clientId: string, agentId: string): Promise<{ client: ClientWithPolicy[]; appointments: Appointment[] }> {
        const pool = await poolPromise;
        const clientResult = await pool.query('SELECT * FROM sp_get_client($1,$2)', [clientId, agentId]);
        const appointmentsResult = await pool.query('SELECT * FROM sp_get_client_appointments($1,$2)', [clientId, agentId]);
        return {
            client: clientResult.rows.map(r => mapClient(r)),
            appointments: appointmentsResult.rows.map(r => mapAppointment(r))
        };
    }

    /** Convert prospect → client */
public async convertToClient(clientId: string, agentId: string): Promise<{ success: boolean; message: string }> {
    const pool = await poolPromise;

    try {
        // 1️⃣ Call the Postgres function
        const result = await pool.query('SELECT * FROM sp_convert_to_client($1, $2)', [clientId, agentId]);
        const rowsAffected = result.rows[0]?.rows_affected || 0;

        if (rowsAffected === 0) {
            return { success: false, message: 'Conversion failed or prospect already a client' };
        }

        // 2️⃣ Fetch client & agent info for email
        const clientResult = await pool.query(
            'SELECT first_name, surname, last_name, email FROM clients WHERE client_id=$1',
            [clientId]
        );
        const agentResult = await pool.query(
            'SELECT first_name, last_name, email FROM agent WHERE agent_id=$1',
            [agentId]
        );

        const client = clientResult.rows[0];
        const agent = agentResult.rows[0];

        // 3️⃣ Send email notification (non-blocking)
        if (agent?.email && client?.email) {
            emailService.sendMail(
                agent.email,
                'Prospect Converted to Client',
                `Client ${client.first_name} ${client.surname} was converted to a client.`,
                `<h3>Client Conversion</h3>
                 <p>${client.first_name} ${client.surname}</p>
                 <p>${client.email}</p>`
            ).catch(err => console.error('Email send failed:', err));
        }

        // 4️⃣ Return success
        return { success: true, message: `Client ${client.first_name} ${client.surname} converted successfully` };

    } catch (err) {
        console.error('Failed to convert client:', err);
        return { success: false, message: 'Server error during conversion' };
    }
}


    /** Delete client (soft) */
    public async deleteClient(clientId: string, agentId: string): Promise<number> {
        const pool = await poolPromise;
        const result = await pool.query('SELECT * FROM sp_delete_client($1,$2)', [clientId, agentId]);
        return result.rows[0].rows_affected;
    }

    /** Get client statistics */
    public async getClientStatistics(agentId: string): Promise<ClientStatistics> {
        const pool = await poolPromise;
        const result = await pool.query('SELECT * FROM sp_get_client_statistics($1)', [agentId]);
        const r = result.rows[0];
        return {
            TotalContacts: Number(r.total_contacts),
            TotalClients: Number(r.total_clients),
            TotalProspects: Number(r.total_prospects),
            TodayBirthdays: Number(r.today_birthdays)
        };
    }

    /** Get today's birthdays */
    public async getTodaysBirthdays(agentId: string): Promise<Birthday[]> {
        const pool = await poolPromise;
        const result = await pool.query('SELECT * FROM sp_get_today_birthdays($1)', [agentId]);
        return result.rows.map(r => ({ ...mapClient(r), Age: r.age }));
    }

    /** Search clients */
    public async searchClients(agentId: string, searchTerm: string): Promise<Client[]> {
        const pool = await poolPromise;
        const result = await pool.query('SELECT * FROM sp_search_clients($1,$2)', [agentId, searchTerm]);
        return result.rows.map(r => mapClient(r));
    }

    /** Get clients by insurance type */
    public async getClientsByInsuranceType(agentId: string, insuranceType: string): Promise<Client[]> {
        const pool = await poolPromise;
        const result = await pool.query('SELECT * FROM sp_get_clients_by_insurance_type($1,$2)', [agentId, insuranceType]);
        return result.rows.map(r => mapClient(r));
    }

    /** Get client with full details */
    public async getClientWithPolicies(clientId: string, agentId: string): Promise<ClientWithDetails> {
        const pool = await poolPromise;
        const client = (await pool.query('SELECT * FROM sp_get_client_with_policies_client($1,$2)', [clientId, agentId])).rows[0];
        const policies = (await pool.query('SELECT * FROM sp_get_client_with_policies_policies($1,$2)', [clientId, agentId])).rows;
        const appointments = (await pool.query('SELECT * FROM sp_get_client_with_policies_appointments($1,$2)', [clientId, agentId])).rows;
        const reminders = (await pool.query('SELECT * FROM sp_get_client_with_policies_reminders($1,$2)', [clientId, agentId])).rows;
        return {
            ...mapClient(client),
            Policies: policies.map(r => mapPolicy(r)),
            RecentAppointments: appointments.map(r => mapAppointment(r)),
            ActiveReminders: reminders.map(r => mapReminder(r))
        };
    }

  /** Create new client */
public async createClient(clientData: CreateClientRequest): Promise<ClientResponse> {
    const pool = await poolPromise;
    const result = await pool.query(
  'SELECT * FROM sp_create_client($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)',
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
    clientData.InsuranceType,     
    clientData.IsClient ?? false, 
    clientData.Notes              
  ]
);


    const row = result.rows[0];
    return { 
        Success: row.success === 1,   // map from postgres integer (1/0)
        Message: row.message,
        ClientId: row.client_id 
    };
}

    /** Update client */
    public async updateClient(clientData: UpdateClientRequest): Promise<ClientResponse> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_update_client($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)',
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
        return { Success: true, Message: 'Client updated', ClientId: result.rows[0].client_id };
    }

    /** Get all clients with advanced filters & pagination */
    public async getAllClients(
        agentId: string,
        searchTerm?: string,
        insuranceType?: string,
        isClient?: boolean,
        pageNumber: number = 1,
        pageSize: number = 50
    ): Promise<PagedClients> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_get_all_clients($1,$2,$3,$4,$5,$6)',
            [agentId, searchTerm, insuranceType, isClient, pageNumber, pageSize]
        );

        const clients = result.rows.map(r => mapClient(r));
        const totalCount = result.rows.length > 0 && result.rows[0].total_count
            ? Number(result.rows[0].total_count)
            : clients.length;

        return {
            Clients: clients,
            TotalCount: totalCount,
            PageNumber: pageNumber,
            PageSize: pageSize
        };
    }

    /** Get enhanced client statistics */
    public async getEnhancedClientStatistics(agentId: string): Promise<EnhancedClientStatistics> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_get_enhanced_client_statistics($1)',
            [agentId]
        );

        const r = result.rows[0];
        return {
            TotalContacts: Number(r.total_contacts),
            TotalClients: Number(r.total_clients),
            TotalProspects: Number(r.total_prospects),
            TodayBirthdays: Number(r.today_birthdays),
            ActivePolicies: r.active_policies ? Number(r.active_policies) : undefined,
            ExpiringPolicies: r.expiring_policies ? Number(r.expiring_policies) : undefined,
            MonthBirthdays: r.month_birthdays ? Number(r.month_birthdays) : undefined,
            NewThisWeek: r.new_this_week ? Number(r.new_this_week) : undefined,
            NewThisMonth: r.new_this_month ? Number(r.new_this_month) : undefined,
            InsuranceTypeBreakdown: r.insurance_type_breakdown,
            ExpiringSoon: r.expiring_soon ? Number(r.expiring_soon) : undefined,
            InactiveClients: r.inactive_clients ? Number(r.inactive_clients) : undefined,
            TopInsuranceType: r.top_insurance_type,
            ConversionRate: r.conversion_rate ? Number(r.conversion_rate) : undefined
        };
    }

    /** Send birthday reminders */
    public async sendBirthdayReminders(agentId: string, agentEmail: string) {
        try {
            const birthdays: Birthday[] = await this.getTodaysBirthdays(agentId);

            if (birthdays.length === 0) {
                console.log('No birthdays today.');
                return;
            }

            let emailText = `🎉 Today's Client Birthdays:\n\n`;
            birthdays.forEach(b => {
                emailText += `• ${b.FirstName} ${b.Surname} (${b.Age} years) - DOB: ${b.DateOfBirth}\n`;
            });

            const subject = `Today's Client Birthdays - ${birthdays.length} 🎂`;

            await emailService.sendMail(agentEmail, subject, emailText)
                .then(info => console.log('Birthday reminders sent:', info.messageId))
                .catch(err => console.error('Birthday reminder email failed:', err));

        } catch (err) {
            console.error('Error sending birthday reminders:', err);
        }
    }
}
