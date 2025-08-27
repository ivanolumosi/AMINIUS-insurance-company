import { Router } from 'express';
import { AppointmentController } from '../controllers/appointments';

const router = Router();
const controller = new AppointmentController();

// ==================
// Specific routes first (to avoid conflicts with general routes)
// ==================

// Week view appointments
router.get('/:agentId/week', controller.getWeekView.bind(controller));

// Calendar appointments (requires month and year query params)
router.get('/:agentId/calendar', controller.getCalendar.bind(controller));

// Appointment statistics
router.get('/:agentId/statistics', controller.getStatistics.bind(controller));

// Client search for autocomplete (requires 'q' query parameter)
router.get('/:agentId/clients/search', controller.searchClients.bind(controller));

// Time conflict checking
router.post('/:agentId/check-conflicts', controller.checkConflicts.bind(controller));

// ==================
// CRUD routes
// ==================

// Create new appointment
router.post('/:agentId', controller.create.bind(controller));

// Update existing appointment
router.put('/:agentId/:appointmentId', controller.update.bind(controller));

// Get appointment by ID
router.get('/:agentId/:appointmentId', controller.getById.bind(controller));

// Get all appointments with optional filters
// Supports query params: startDate, endDate, status, type, priority, clientId, searchTerm, pageSize, pageNumber
router.get('/:agentId', controller.getAll.bind(controller));

// Delete appointment
router.delete('/:agentId/:appointmentId', controller.delete.bind(controller));

export default router;