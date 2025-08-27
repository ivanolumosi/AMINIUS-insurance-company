import { Router } from 'express';
import { RemindersController } from '../controllers/reminder.controller';

const router = Router();
const controller = new RemindersController();

/**
 * =====================
 * SPECIFIC ROUTES FIRST (to avoid conflicts with parameterized routes)
 * =====================
 */

// Statistics route - must come before /:agentId/:reminderId
router.get('/:agentId/statistics', controller.getReminderStatistics);

// Settings routes - must come before /:agentId/:reminderId
router.get('/:agentId/settings', controller.getSettings.bind(controller));
router.put('/:agentId/settings', controller.updateSettings.bind(controller));

// Filter routes - must come before /:agentId/:reminderId
router.get('/:agentId/type/:reminderType', (req, res) =>
  controller.getRemindersByType(req, res)
);

router.get('/:agentId/status/:status', (req, res) =>
  controller.getRemindersByStatus(req, res)
);

// Today's reminders - specific route
router.get('/:agentId/today', async (req, res) => {
  try {
    const { agentId } = req.params;
    const reminders = await controller.reminderService.getTodayReminders(agentId);
    res.json({
      success: true,
      data: reminders,
      message: "Today's reminders retrieved successfully"
    });
  } catch (error: any) {
    res.status(500).json({
      success: false,
      message: "Failed to get today's reminders",
      error: error.message
    });
  }
});

/**
 * =====================
 * Reminder CRUD (General parameterized routes come AFTER specific ones)
 * =====================
 */

// Create reminder
router.post('/:agentId', controller.create.bind(controller));

// Get all reminders (this is safe as it doesn't have additional params)
router.get('/:agentId', controller.getAll.bind(controller));

// Reminder actions with specific paths - these come before the general /:reminderId route
router.post('/:agentId/:reminderId/complete', controller.complete.bind(controller));

// Individual reminder CRUD - THESE MUST COME LAST due to the parameterized nature
router.get('/:agentId/:reminderId', controller.getById.bind(controller));
router.put('/:agentId/:reminderId', controller.update.bind(controller));
router.delete('/:agentId/:reminderId', controller.delete.bind(controller));

/**
 * =====================
 * Middleware for request logging (optional)
 * =====================
 */

// Log all reminder routes for debugging
router.use((req, res, next) => {
  console.log(`🛣️ Reminder Route: ${req.method} ${req.originalUrl}`);
  console.log(`🛣️ Params:`, req.params);
  console.log(`🛣️ Query:`, req.query);
  next();
});

export default router;