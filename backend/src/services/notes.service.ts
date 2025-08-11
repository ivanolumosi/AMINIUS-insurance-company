// services/notes.service.ts
import { poolPromise } from '../../db';
import * as sql from 'mssql';
import { DailyNote, SaveNotesResult, DeleteNotesResult, NotesDateRange } from '../interfaces/notes';

export class NotesService {
    /**
     * Get daily notes for a specific agent and date
     */
    public async getDailyNotes(agentId: string, noteDate: string): Promise<DailyNote[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('NoteDate', sql.Date, noteDate)
            .execute('sp_GetDailyNotes');

        return result.recordset;
    }

    /**
     * Save daily notes (insert or update)
     */
    public async saveDailyNotes(agentId: string, noteDate: string, notes: string): Promise<SaveNotesResult> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('NoteDate', sql.Date, noteDate)
            .input('Notes', sql.NVarChar(sql.MAX), notes)
            .execute('sp_SaveDailyNotes');

        return result.recordset[0];
    }

    /**
     * Get all notes for an agent within a date range
     */
    public async getAllNotes(agentId: string, options?: NotesDateRange): Promise<DailyNote[]> {
        const pool = await poolPromise;
        const request = pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId);

        if (options?.StartDate) {
            request.input('StartDate', sql.Date, options.StartDate);
        }
        if (options?.EndDate) {
            request.input('EndDate', sql.Date, options.EndDate);
        }

        const result = await request.execute('sp_GetAllNotes');
        return result.recordset;
    }

    /**
     * Search notes by content
     */
    public async searchNotes(agentId: string, searchTerm: string): Promise<DailyNote[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('SearchTerm', sql.NVarChar(500), searchTerm)
            .execute('sp_SearchNotes');

        return result.recordset;
    }

    /**
     * Delete notes for a specific date
     */
    public async deleteNotes(agentId: string, noteDate: string): Promise<DeleteNotesResult> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('NoteDate', sql.Date, noteDate)
            .execute('sp_DeleteNotes');

        return result.recordset[0];
    }
}

// Export individual functions for compatibility
const notesService = new NotesService();

export const getDailyNotes = (agentId: string, noteDate: string) => 
    notesService.getDailyNotes(agentId, noteDate);

export const saveDailyNotes = (agentId: string, noteDate: string, notes: string) => 
    notesService.saveDailyNotes(agentId, noteDate, notes);

export const getAllNotes = (agentId: string, options?: NotesDateRange) => 
    notesService.getAllNotes(agentId, options);

export const searchNotes = (agentId: string, searchTerm: string) => 
    notesService.searchNotes(agentId, searchTerm);

export const deleteNotes = (agentId: string, noteDate: string) => 
    notesService.deleteNotes(agentId, noteDate);