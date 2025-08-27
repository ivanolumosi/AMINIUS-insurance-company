// routes/utility.routes.ts
import { Router } from 'express';
import { UtilityController } from '../controllers/utility.controller';

const router = Router();
const controller = new UtilityController();

// Validation
router.get('/validate/email', controller.validateEmail.bind(controller));
router.get('/validate/national-id', controller.validateNationalId.bind(controller));
router.get('/validate/date', controller.validateDate.bind(controller));
router.get('/validate/time-range', controller.validateTimeRange.bind(controller));
router.get('/:agentId/data-integrity', controller.checkDataIntegrity.bind(controller));
router.get('/format/phone', controller.formatPhoneNumber.bind(controller));

// Utility
router.get('/greeting', controller.getGreeting.bind(controller));
router.post('/template/parse', controller.parseTemplate.bind(controller));
router.get('/password/random', controller.generateRandomPassword.bind(controller));
router.get('/calculate/age', controller.calculateAge.bind(controller));
router.get('/calculate/days-until-expiry', controller.daysUntilExpiry.bind(controller));
router.get('/format/client-name', controller.formatClientName.bind(controller));
router.get('/format/currency', controller.formatCurrency.bind(controller));
router.get('/color/status', controller.getStatusColor.bind(controller));
router.get('/color/priority', controller.getPriorityColor.bind(controller));
router.get('/icon/appointment-type', controller.getAppointmentTypeIcon.bind(controller));

// Notifications
router.post('/:agentId/notifications/email', controller.sendEmail.bind(controller));
router.post('/:agentId/notifications/sms', controller.sendSMS.bind(controller));
router.post('/:agentId/notifications/whatsapp', controller.sendWhatsApp.bind(controller));
router.post('/:agentId/notifications/push', controller.sendPush.bind(controller));
router.post('/:agentId/notifications/schedule', controller.scheduleNotification.bind(controller));
router.delete('/:agentId/notifications/:notificationId', controller.cancelScheduledNotification.bind(controller));
router.get('/notifications/process', controller.processScheduled.bind(controller));
router.get('/:agentId/notifications/history', controller.getNotificationHistory.bind(controller));
router.put('/notifications/:notificationId/status', controller.updateNotificationStatus.bind(controller));

export default router;