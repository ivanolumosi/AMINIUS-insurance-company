import { Router } from 'express';
import { SearchController } from '../controllers/search.controller';

const router = Router();
const controller = new SearchController();

// Global Search
router.get('/:agentId/global', controller.globalSearch.bind(controller));

// Entity-specific searches
router.get('/:agentId/clients', controller.searchClients.bind(controller));
router.get('/:agentId/appointments', controller.searchAppointments.bind(controller));
router.get('/:agentId/policies', controller.searchPolicies.bind(controller));
router.get('/:agentId/reminders', controller.searchReminders.bind(controller));

// Suggestions & History
router.get('/:agentId/suggestions', controller.getSearchSuggestions.bind(controller));
router.get('/:agentId/history', controller.getSearchHistory.bind(controller));

export default router;
