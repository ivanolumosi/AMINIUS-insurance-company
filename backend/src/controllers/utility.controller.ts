// controllers/utility.controller.ts
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
        try {
            const result = await validateEmail(req.query.email as string);
            res.json(result);
        } catch (error) {
            console.error('Error validating email:', error);
            res.status(500).json({ 
                Success: false, 
                Message: 'Internal server error',
                Error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    async validateNationalId(req: Request, res: Response) {
        try {
            const result = await validateNationalId(req.query.nationalId as string);
            res.json(result);
        } catch (error) {
            console.error('Error validating national ID:', error);
            res.status(500).json({ 
                Success: false, 
                Message: 'Internal server error',
                Error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    async validateDate(req: Request, res: Response) {
        try {
            const { dateValue, minDate, maxDate } = req.query;
            const result = await validateDate(dateValue as string, minDate as string, maxDate as string);
            res.json(result);
        } catch (error) {
            console.error('Error validating date:', error);
            res.status(500).json({ 
                Success: false, 
                Message: 'Internal server error',
                Error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    async validateTimeRange(req: Request, res: Response) {
        try {
            const { startTime, endTime } = req.query;
            const result = await validateTimeRange(startTime as string, endTime as string);
            res.json(result);
        } catch (error) {
            console.error('Error validating time range:', error);
            res.status(500).json({ 
                Success: false, 
                Message: 'Internal server error',
                Error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    async checkDataIntegrity(req: Request, res: Response) {
        try {
            const { agentId } = req.params;
            const result = await checkDataIntegrity(agentId);
            res.json(result);
        } catch (error) {
            console.error('Error checking data integrity:', error);
            res.status(500).json({ 
                Success: false, 
                Message: 'Internal server error',
                Error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    async formatPhoneNumber(req: Request, res: Response) {
        try {
            const { phoneNumber, countryCode } = req.query;
            const result = await formatPhoneNumber(phoneNumber as string, countryCode as string);
            res.json(result);
        } catch (error) {
            console.error('Error formatting phone number:', error);
            res.status(500).json({ 
                Success: false, 
                Message: 'Internal server error',
                Error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    // ===== Utility =====
    async getGreeting(req: Request, res: Response) {
        try {
            const result = await getGreeting();
            res.json(result);
        } catch (error) {
            console.error('Error getting greeting:', error);
            res.status(500).json({ 
                Success: false, 
                Message: 'Internal server error',
                Error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    async parseTemplate(req: Request, res: Response) {
        try {
            const { template, data } = req.body;
            const result = await parseTemplate(template, data);
            res.json(result);
        } catch (error) {
            console.error('Error parsing template:', error);
            res.status(500).json({ 
                Success: false, 
                Message: 'Internal server error',
                Error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    async generateRandomPassword(req: Request, res: Response) {
        try {
            const { length } = req.query;
            const result = await generateRandomPassword(length ? parseInt(length as string) : undefined);
            res.json(result);
        } catch (error) {
            console.error('Error generating random password:', error);
            res.status(500).json({ 
                Success: false, 
                Message: 'Internal server error',
                Error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    async calculateAge(req: Request, res: Response) {
        try {
            const { dateOfBirth } = req.query;
            const result = await calculateAge(dateOfBirth as string);
            res.json({ age: result });
        } catch (error) {
            console.error('Error calculating age:', error);
            res.status(500).json({ 
                Success: false, 
                Message: 'Internal server error',
                Error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    async daysUntilExpiry(req: Request, res: Response) {
        try {
            const { expiryDate } = req.query;
            const result = await daysUntilExpiry(expiryDate as string);
            res.json({ daysUntil: result });
        } catch (error) {
            console.error('Error calculating days until expiry:', error);
            res.status(500).json({ 
                Success: false, 
                Message: 'Internal server error',
                Error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    async formatClientName(req: Request, res: Response) {
        try {
            const { firstName, surname, lastName } = req.query;
            const result = await formatClientName(firstName as string, surname as string, lastName as string);
            res.json({ formattedName: result });
        } catch (error) {
            console.error('Error formatting client name:', error);
            res.status(500).json({ 
                Success: false, 
                Message: 'Internal server error',
                Error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    async formatCurrency(req: Request, res: Response) {
        try {
            const { amount } = req.query;
            const result = await formatCurrency(Number(amount));
            res.json({ formattedCurrency: result });
        } catch (error) {
            console.error('Error formatting currency:', error);
            res.status(500).json({ 
                Success: false, 
                Message: 'Internal server error',
                Error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    async getStatusColor(req: Request, res: Response) {
        try {
            const result = await getStatusColor(req.query.status as string);
            res.json({ statusColor: result });
        } catch (error) {
            console.error('Error getting status color:', error);
            res.status(500).json({ 
                Success: false, 
                Message: 'Internal server error',
                Error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    async getPriorityColor(req: Request, res: Response) {
        try {
            const result = await getPriorityColor(req.query.priority as string);
            res.json({ priorityColor: result });
        } catch (error) {
            console.error('Error getting priority color:', error);
            res.status(500).json({ 
                Success: false, 
                Message: 'Internal server error',
                Error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    async getAppointmentTypeIcon(req: Request, res: Response) {
        try {
            const result = await getAppointmentTypeIcon(req.query.type as string);
            res.json({ typeIcon: result });
        } catch (error) {
            console.error('Error getting appointment type icon:', error);
            res.status(500).json({ 
                Success: false, 
                Message: 'Internal server error',
                Error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    // ===== Notifications =====
    async sendEmail(req: Request, res: Response) {
        try {
            const { agentId } = req.params;
            const { toEmail, subject, body } = req.body;
            const result = await sendEmailNotification(agentId, toEmail, subject, body);
            res.json(result);
        } catch (error) {
            console.error('Error sending email notification:', error);
            res.status(500).json({ 
                Success: false, 
                Message: 'Internal server error',
                Error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    async sendSMS(req: Request, res: Response) {
        try {
            const { agentId } = req.params;
            const { phoneNumber, message } = req.body;
            const result = await sendSMSNotification(agentId, phoneNumber, message);
            res.json(result);
        } catch (error) {
            console.error('Error sending SMS notification:', error);
            res.status(500).json({ 
                Success: false, 
                Message: 'Internal server error',
                Error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    async sendWhatsApp(req: Request, res: Response) {
        try {
            const { agentId } = req.params;
            const { phoneNumber, message } = req.body;
            const result = await sendWhatsAppNotification(agentId, phoneNumber, message);
            res.json(result);
        } catch (error) {
            console.error('Error sending WhatsApp notification:', error);
            res.status(500).json({ 
                Success: false, 
                Message: 'Internal server error',
                Error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    async sendPush(req: Request, res: Response) {
        try {
            const { agentId } = req.params;
            const { title, body } = req.body;
            const result = await sendPushNotification(agentId, title, body);
            res.json(result);
        } catch (error) {
            console.error('Error sending push notification:', error);
            res.status(500).json({ 
                Success: false, 
                Message: 'Internal server error',
                Error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    async scheduleNotification(req: Request, res: Response) {
        try {
            const { agentId } = req.params;
            const { scheduledTime, notificationType, recipient, body, subject } = req.body;
            const result = await scheduleNotification(agentId, scheduledTime, notificationType, recipient, body, subject);
            res.json(result);
        } catch (error) {
            console.error('Error scheduling notification:', error);
            res.status(500).json({ 
                Success: false, 
                Message: 'Internal server error',
                Error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    async cancelScheduledNotification(req: Request, res: Response) {
        try {
            const { notificationId, agentId } = req.params;
            const result = await cancelScheduledNotification(notificationId, agentId);
            res.json(result);
        } catch (error) {
            console.error('Error canceling scheduled notification:', error);
            res.status(500).json({ 
                Success: false, 
                Message: 'Internal server error',
                Error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    async processScheduled(req: Request, res: Response) {
        try {
            const result = await processScheduledNotifications();
            res.json(result);
        } catch (error) {
            console.error('Error processing scheduled notifications:', error);
            res.status(500).json({ 
                Success: false, 
                Message: 'Internal server error',
                Error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    async getNotificationHistory(req: Request, res: Response) {
        try {
            const { agentId } = req.params;
            const options = req.query as any;
            const result = await getNotificationHistory(agentId, options);
            res.json(result);
        } catch (error) {
            console.error('Error getting notification history:', error);
            res.status(500).json({ 
                Success: false, 
                Message: 'Internal server error',
                Error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    async updateNotificationStatus(req: Request, res: Response) {
        try {
            const { notificationId } = req.params;
            const { status, errorMessage } = req.body;
            const result = await updateNotificationStatus(notificationId, status, errorMessage);
            res.json(result);
        } catch (error) {
            console.error('Error updating notification status:', error);
            res.status(500).json({ 
                Success: false, 
                Message: 'Internal server error',
                Error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }
}