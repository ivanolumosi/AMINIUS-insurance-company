// controllers/notes.controller.ts
import { Request, Response } from 'express';
import * as notesService from '../services/notes.service';
import { validate as isUuid } from 'uuid';

export class NotesController {
    async getDailyNotes(req: Request, res: Response) {
        try {
            const { agentId, noteDate } = req.params;
            
            if (!isUuid(agentId)) {
                return res.status(400).json({ 
                    success: false, 
                    error: 'Invalid AgentId GUID format' 
                });
            }

            const notes = await notesService.getDailyNotes(agentId, noteDate);
            res.json({ 
                success: true, 
                data: notes || [] 
            });
        } catch (error: any) {
            console.error('Get daily notes error:', error);
            res.status(500).json({ 
                success: false, 
                error: error.message 
            });
        }
    }

    async saveDailyNotes(req: Request, res: Response) {
        try {
            const { agentId, noteDate } = req.params;
            const { notes } = req.body;

            if (!isUuid(agentId)) {
                return res.status(400).json({ 
                    success: false, 
                    error: 'Invalid AgentId GUID format' 
                });
            }

            if (!notes || typeof notes !== 'string') {
                return res.status(400).json({ 
                    success: false, 
                    error: 'Notes content is required and must be a string' 
                });
            }

            const result = await notesService.saveDailyNotes(agentId, noteDate, notes);
            res.json({ 
                success: true, 
                data: result 
            });
        } catch (error: any) {
            console.error('Save daily notes error:', error);
            res.status(500).json({ 
                success: false, 
                error: error.message 
            });
        }
    }

    async getAllNotes(req: Request, res: Response) {
        try {
            const { agentId } = req.params;
            const { StartDate, EndDate } = req.query;

            if (!isUuid(agentId)) {
                return res.status(400).json({ 
                    success: false, 
                    error: 'Invalid AgentId GUID format' 
                });
            }

            const options = {
                StartDate: StartDate ? String(StartDate) : undefined,
                EndDate: EndDate ? String(EndDate) : undefined
            };

            const notes = await notesService.getAllNotes(agentId, options);
            res.json({ 
                success: true, 
                data: notes || [] 
            });
        } catch (error: any) {
            console.error('Get all notes error:', error);
            res.status(500).json({ 
                success: false, 
                error: error.message 
            });
        }
    }

    async searchNotes(req: Request, res: Response) {
        try {
            const { agentId } = req.params;
            const { searchTerm } = req.query;

            if (!isUuid(agentId)) {
                return res.status(400).json({ 
                    success: false, 
                    error: 'Invalid AgentId GUID format' 
                });
            }

            if (!searchTerm) {
                return res.status(400).json({ 
                    success: false, 
                    error: 'Search term is required' 
                });
            }

            const notes = await notesService.searchNotes(agentId, String(searchTerm));
            res.json({ 
                success: true, 
                data: notes || [] 
            });
        } catch (error: any) {
            console.error('Search notes error:', error);
            res.status(500).json({ 
                success: false, 
                error: error.message 
            });
        }
    }

    async deleteNotes(req: Request, res: Response) {
        try {
            const { agentId, noteDate } = req.params;

            if (!isUuid(agentId)) {
                return res.status(400).json({ 
                    success: false, 
                    error: 'Invalid AgentId GUID format' 
                });
            }

            const result = await notesService.deleteNotes(agentId, noteDate);
            res.json({ 
                success: true, 
                data: result 
            });
        } catch (error: any) {
            console.error('Delete notes error:', error);
            res.status(500).json({ 
                success: false, 
                error: error.message 
            });
        }
    }
}