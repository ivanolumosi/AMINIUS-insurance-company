// src/routes/reminders.routes.ts
import { Router } from 'express';
import { RemindersController } from '../controllers/reminder.controller';

const router = Router();
const controller = new RemindersController();

// CRUD
router.post('/:agentId', controller.create.bind(controller));
router.get('/:agentId', controller.getAll.bind(controller));
router.get('/:agentId/:reminderId', controller.getById.bind(controller));
router.put('/:agentId/:reminderId', controller.update.bind(controller));
router.delete('/:agentId/:reminderId', controller.delete.bind(controller));
router.post('/:agentId/:reminderId/complete', controller.complete.bind(controller));

// Lists
router.get('/:agentId/today', controller.getToday.bind(controller));
router.get('/:agentId/upcoming', controller.getUpcoming.bind(controller));
router.get('/:agentId/completed', controller.getCompleted.bind(controller));
router.get('/:agentId/birthdays', controller.getBirthdays.bind(controller));
router.get('/:agentId/policy-expiries', controller.getPolicyExpiries.bind(controller));

// Settings
router.get('/:agentId/settings', controller.getSettings.bind(controller));
router.put('/:agentId/settings', controller.updateSettings.bind(controller));

// Utility
router.get('/:agentId/stats', controller.stats.bind(controller));
router.get('/:agentId/validate-phone', controller.validatePhone.bind(controller));

export default router;
