import { Request, Response } from 'express';
import * as notesService from '../services/notes.service';
import { validate as isUuid } from 'uuid';

export class NotesController {
    async getDailyNotes(req: Request, res: Response) {
        try {
            const { agentId, noteDate } = req.params;

            if (!isUuid(agentId)) {
                return res.status(400).json({ error: 'Invalid AgentId GUID format' });
            }

            const notes = await notesService.getDailyNotes(agentId, noteDate);
            res.json(notes);
        } catch (error: any) {
            res.status(500).json({ error: error.message });
        }
    }

    async saveDailyNotes(req: Request, res: Response) {
        try {
            const { agentId, noteDate } = req.params;
            const { notes } = req.body;

            if (!isUuid(agentId)) {
                return res.status(400).json({ error: 'Invalid AgentId GUID format' });
            }

            const result = await notesService.saveDailyNotes(agentId, noteDate, notes);
            res.json(result);
        } catch (error: any) {
            res.status(500).json({ error: error.message });
        }
    }

    async getAllNotes(req: Request, res: Response) {
        try {
            const { agentId } = req.params;
            const { StartDate, EndDate } = req.query;

            if (!isUuid(agentId)) {
                return res.status(400).json({ error: 'Invalid AgentId GUID format' });
            }

            const notes = await notesService.getAllNotes(agentId, {
                StartDate: StartDate ? String(StartDate) : undefined,
                EndDate: EndDate ? String(EndDate) : undefined
            });
            res.json(notes);
        } catch (error: any) {
            res.status(500).json({ error: error.message });
        }
    }

    async searchNotes(req: Request, res: Response) {
        try {
            const { agentId } = req.params;
            const { searchTerm } = req.query;

            if (!isUuid(agentId)) {
                return res.status(400).json({ error: 'Invalid AgentId GUID format' });
            }

            const notes = await notesService.searchNotes(agentId, String(searchTerm));
            res.json(notes);
        } catch (error: any) {
            res.status(500).json({ error: error.message });
        }
    }

    async deleteNotes(req: Request, res: Response) {
        try {
            const { agentId, noteDate } = req.params;

            if (!isUuid(agentId)) {
                return res.status(400).json({ error: 'Invalid AgentId GUID format' });
            }

            const result = await notesService.deleteNotes(agentId, noteDate);
            res.json(result);
        } catch (error: any) {
            res.status(500).json({ error: error.message });
        }
    }
}
