// interfaces/Notes.ts
export interface DailyNote {
    NoteId: string;
    AgentId: string;
    NoteDate: string; // DATE as string
    Notes: string;
    CreatedDate: string; // DATETIME2 as string
    ModifiedDate: string; // DATETIME2 as string
}

export interface SaveNotesResult {
    RowsAffected: number;
}

export interface DeleteNotesResult {
    RowsAffected: number;
}

export interface NotesDateRange {
    StartDate?: string;
    EndDate?: string;
}