import { Request, Response } from 'express';
import {
    validateEmail,
    validateNationalId,
    validateDate,
    validateTimeRange,
    checkDataIntegrity,
    formatPhoneNumber,
    getGreeting,
    parseTemplate,
    generateRandomPassword,
    calculateAge,
    daysUntilExpiry,
    formatClientName,
    formatCurrency,
    getStatusColor,
    getPriorityColor,
    getAppointmentTypeIcon,
    sendEmailNotification,
    sendSMSNotification,
    sendWhatsAppNotification,
    sendPushNotification,
    scheduleNotification,
    cancelScheduledNotification,
    processScheduledNotifications,
    getNotificationHistory,
    updateNotificationStatus
} from '../services/utility.service';

export class UtilityController {
    // ===== Validation =====
    async validateEmail(req: Request, res: Response) {
        const result = await validateEmail(req.query.email as string);
        res.json(result);
    }

    async validateNationalId(req: Request, res: Response) {
        const result = await validateNationalId(req.query.nationalId as string);
        res.json(result);
    }

    async validateDate(req: Request, res: Response) {
        const { dateValue, minDate, maxDate } = req.query;
        const result = await validateDate(dateValue as string, minDate as string, maxDate as string);
        res.json(result);
    }

    async validateTimeRange(req: Request, res: Response) {
        const { startTime, endTime } = req.query;
        const result = await validateTimeRange(startTime as string, endTime as string);
        res.json(result);
    }

    async checkDataIntegrity(req: Request, res: Response) {
        const { agentId } = req.params;
        const result = await checkDataIntegrity(agentId);
        res.json(result);
    }

    async formatPhoneNumber(req: Request, res: Response) {
        const { phoneNumber, countryCode } = req.query;
        const result = await formatPhoneNumber(phoneNumber as string, countryCode as string);
        res.json(result);
    }

    // ===== Utility =====
    async getGreeting(req: Request, res: Response) {
        const result = await getGreeting();
        res.json(result);
    }

    async parseTemplate(req: Request, res: Response) {
        const { template, data } = req.body;
        const result = await parseTemplate(template, data);
        res.json(result);
    }

    async generateRandomPassword(req: Request, res: Response) {
        const { length } = req.query;
        const result = await generateRandomPassword(length ? parseInt(length as string) : undefined);
        res.json(result);
    }

    async calculateAge(req: Request, res: Response) {
        const { dateOfBirth } = req.query;
        const result = await calculateAge(dateOfBirth as string);
        res.json({ age: result });
    }

    async daysUntilExpiry(req: Request, res: Response) {
        const { expiryDate } = req.query;
        const result = await daysUntilExpiry(expiryDate as string);
        res.json({ daysUntil: result });
    }

    async formatClientName(req: Request, res: Response) {
        const { firstName, surname, lastName } = req.query;
        const result = await formatClientName(firstName as string, surname as string, lastName as string);
        res.json({ formattedName: result });
    }

    async formatCurrency(req: Request, res: Response) {
        const { amount } = req.query;
        const result = await formatCurrency(Number(amount));
        res.json({ formattedCurrency: result });
    }

    async getStatusColor(req: Request, res: Response) {
        const result = await getStatusColor(req.query.status as string);
        res.json({ statusColor: result });
    }

    async getPriorityColor(req: Request, res: Response) {
        const result = await getPriorityColor(req.query.priority as string);
        res.json({ priorityColor: result });
    }

    async getAppointmentTypeIcon(req: Request, res: Response) {
        const result = await getAppointmentTypeIcon(req.query.type as string);
        res.json({ typeIcon: result });
    }

    // ===== Notifications =====
    async sendEmail(req: Request, res: Response) {
        const { agentId } = req.params;
        const { toEmail, subject, body } = req.body;
        const result = await sendEmailNotification(agentId, toEmail, subject, body);
        res.json(result);
    }

    async sendSMS(req: Request, res: Response) {
        const { agentId } = req.params;
        const { phoneNumber, message } = req.body;
        const result = await sendSMSNotification(agentId, phoneNumber, message);
        res.json(result);
    }

    async sendWhatsApp(req: Request, res: Response) {
        const { agentId } = req.params;
        const { phoneNumber, message } = req.body;
        const result = await sendWhatsAppNotification(agentId, phoneNumber, message);
        res.json(result);
    }

    async sendPush(req: Request, res: Response) {
        const { agentId } = req.params;
        const { title, body } = req.body;
        const result = await sendPushNotification(agentId, title, body);
        res.json(result);
    }

    async scheduleNotification(req: Request, res: Response) {
        const { agentId } = req.params;
        const { scheduledTime, notificationType, recipient, body, subject } = req.body;
        const result = await scheduleNotification(agentId, scheduledTime, notificationType, recipient, body, subject);
        res.json(result);
    }

    async cancelScheduledNotification(req: Request, res: Response) {
        const { notificationId, agentId } = req.params;
        const result = await cancelScheduledNotification(notificationId, agentId);
        res.json(result);
    }

    async processScheduled(req: Request, res: Response) {
        const result = await processScheduledNotifications();
        res.json(result);
    }

    async getNotificationHistory(req: Request, res: Response) {
        const { agentId } = req.params;
        const options = req.query;
        const result = await getNotificationHistory(agentId, options);
        res.json(result);
    }

    async updateNotificationStatus(req: Request, res: Response) {
        const { notificationId } = req.params;
        const { status, errorMessage } = req.body;
        const result = await updateNotificationStatus(notificationId, status, errorMessage);
        res.json(result);
    }
}
