// services/notes.service.ts
import { poolPromise } from '../../db';
import { DailyNote, SaveNotesResult, DeleteNotesResult, NotesDateRange } from '../interfaces/notes';

export class NotesService {
    /**
     * Get daily notes for a specific agent and date
     */
    public async getDailyNotes(agentId: string, noteDate: string): Promise<DailyNote[]> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_get_daily_notes($1, $2)',
            [agentId, noteDate]
        );
        return result.rows;
    }

    /**
     * Save daily notes (insert or update)
     */
    public async saveDailyNotes(agentId: string, noteDate: string, notes: string): Promise<SaveNotesResult> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_save_daily_notes($1, $2, $3)',
            [agentId, noteDate, notes]
        );
        return result.rows[0];
    }

    /**
     * Get all notes for an agent within a date range
     */
    public async getAllNotes(agentId: string, options?: NotesDateRange): Promise<DailyNote[]> {
        const pool = await poolPromise;
        
        let query = 'SELECT * FROM sp_get_all_notes($1';
        const params: any[] = [agentId];
        let paramCount = 1;

        if (options?.StartDate) {
            paramCount++;
            query += `, $${paramCount}`;
            params.push(options.StartDate);
        } else {
            query += ', null';
        }

        if (options?.EndDate) {
            paramCount++;
            query += `, $${paramCount}`;
            params.push(options.EndDate);
        } else {
            query += ', null';
        }

        query += ')';

        const result = await pool.query(query, params);
        return result.rows;
    }

    /**
     * Search notes by content
     */
    public async searchNotes(agentId: string, searchTerm: string): Promise<DailyNote[]> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_search_notes($1, $2)',
            [agentId, searchTerm]
        );
        return result.rows;
    }

    /**
     * Delete notes for a specific date
     */
    public async deleteNotes(agentId: string, noteDate: string): Promise<DeleteNotesResult> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_delete_notes($1, $2)',
            [agentId, noteDate]
        );
        return result.rows[0];
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