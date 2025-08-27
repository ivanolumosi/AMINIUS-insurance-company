import { Request, Response } from 'express';
import * as searchService from '../services/search.service';
import { validate as isUuid } from 'uuid';

export class SearchController {
    /** Utility: validate a UUID format */
    private isValidUuid(uuid: string): boolean {
        return isUuid(uuid);
    }

    /** DRY helper to validate agentId in all endpoints */
    private validateAgentId(req: Request, res: Response): string | null {
        const { agentId } = req.params;
        if (!agentId) {
            res.status(400).json({ 
                success: false,
                error: 'AgentId is required' 
            });
            return null;
        }
        if (!this.isValidUuid(agentId)) {
            res.status(400).json({ 
                success: false,
                error: 'Invalid AgentId UUID format' 
            });
            return null;
        }
        return agentId;
    }

    /** Handle PostgreSQL specific errors */
    private handlePostgreSQLError(error: any, defaultMessage: string) {
        let statusCode = 500;
        let errorMessage = defaultMessage;
        
        if (error.code) {
            console.error('PostgreSQL error code:', error.code);
            console.error('PostgreSQL error detail:', error.detail);
            
            switch (error.code) {
                case '23503': // foreign_key_violation
                    statusCode = 400;
                    errorMessage = "Invalid reference to agent";
                    break;
                case '42P01': // undefined_table
                    statusCode = 500;
                    errorMessage = "Database configuration error";
                    break;
                case '42883': // undefined_function
                    statusCode = 500;
                    errorMessage = "Search function not available";
                    break;
                default:
                    errorMessage = "Database error occurred";
            }
        }

        return {
            statusCode,
            response: {
                success: false,
                error: errorMessage,
                message: error.message,
                errorCode: error.code || null,
                ...(process.env.NODE_ENV === 'development' && { 
                    stack: error.stack,
                    detail: error.detail 
                })
            }
        };
    }

    /** Global search across all entities */
    async globalSearch(req: Request, res: Response) {
        console.log('🔍 GLOBAL SEARCH - Controller method started');
        
        const agentId = this.validateAgentId(req, res);
        if (!agentId) return;

        const { searchTerm } = req.query;
        if (!searchTerm || typeof searchTerm !== 'string' || searchTerm.trim().length < 1) {
            return res.status(400).json({ 
                success: false,
                error: 'searchTerm is required and must be at least 1 character' 
            });
        }

        try {
            console.log('🔍 Performing global search with term:', searchTerm.trim());
            const result = await searchService.globalSearch(agentId, searchTerm.trim());
            
            console.log('✅ GLOBAL SEARCH - Found results:', result.length);
            res.json({
                success: true,
                data: result,
                message: "Global search completed successfully",
                count: result.length,
                searchTerm: searchTerm.trim()
            });
        } catch (error: any) {
            console.error('❌ GLOBAL SEARCH - Error:', error);
            const errorResponse = this.handlePostgreSQLError(error, 'Error performing global search');
            res.status(errorResponse.statusCode).json(errorResponse.response);
        }
    }

    /** Search clients specifically */
    async searchClients(req: Request, res: Response) {
        console.log('🔍 SEARCH CLIENTS - Controller method started');
        
        const agentId = this.validateAgentId(req, res);
        if (!agentId) return;

        const { searchTerm } = req.query;
        const term = searchTerm ? String(searchTerm).trim() : '';

        try {
            console.log('🔍 Searching clients with term:', term);
            const result = await searchService.searchClients(agentId, term);
            
            console.log('✅ SEARCH CLIENTS - Found clients:', result.length);
            res.json({
                success: true,
                data: result,
                message: "Client search completed successfully",
                count: result.length,
                searchTerm: term
            });
        } catch (error: any) {
            console.error('❌ SEARCH CLIENTS - Error:', error);
            const errorResponse = this.handlePostgreSQLError(error, 'Error searching clients');
            res.status(errorResponse.statusCode).json(errorResponse.response);
        }
    }

    /** Search appointments specifically */
    async searchAppointments(req: Request, res: Response) {
        console.log('🔍 SEARCH APPOINTMENTS - Controller method started');
        
        const agentId = this.validateAgentId(req, res);
        if (!agentId) return;

        const { searchTerm } = req.query;
        const term = searchTerm ? String(searchTerm).trim() : '';

        try {
            console.log('🔍 Searching appointments with term:', term);
            const result = await searchService.searchAppointments(agentId, term);
            
            console.log('✅ SEARCH APPOINTMENTS - Found appointments:', result.length);
            res.json({
                success: true,
                data: result,
                message: "Appointment search completed successfully",
                count: result.length,
                searchTerm: term
            });
        } catch (error: any) {
            console.error('❌ SEARCH APPOINTMENTS - Error:', error);
            const errorResponse = this.handlePostgreSQLError(error, 'Error searching appointments');
            res.status(errorResponse.statusCode).json(errorResponse.response);
        }
    }

    /** Search policies specifically */
    async searchPolicies(req: Request, res: Response) {
        console.log('🔍 SEARCH POLICIES - Controller method started');
        
        const agentId = this.validateAgentId(req, res);
        if (!agentId) return;

        const { searchTerm } = req.query;
        const term = searchTerm ? String(searchTerm).trim() : '';

        try {
            console.log('🔍 Searching policies with term:', term);
            const result = await searchService.searchPolicies(agentId, term);
            
            console.log('✅ SEARCH POLICIES - Found policies:', result.length);
            res.json({
                success: true,
                data: result,
                message: "Policy search completed successfully",
                count: result.length,
                searchTerm: term
            });
        } catch (error: any) {
            console.error('❌ SEARCH POLICIES - Error:', error);
            const errorResponse = this.handlePostgreSQLError(error, 'Error searching policies');
            res.status(errorResponse.statusCode).json(errorResponse.response);
        }
    }

    /** Search reminders specifically */
    async searchReminders(req: Request, res: Response) {
        console.log('🔍 SEARCH REMINDERS - Controller method started');
        
        const agentId = this.validateAgentId(req, res);
        if (!agentId) return;

        const { searchTerm } = req.query;
        const term = searchTerm ? String(searchTerm).trim() : '';

        try {
            console.log('🔍 Searching reminders with term:', term);
            const result = await searchService.searchReminders(agentId, term);
            
            console.log('✅ SEARCH REMINDERS - Found reminders:', result.length);
            res.json({
                success: true,
                data: result,
                message: "Reminder search completed successfully",
                count: result.length,
                searchTerm: term
            });
        } catch (error: any) {
            console.error('❌ SEARCH REMINDERS - Error:', error);
            const errorResponse = this.handlePostgreSQLError(error, 'Error searching reminders');
            res.status(errorResponse.statusCode).json(errorResponse.response);
        }
    }

    /** Get search suggestions for autocomplete */
    async getSearchSuggestions(req: Request, res: Response) {
        console.log('💡 GET SEARCH SUGGESTIONS - Controller method started');
        
        const agentId = this.validateAgentId(req, res);
        if (!agentId) return;

        const { searchTerm, maxResults } = req.query;
        const term = searchTerm ? String(searchTerm).trim() : '';
        const max = maxResults ? Number(maxResults) : 10;

        // Validate maxResults
        if (isNaN(max) || max < 1 || max > 100) {
            return res.status(400).json({
                success: false,
                error: 'maxResults must be a number between 1 and 100'
            });
        }

        try {
            console.log('💡 Getting search suggestions for term:', term, 'max:', max);
            const result = await searchService.getSearchSuggestions(agentId, term, max);
            
            console.log('✅ GET SEARCH SUGGESTIONS - Found suggestions:', result.length);
            res.json({
                success: true,
                data: result,
                message: "Search suggestions retrieved successfully",
                count: result.length,
                searchTerm: term,
                maxResults: max
            });
        } catch (error: any) {
            console.error('❌ GET SEARCH SUGGESTIONS - Error:', error);
            const errorResponse = this.handlePostgreSQLError(error, 'Error getting search suggestions');
            res.status(errorResponse.statusCode).json(errorResponse.response);
        }
    }

    /** Get search history */
    async getSearchHistory(req: Request, res: Response) {
        console.log('📚 GET SEARCH HISTORY - Controller method started');
        
        const agentId = this.validateAgentId(req, res);
        if (!agentId) return;

        const { maxResults } = req.query;
        const max = maxResults ? Number(maxResults) : 20;

        // Validate maxResults
        if (isNaN(max) || max < 1 || max > 100) {
            return res.status(400).json({
                success: false,
                error: 'maxResults must be a number between 1 and 100'
            });
        }

        try {
            console.log('📚 Getting search history, max:', max);
            const result = await searchService.getSearchHistory(agentId, max);
            
            console.log('✅ GET SEARCH HISTORY - Found history items:', result.length);
            res.json({
                success: true,
                data: result,
                message: "Search history retrieved successfully",
                count: result.length,
                maxResults: max
            });
        } catch (error: any) {
            console.error('❌ GET SEARCH HISTORY - Error:', error);
            const errorResponse = this.handlePostgreSQLError(error, 'Error getting search history');
            res.status(errorResponse.statusCode).json(errorResponse.response);
        }
    }

    /** Clear search history */
    async clearSearchHistory(req: Request, res: Response) {
        console.log('🗑️ CLEAR SEARCH HISTORY - Controller method started');
        
        const agentId = this.validateAgentId(req, res);
        if (!agentId) return;

        try {
            console.log('🗑️ Clearing search history for agent:', agentId);
            await searchService.clearSearchHistory(agentId);
            
            console.log('✅ CLEAR SEARCH HISTORY - History cleared successfully');
            res.json({
                success: true,
                message: "Search history cleared successfully"
            });
        } catch (error: any) {
            console.error('❌ CLEAR SEARCH HISTORY - Error:', error);
            const errorResponse = this.handlePostgreSQLError(error, 'Error clearing search history');
            res.status(errorResponse.statusCode).json(errorResponse.response);
        }
    }

    /** Delete specific search history item */
    async deleteSearchHistoryItem(req: Request, res: Response) {
        console.log('🗑️ DELETE SEARCH HISTORY ITEM - Controller method started');
        
        const agentId = this.validateAgentId(req, res);
        if (!agentId) return;

        const { searchHistoryId } = req.params;
        if (!this.isValidUuid(searchHistoryId)) {
            return res.status(400).json({ 
                success: false,
                error: 'Invalid SearchHistoryId UUID format' 
            });
        }

        try {
            console.log('🗑️ Deleting search history item:', searchHistoryId);
            const success = await searchService.deleteSearchHistoryItem(agentId, searchHistoryId);
            
            if (success) {
                console.log('✅ DELETE SEARCH HISTORY ITEM - Item deleted successfully');
                res.json({
                    success: true,
                    message: "Search history item deleted successfully"
                });
            } else {
                res.status(404).json({
                    success: false,
                    error: "Search history item not found"
                });
            }
        } catch (error: any) {
            console.error('❌ DELETE SEARCH HISTORY ITEM - Error:', error);
            const errorResponse = this.handlePostgreSQLError(error, 'Error deleting search history item');
            res.status(errorResponse.statusCode).json(errorResponse.response);
        }
    }

    /** Get popular search terms */
    async getPopularSearchTerms(req: Request, res: Response) {
        console.log('📊 GET POPULAR SEARCH TERMS - Controller method started');
        
        const agentId = this.validateAgentId(req, res);
        if (!agentId) return;

        const { maxResults } = req.query;
        const max = maxResults ? Number(maxResults) : 10;

        // Validate maxResults
        if (isNaN(max) || max < 1 || max > 50) {
            return res.status(400).json({
                success: false,
                error: 'maxResults must be a number between 1 and 50'
            });
        }

        try {
            console.log('📊 Getting popular search terms, max:', max);
            const result = await searchService.getPopularSearchTerms(agentId, max);
            
            console.log('✅ GET POPULAR SEARCH TERMS - Found terms:', result.length);
            res.json({
                success: true,
                data: result,
                message: "Popular search terms retrieved successfully",
                count: result.length,
                maxResults: max
            });
        } catch (error: any) {
            console.error('❌ GET POPULAR SEARCH TERMS - Error:', error);
            const errorResponse = this.handlePostgreSQLError(error, 'Error getting popular search terms');
            res.status(errorResponse.statusCode).json(errorResponse.response);
        }
    }

    /** Advanced search with filters */
    async advancedSearch(req: Request, res: Response) {
        console.log('🔍 ADVANCED SEARCH - Controller method started');
        
        const agentId = this.validateAgentId(req, res);
        if (!agentId) return;

        const { searchTerm, entityTypes, dateFrom, dateTo, maxResults } = req.query;

        if (!searchTerm || typeof searchTerm !== 'string' || searchTerm.trim().length < 1) {
            return res.status(400).json({ 
                success: false,
                error: 'searchTerm is required and must be at least 1 character' 
            });
        }

        const term = searchTerm.trim();
        const entities = entityTypes ? String(entityTypes).split(',').map(e => e.trim()) : [];
        const max = maxResults ? Number(maxResults) : 50;

        // Validate maxResults
        if (isNaN(max) || max < 1 || max > 200) {
            return res.status(400).json({
                success: false,
                error: 'maxResults must be a number between 1 and 200'
            });
        }

        // Parse dates
        let fromDate: Date | undefined;
        let toDate: Date | undefined;

        if (dateFrom) {
            fromDate = new Date(String(dateFrom));
            if (isNaN(fromDate.getTime())) {
                return res.status(400).json({
                    success: false,
                    error: 'Invalid dateFrom format'
                });
            }
        }

        if (dateTo) {
            toDate = new Date(String(dateTo));
            if (isNaN(toDate.getTime())) {
                return res.status(400).json({
                    success: false,
                    error: 'Invalid dateTo format'
                });
            }
        }

        try {
            console.log('🔍 Performing advanced search:', { term, entities, fromDate, toDate, max });
            const result = await searchService.advancedSearch(agentId, term, entities, fromDate, toDate, max);
            
            console.log('✅ ADVANCED SEARCH - Found results:', result.length);
            res.json({
                success: true,
                data: result,
                message: "Advanced search completed successfully",
                count: result.length,
                searchTerm: term,
                filters: {
                    entityTypes: entities,
                    dateFrom: fromDate?.toISOString() || null,
                    dateTo: toDate?.toISOString() || null,
                    maxResults: max
                }
            });
        } catch (error: any) {
            console.error('❌ ADVANCED SEARCH - Error:', error);
            const errorResponse = this.handlePostgreSQLError(error, 'Error performing advanced search');
            res.status(errorResponse.statusCode).json(errorResponse.response);
        }
    }
}