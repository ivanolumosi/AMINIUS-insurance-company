// services/search.service.ts
import { poolPromise } from '../../db';
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
        const result = await pool.query('SELECT * FROM sp_global_search($1, $2)', [agentId, searchTerm]);

        // Save search history
        await this.saveSearchHistory(agentId, searchTerm);

        return result.rows;
    }

    /**
     * Search clients specifically
     */
    public async searchClients(agentId: string, searchTerm: string): Promise<SearchClient[]> {
        const pool = await poolPromise;
        const result = await pool.query('SELECT * FROM sp_search_clients($1, $2)', [agentId, searchTerm]);

        return result.rows;
    }

    /**
     * Search appointments specifically
     */
    public async searchAppointments(agentId: string, searchTerm: string): Promise<SearchAppointment[]> {
        const pool = await poolPromise;
        const result = await pool.query('SELECT * FROM sp_search_appointments($1, $2)', [agentId, searchTerm]);

        return result.rows;
    }

    /**
     * Search policies specifically
     */
    public async searchPolicies(agentId: string, searchTerm: string): Promise<SearchPolicy[]> {
        const pool = await poolPromise;
        const result = await pool.query('SELECT * FROM sp_search_policies($1, $2)', [agentId, searchTerm]);

        return result.rows;
    }

    /**
     * Search reminders specifically
     */
    public async searchReminders(agentId: string, searchTerm: string): Promise<SearchReminder[]> {
        const pool = await poolPromise;
        const result = await pool.query('SELECT * FROM sp_search_reminders($1, $2)', [agentId, searchTerm]);

        return result.rows;
    }

    /**
     * Get search suggestions for autocomplete
     */
    public async getSearchSuggestions(agentId: string, searchTerm: string, maxResults: number = 10): Promise<SearchSuggestion[]> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_get_search_suggestions($1, $2, $3)', 
            [agentId, searchTerm, maxResults]
        );

        return result.rows;
    }

    /**
     * Save search history
     */
    public async saveSearchHistory(agentId: string, searchTerm: string): Promise<void> {
        const pool = await poolPromise;
        await pool.query('SELECT sp_save_search_history($1, $2)', [agentId, searchTerm]);
    }

    /**
     * Get search history
     */
    public async getSearchHistory(agentId: string, maxResults: number = 20): Promise<SearchHistory[]> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_get_search_history($1, $2)', 
            [agentId, maxResults]
        );

        return result.rows;
    }

    /**
     * Clear search history for an agent
     */
    public async clearSearchHistory(agentId: string): Promise<void> {
        const pool = await poolPromise;
        await pool.query('SELECT sp_clear_search_history($1)', [agentId]);
    }

    /**
     * Delete specific search history item
     */
    public async deleteSearchHistoryItem(agentId: string, searchHistoryId: string): Promise<boolean> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT sp_delete_search_history_item($1, $2) as success', 
            [agentId, searchHistoryId]
        );

        return result.rows[0]?.success || false;
    }

    /**
     * Get popular search terms for an agent
     */
    public async getPopularSearchTerms(agentId: string, maxResults: number = 10): Promise<{ searchTerm: string; searchCount: number }[]> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_get_popular_search_terms($1, $2)', 
            [agentId, maxResults]
        );

        return result.rows;
    }

    /**
     * Advanced search with filters
     */
    public async advancedSearch(
        agentId: string, 
        searchTerm: string, 
        entityTypes: string[] = [], 
        dateFrom?: Date, 
        dateTo?: Date,
        maxResults: number = 50
    ): Promise<GlobalSearchResult[]> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_advanced_search($1, $2, $3, $4, $5, $6)', 
            [
                agentId, 
                searchTerm, 
                entityTypes.length ? entityTypes.join(',') : null,
                dateFrom || null,
                dateTo || null,
                maxResults
            ]
        );

        // Save search history for advanced searches too
        await this.saveSearchHistory(agentId, searchTerm);

        return result.rows;
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

export const clearSearchHistory = (agentId: string) => 
    searchService.clearSearchHistory(agentId);

export const deleteSearchHistoryItem = (agentId: string, searchHistoryId: string) => 
    searchService.deleteSearchHistoryItem(agentId, searchHistoryId);

export const getPopularSearchTerms = (agentId: string, maxResults?: number) => 
    searchService.getPopularSearchTerms(agentId, maxResults);

export const advancedSearch = (
    agentId: string, 
    searchTerm: string, 
    entityTypes?: string[], 
    dateFrom?: Date, 
    dateTo?: Date,
    maxResults?: number
) => searchService.advancedSearch(agentId, searchTerm, entityTypes, dateFrom, dateTo, maxResults);