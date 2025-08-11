// services/search.service.ts
import { poolPromise } from '../../db';
import * as sql from 'mssql';
import {
    GlobalSearchResult,
    SearchClient,
    SearchAppointment,
    SearchPolicy,
    SearchReminder,
    SearchSuggestion,
    SearchHistory
} from '../interfaces/search';

export class SearchService {
    /**
     * Perform global search across all entities
     */
    public async globalSearch(agentId: string, searchTerm: string): Promise<GlobalSearchResult[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('SearchTerm', sql.NVarChar(500), searchTerm)
            .execute('sp_GlobalSearch');

        // Save search history
        await this.saveSearchHistory(agentId, searchTerm);

        return result.recordset;
    }

    /**
     * Search clients specifically
     */
    public async searchClients(agentId: string, searchTerm: string): Promise<SearchClient[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('SearchTerm', sql.NVarChar(500), searchTerm)
            .execute('sp_SearchClients');

        return result.recordset;
    }

    /**
     * Search appointments specifically
     */
    public async searchAppointments(agentId: string, searchTerm: string): Promise<SearchAppointment[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('SearchTerm', sql.NVarChar(500), searchTerm)
            .execute('sp_SearchAppointments');

        return result.recordset;
    }

    /**
     * Search policies specifically
     */
    public async searchPolicies(agentId: string, searchTerm: string): Promise<SearchPolicy[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('SearchTerm', sql.NVarChar(500), searchTerm)
            .execute('sp_SearchPolicies');

        return result.recordset;
    }

    /**
     * Search reminders specifically
     */
    public async searchReminders(agentId: string, searchTerm: string): Promise<SearchReminder[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('SearchTerm', sql.NVarChar(500), searchTerm)
            .execute('sp_SearchReminders');

        return result.recordset;
    }

    /**
     * Get search suggestions for autocomplete
     */
    public async getSearchSuggestions(agentId: string, searchTerm: string, maxResults: number = 10): Promise<SearchSuggestion[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('SearchTerm', sql.NVarChar(500), searchTerm)
            .input('MaxResults', sql.Int, maxResults)
            .execute('sp_GetSearchSuggestions');

        return result.recordset;
    }

    /**
     * Save search history
     */
    public async saveSearchHistory(agentId: string, searchTerm: string): Promise<void> {
        const pool = await poolPromise;
        await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('SearchTerm', sql.NVarChar(500), searchTerm)
            .execute('sp_SaveSearchHistory');
    }

    /**
     * Get search history
     */
    public async getSearchHistory(agentId: string, maxResults: number = 20): Promise<SearchHistory[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('MaxResults', sql.Int, maxResults)
            .execute('sp_GetSearchHistory');

        return result.recordset;
    }
}

// Export individual functions for compatibility
const searchService = new SearchService();

export const globalSearch = (agentId: string, searchTerm: string) => 
    searchService.globalSearch(agentId, searchTerm);

export const searchClients = (agentId: string, searchTerm: string) => 
    searchService.searchClients(agentId, searchTerm);

export const searchAppointments = (agentId: string, searchTerm: string) => 
    searchService.searchAppointments(agentId, searchTerm);

export const searchPolicies = (agentId: string, searchTerm: string) => 
    searchService.searchPolicies(agentId, searchTerm);

export const searchReminders = (agentId: string, searchTerm: string) => 
    searchService.searchReminders(agentId, searchTerm);

export const getSearchSuggestions = (agentId: string, searchTerm: string, maxResults?: number) => 
    searchService.getSearchSuggestions(agentId, searchTerm, maxResults);

export const saveSearchHistory = (agentId: string, searchTerm: string) => 
    searchService.saveSearchHistory(agentId, searchTerm);

export const getSearchHistory = (agentId: string, maxResults?: number) => 
    searchService.getSearchHistory(agentId, maxResults);