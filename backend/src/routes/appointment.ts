import { Router } from 'express';
import { AppointmentController } from '../controllers/appointments';

const router = Router();
const controller = new AppointmentController();

// ==================
// Specific routes first
// ==================
router.get('/:agentId/today', controller.getToday.bind(controller));
router.get('/:agentId/date', controller.getForDate.bind(controller));
router.get('/:agentId/week', controller.getWeekView.bind(controller));
router.get('/:agentId/calendar', controller.getCalendar.bind(controller));
router.get('/:agentId/statistics', controller.getStatistics.bind(controller));

// 🔍 Client search for autocomplete
router.get('/:agentId/clients/search', controller.searchClients.bind(controller));

// General search in appointments
router.get('/:agentId/search', controller.search.bind(controller));

// ==================
// CRUD routes
// ==================
router.post('/:agentId', controller.create.bind(controller));
router.put('/:agentId/:appointmentId', controller.update.bind(controller));
router.get('/:agentId/:appointmentId', controller.getById.bind(controller));
router.get('/:agentId', controller.getAllAppointments.bind(controller));
router.delete('/:agentId/:appointmentId', controller.delete.bind(controller));

// Status update
router.put('/:agentId/:appointmentId/status', controller.updateStatus.bind(controller));

// Conflict check
router.post('/:agentId/check-conflicts', controller.checkConflicts.bind(controller));

export default router;
