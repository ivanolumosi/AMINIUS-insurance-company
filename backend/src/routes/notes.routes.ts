// routes/notes.routes.ts
import { Router } from 'express';
import { NotesController } from '../controllers/notes.controller';

const router = Router();
const controller = new NotesController();

// ============================================
// SEARCH OPERATIONS (MOST SPECIFIC FIRST)
// ============================================
// Search notes by content
router.get('/:agentId/search', controller.searchNotes.bind(controller));

// ============================================
// DAILY NOTES OPERATIONS
// ============================================
// Get daily notes for specific date
router.get('/:agentId/:noteDate', controller.getDailyNotes.bind(controller));

// Save/Update daily notes for specific date
router.post('/:agentId/:noteDate', controller.saveDailyNotes.bind(controller));

// Delete notes for specific date
router.delete('/:agentId/:noteDate', controller.deleteNotes.bind(controller));

// ============================================
// GENERAL NOTES OPERATIONS (LEAST SPECIFIC)
// ============================================
// Get all notes with optional date range filtering
// Query params: ?StartDate=YYYY-MM-DD&EndDate=YYYY-MM-DD
router.get('/:agentId', controller.getAllNotes.bind(controller));

export default router;