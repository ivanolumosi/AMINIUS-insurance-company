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



    /**
     * Convert prospect to client
     */
    public async convertToClient(clientId: string, agentId: string): Promise<number> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('ClientId', sql.UniqueIdentifier, clientId)
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .execute('sp_ConvertToClient');

        return result.recordset[0].RowsAffected;
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
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .execute('sp_GetTodayBirthdays');

        return result.recordset;
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