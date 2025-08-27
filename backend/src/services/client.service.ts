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
    ClientPolicy
} from '../interfaces/client';
import emailService from '../nodemailer/emailservice';

/**
 * Utility: normalize DB dates to ISO string
 */
const toIsoString = (date: any): string | null =>
    date ? new Date(date).toISOString() : null;

/**
 * Utility: map DB row → Client DTO
 */
const mapClient = (row: any): Client => ({
    clientId: row.client_id,
    agentId: row.agent_id,
    firstName: row.first_name,
    surname: row.surname,
    lastName: row.last_name,
    phoneNumber: row.phone_number,
    email: row.email,
    address: row.address,
    nationalId: row.national_id,
    dateOfBirth: toIsoString(row.date_of_birth) as string,
    isClient: row.isclient,
    insuranceType: row.insurance_type,
    notes: row.notes,
    createdDate: toIsoString(row.created_date) as string,
    modifiedDate: toIsoString(row.modified_date) as string,
    isActive: row.is_active,
    age: row.age ? Number(row.age) : undefined,
    policyCount: row.policy_count ? Number(row.policy_count) : undefined,
    nextExpiryDate: toIsoString(row.next_expiry_date) as string | undefined
});

/**
 * Utility: map DB row → ClientPolicy DTO
 */
const mapPolicy = (row: any): ClientPolicy => ({
    policyId: row.policy_id,
    clientId: row.client_id,
    policyName: row.policy_name,
    policyType: row.policy_type,
    companyName: row.company_name,
    status: row.status,
    startDate: toIsoString(row.start_date) as string,
    endDate: toIsoString(row.end_date) as string,
    daysToExpiry: row.days_to_expiry ? Number(row.days_to_expiry) : undefined,
    notes: row.notes,
    createdDate: toIsoString(row.created_date) as string,
    modifiedDate: toIsoString(row.modified_date) as string,
    isActive: row.is_active
});

/**
 * Utility: map DB row → Appointment DTO
 */
const mapAppointment = (row: any): Appointment => ({
    appointmentId: row.appointment_id,
    title: row.title,
    appointmentDate: toIsoString(row.appointment_date) as string,
    startTime: row.start_time,
    endTime: row.end_time,
    type: row.type,
    status: row.status,
    location: row.location
});

/**
 * Utility: map DB row → Reminder DTO
 */
const mapReminder = (row: any): Reminder => ({
    reminderId: row.reminder_id,
    title: row.title,
    reminderDate: toIsoString(row.reminder_date) as string,
    reminderTime: row.reminder_time,
    reminderType: row.reminder_type,
    priority: row.priority,
    status: row.status
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
        return result.rows.map(r => ({ ...mapClient(r), ...r }));
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
    public async convertToClient(clientId: string, agentId: string): Promise<number> {
        const pool = await poolPromise;
        try {
            const result = await pool.query('SELECT * FROM sp_convert_to_client($1,$2)', [clientId, agentId]);
            const rowsAffected = result.rows[0]?.rows_affected || 0;
            // Send notification email
            const client = (await pool.query('SELECT first_name, surname, last_name, email FROM clients WHERE client_id=$1', [clientId])).rows[0];
            const agent = (await pool.query('SELECT first_name,last_name,email FROM agent WHERE agent_id=$1', [agentId])).rows[0];
            if (agent?.email && client) {
                emailService.sendMail(
                    agent.email,
                    'Prospect Converted to Client',
                    `Client ${client.first_name} ${client.surname} was converted to a client.`,
                    `<h3>Client Conversion</h3><p>${client.first_name} ${client.surname}</p><p>${client.email}</p>`
                ).catch(console.error);
            }
            return rowsAffected;
        } catch (err) {
            console.error('Failed to convert client:', err);
            return 0;
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
            totalContacts: Number(r.total_contacts),
            totalClients: Number(r.total_clients),
            totalProspects: Number(r.total_prospects),
            todayBirthdays: Number(r.today_birthdays)
        };
    }

    /** Get today's birthdays */
    public async getTodaysBirthdays(agentId: string): Promise<Birthday[]> {
        const pool = await poolPromise;
        const result = await pool.query('SELECT * FROM sp_get_today_birthdays($1)', [agentId]);
        return result.rows.map(r => ({ ...mapClient(r), age: r.age }));
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
            policies: policies.map(r => mapPolicy(r)),
            recentAppointments: appointments.map(r => mapAppointment(r)),
            activeReminders: reminders.map(r => mapReminder(r))
        };
    }

    /** Create new client */
    public async createClient(clientData: CreateClientRequest): Promise<ClientResponse> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_create_client($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)',
            [
                clientData.agentId,
                clientData.firstName,
                clientData.surname,
                clientData.lastName,
                clientData.phoneNumber,
                clientData.email,
                clientData.address,
                clientData.nationalId,
                clientData.dateOfBirth,
                clientData.isClient ?? false,
                clientData.insuranceType,
                clientData.notes
            ]
        );
        return { success: true, message: 'Client created', clientId: result.rows[0].client_id };
    }

    /** Update client */
    public async updateClient(clientData: UpdateClientRequest): Promise<ClientResponse> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_update_client($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)',
            [
                clientData.clientId,
                clientData.agentId,
                clientData.firstName,
                clientData.surname,
                clientData.lastName,
                clientData.phoneNumber,
                clientData.email,
                clientData.address,
                clientData.nationalId,
                clientData.dateOfBirth,
                clientData.insuranceType,
                clientData.notes
            ]
        );
        return { success: true, message: 'Client updated', clientId: result.rows[0].client_id };
    }
}
