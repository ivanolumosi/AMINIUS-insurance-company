import { Router } from 'express';
import { SearchController } from '../controllers/search.controller';

const router = Router();
const controller = new SearchController();

// ==================
// Specific routes first (to avoid conflicts)
// ==================

// Advanced search with filters
router.get('/:agentId/advanced', controller.advancedSearch.bind(controller));

// Popular search terms analytics
router.get('/:agentId/popular', controller.getPopularSearchTerms.bind(controller));

// Search suggestions for autocomplete
router.get('/:agentId/suggestions', controller.getSearchSuggestions.bind(controller));

// Search history management
router.get('/:agentId/history', controller.getSearchHistory.bind(controller));
router.delete('/:agentId/history', controller.clearSearchHistory.bind(controller));
router.delete('/:agentId/history/:searchHistoryId', controller.deleteSearchHistoryItem.bind(controller));

// Global search across all entities
router.get('/:agentId/global', controller.globalSearch.bind(controller));

// ==================
// Entity-specific searches
// ==================

// Search clients
router.get('/:agentId/clients', controller.searchClients.bind(controller));

// Search appointments
router.get('/:agentId/appointments', controller.searchAppointments.bind(controller));

// Search policies
router.get('/:agentId/policies', controller.searchPolicies.bind(controller));

// Search reminders
router.get('/:agentId/reminders', controller.searchReminders.bind(controller));

export default router;