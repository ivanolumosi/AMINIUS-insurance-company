import { Router } from 'express';
import { NotesController } from '../controllers/notes.controller';

const router = Router();
const controller = new NotesController();

// Daily notes
router.get('/:agentId/:noteDate', controller.getDailyNotes.bind(controller));
router.post('/:agentId/:noteDate', controller.saveDailyNotes.bind(controller));

// All notes in a range
router.get('/:agentId', controller.getAllNotes.bind(controller));

// Search notes
router.get('/:agentId/search', controller.searchNotes.bind(controller));

// Delete notes
router.delete('/:agentId/:noteDate', controller.deleteNotes.bind(controller));

export default router;
