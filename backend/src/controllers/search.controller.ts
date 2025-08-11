import { Request, Response } from 'express';
import * as searchService from '../services/search.service';
import { validate as isUuid } from 'uuid';

export class SearchController {
    async globalSearch(req: Request, res: Response) {
        try {
            const { agentId } = req.params;
            const { searchTerm } = req.query;

            if (!isUuid(agentId)) {
                return res.status(400).json({ error: 'Invalid AgentId GUID format' });
            }
            if (!searchTerm) {
                return res.status(400).json({ error: 'searchTerm is required' });
            }

            const result = await searchService.globalSearch(agentId, String(searchTerm));
            res.json(result);
        } catch (error: any) {
            res.status(500).json({ error: error.message });
        }
    }

    async searchClients(req: Request, res: Response) {
        try {
            const { agentId } = req.params;
            const { searchTerm } = req.query;

            if (!isUuid(agentId)) {
                return res.status(400).json({ error: 'Invalid AgentId GUID format' });
            }

            const result = await searchService.searchClients(agentId, String(searchTerm || ''));
            res.json(result);
        } catch (error: any) {
            res.status(500).json({ error: error.message });
        }
    }

    async searchAppointments(req: Request, res: Response) {
        try {
            const { agentId } = req.params;
            const { searchTerm } = req.query;

            if (!isUuid(agentId)) {
                return res.status(400).json({ error: 'Invalid AgentId GUID format' });
            }

            const result = await searchService.searchAppointments(agentId, String(searchTerm || ''));
            res.json(result);
        } catch (error: any) {
            res.status(500).json({ error: error.message });
        }
    }

    async searchPolicies(req: Request, res: Response) {
        try {
            const { agentId } = req.params;
            const { searchTerm } = req.query;

            if (!isUuid(agentId)) {
                return res.status(400).json({ error: 'Invalid AgentId GUID format' });
            }

            const result = await searchService.searchPolicies(agentId, String(searchTerm || ''));
            res.json(result);
        } catch (error: any) {
            res.status(500).json({ error: error.message });
        }
    }

    async searchReminders(req: Request, res: Response) {
        try {
            const { agentId } = req.params;
            const { searchTerm } = req.query;

            if (!isUuid(agentId)) {
                return res.status(400).json({ error: 'Invalid AgentId GUID format' });
            }

            const result = await searchService.searchReminders(agentId, String(searchTerm || ''));
            res.json(result);
        } catch (error: any) {
            res.status(500).json({ error: error.message });
        }
    }

    async getSearchSuggestions(req: Request, res: Response) {
        try {
            const { agentId } = req.params;
            const { searchTerm, maxResults } = req.query;

            if (!isUuid(agentId)) {
                return res.status(400).json({ error: 'Invalid AgentId GUID format' });
            }

            const result = await searchService.getSearchSuggestions(
                agentId,
                String(searchTerm || ''),
                maxResults ? Number(maxResults) : 10
            );
            res.json(result);
        } catch (error: any) {
            res.status(500).json({ error: error.message });
        }
    }

    async getSearchHistory(req: Request, res: Response) {
        try {
            const { agentId } = req.params;
            const { maxResults } = req.query;

            if (!isUuid(agentId)) {
                return res.status(400).json({ error: 'Invalid AgentId GUID format' });
            }

            const result = await searchService.getSearchHistory(
                agentId,
                maxResults ? Number(maxResults) : 20
            );
            res.json(result);
        } catch (error: any) {
            res.status(500).json({ error: error.message });
        }
    }
}
