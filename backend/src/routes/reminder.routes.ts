// =============================================
// UPDATED REMINDER ROUTES - routes/reminder.routes.ts
// Fixed to match both frontend service and controller expectations
// =============================================

import { Router } from 'express';
import { RemindersController } from '../controllers/reminder.controller';

const router = Router();
const remindersController = new RemindersController();

// =============================================
// UTILITY ROUTES (Must come first to avoid conflicts)
// =============================================

// Validate phone number
// POST /api/reminders/validate-phone
// Body: { phoneNumber: string, countryCode?: string }
router.post('/validate-phone', remindersController.validatePhoneNumber);

// =============================================
// SPECIFIC ROUTES (Must come before parameterized routes)
// =============================================

// Get today's reminders (backward compatibility)
// GET /api/reminders/today
// Headers: x-agent-id (required)
router.get('/today', remindersController.getTodayReminders);

// Get reminder statistics (backward compatibility)
// GET /api/reminders/statistics
// Headers: x-agent-id (required)
router.get('/statistics', remindersController.getReminderStatistics);

// Get reminder settings (backward compatibility)
// GET /api/reminders/settings
// Headers: x-agent-id (required)
router.get('/settings', remindersController.getReminderSettings);

// Update reminder settings (backward compatibility)
// PUT /api/reminders/settings
// Headers: x-agent-id (required)
router.put('/settings', remindersController.updateReminderSettings);

// Get birthday reminders (backward compatibility)
// GET /api/reminders/birthdays
// Headers: x-agent-id (required)
router.get('/birthdays', remindersController.getBirthdayReminders);

// Get policy expiry reminders (backward compatibility)
// GET /api/reminders/policy-expiry
// Headers: x-agent-id (required)
router.get('/policy-expiry', remindersController.getPolicyExpiryReminders);

// Get reminders by type (backward compatibility)
// GET /api/reminders/type/:reminderType
// Headers: x-agent-id (required)
router.get('/type/:reminderType', remindersController.getRemindersByType);

// Get reminders by status (backward compatibility)
// GET /api/reminders/status/:status
// Headers: x-agent-id (required)
router.get('/status/:status', remindersController.getRemindersByStatus);

// =============================================
// AGENT-SPECIFIC ROUTES (Frontend expects these patterns)
// =============================================

// Get reminder statistics for an agent
// GET /api/reminders/{agentId}/statistics
router.get('/:agentId/statistics', remindersController.getReminderStatistics);

// Get reminder settings for an agent
// GET /api/reminders/{agentId}/settings
router.get('/:agentId/settings', remindersController.getReminderSettings);

// Update reminder settings for an agent
// PUT /api/reminders/{agentId}/settings
// Body: ReminderSettings
router.put('/:agentId/settings', remindersController.updateReminderSettings);

// Get today's reminders for an agent
// GET /api/reminders/{agentId}/today
router.get('/:agentId/today', remindersController.getTodayReminders);

// Get birthday reminders
// GET /api/reminders/{agentId}/birthdays
router.get('/:agentId/birthdays', remindersController.getBirthdayReminders);

// Get policy expiry reminders
// GET /api/reminders/{agentId}/policy-expiry
// Query params: daysAhead? (default: 30)
router.get('/:agentId/policy-expiry', remindersController.getPolicyExpiryReminders);

// Get reminders by type
// GET /api/reminders/{agentId}/type/{reminderType}
router.get('/:agentId/type/:reminderType', remindersController.getRemindersByType);

// Get reminders by status
// GET /api/reminders/{agentId}/status/{status}
router.get('/:agentId/status/:status', remindersController.getRemindersByStatus);

// Complete a reminder
// POST /api/reminders/{agentId}/{reminderId}/complete
// Body: { notes?: string }
router.post('/:agentId/:reminderId/complete', remindersController.completeReminder);

// =============================================
// MAIN CRUD ROUTES (These must come after specific routes)
// =============================================

// Create a new reminder
// POST /api/reminders/{agentId}
// Body: CreateReminderRequest
router.post('/:agentId', remindersController.createReminder);

// Get all reminders with pagination and filters
// GET /api/reminders/{agentId}
// Query params: ReminderType?, Status?, Priority?, StartDate?, EndDate?, ClientId?, PageSize?, PageNumber?
router.get('/:agentId', remindersController.getAllReminders);

// Get reminder by ID
// GET /api/reminders/{agentId}/{reminderId}
router.get('/:agentId/:reminderId', remindersController.getReminderById);

// Update a reminder
// PUT /api/reminders/{agentId}/{reminderId}
// Body: UpdateReminderRequest
router.put('/:agentId/:reminderId', remindersController.updateReminder);

// Delete a reminder
// DELETE /api/reminders/{agentId}/{reminderId}
router.delete('/:agentId/:reminderId', remindersController.deleteReminder);

// =============================================
// LEGACY ROUTES (Using headers for backward compatibility)
// =============================================

// Create reminder (legacy)
// POST /api/reminders
// Headers: x-agent-id (required)
router.post('/', remindersController.createReminder);

// Get reminder by ID (legacy)
// GET /api/reminders/{reminderId}
// Headers: x-agent-id (required)
router.get('/:reminderId', remindersController.getReminderById);

// Update reminder (legacy)
// PUT /api/reminders/{reminderId}
// Headers: x-agent-id (required)
router.put('/:reminderId', remindersController.updateReminder);

// Delete reminder (legacy)
// DELETE /api/reminders/{reminderId}
// Headers: x-agent-id (required)
router.delete('/:reminderId', remindersController.deleteReminder);

// Complete reminder (legacy)
// POST /api/reminders/{reminderId}/complete
// Headers: x-agent-id (required)
router.post('/:reminderId/complete', remindersController.completeReminder);

export default router;