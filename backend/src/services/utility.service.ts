// services/utility.service.ts
import { poolPromise } from '../../db';
import {
    ValidationResult,
    NationalIdValidationResult,
    DataIntegrityIssue,
    PhoneNumberFormatResult
} from '../interfaces/utility';
import {
    GreetingResult,
    ParsedTemplateResult,
    RandomPasswordResult,
    TemplateData
} from '../interfaces/utility';
import {
    NotificationResult,
    Notification,
    ScheduledNotification,
    NotificationHistoryRequest,
    NotificationHistoryResult,
    UpdateNotificationStatusResult,
    CancelNotificationResult
} from '../interfaces/utility';

export class ValidationService {
    /**
     * Validate email format
     */
    public async validateEmail(email: string): Promise<ValidationResult> {
        const pool = await poolPromise;
        const result = await pool.query('SELECT * FROM sp_validate_email($1)', [email]);
        return result.rows[0];
    }

    /**
     * Validate Kenyan National ID
     */
    public async validateNationalId(nationalId: string): Promise<NationalIdValidationResult> {
        const pool = await poolPromise;
        const result = await pool.query('SELECT * FROM sp_validate_national_id($1)', [nationalId]);
        return result.rows[0];
    }

    /**
     * Validate date with optional range
     */
    public async validateDate(dateValue: string, minDate?: string, maxDate?: string): Promise<ValidationResult> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_validate_date($1, $2, $3)', 
            [dateValue, minDate || null, maxDate || null]
        );
        return result.rows[0];
    }

    /**
     * Validate time range
     */
    public async validateTimeRange(startTime: string, endTime: string): Promise<ValidationResult> {
        const pool = await poolPromise;
        const result = await pool.query('SELECT * FROM sp_validate_time_range($1, $2)', [startTime, endTime]);
        return result.rows[0];
    }

    /**
     * Check data integrity for an agent
     */
    public async checkDataIntegrity(agentId: string): Promise<DataIntegrityIssue[]> {
        const pool = await poolPromise;
        const result = await pool.query('SELECT * FROM sp_check_data_integrity($1)', [agentId]);
        return result.rows;
    }

    /**
     * Format phone number
     */
    public async formatPhoneNumber(phoneNumber: string, countryCode: string = '+254'): Promise<PhoneNumberFormatResult> {
        const pool = await poolPromise;
        const result = await pool.query('SELECT * FROM sp_format_phone_number($1, $2)', [phoneNumber, countryCode]);
        return result.rows[0];
    }
}

export class UtilityService {
    /**
     * Get time-based greeting
     */
    public async getGreeting(): Promise<GreetingResult> {
        const pool = await poolPromise;
        const result = await pool.query('SELECT * FROM sp_get_greeting()');
        return result.rows[0];
    }

    /**
     * Parse template with data
     */
    public async parseTemplate(template: string, data?: TemplateData): Promise<ParsedTemplateResult> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_parse_template($1, $2, $3, $4, $5, $6)',
            [
                template,
                data?.ClientName || null,
                data?.AgentName || null,
                data?.PolicyType || null,
                data?.ExpiryDate || null,
                data?.CompanyName || null
            ]
        );
        return result.rows[0];
    }

    /**
     * Generate random password
     */
    public async generateRandomPassword(length: number = 12): Promise<RandomPasswordResult> {
        const pool = await poolPromise;
        const result = await pool.query('SELECT * FROM sp_generate_random_password($1)', [length]);
        return result.rows[0];
    }

    /**
     * Utility functions using SQL functions (implemented as direct queries)
     */
    public async calculateAge(dateOfBirth: string): Promise<number> {
        const pool = await poolPromise;
        const result = await pool.query('SELECT fn_calculate_age($1) AS age', [dateOfBirth]);
        return result.rows[0].age;
    }

    public async daysUntilExpiry(expiryDate: string): Promise<number> {
        const pool = await poolPromise;
        const result = await pool.query('SELECT fn_days_until_expiry($1) AS days_until', [expiryDate]);
        return result.rows[0].days_until;
    }

    public async formatClientName(firstName: string, surname: string, lastName?: string): Promise<string> {
        const pool = await poolPromise;
        const result = await pool.query('SELECT fn_format_client_name($1, $2, $3) AS formatted_name', [firstName, surname, lastName || null]);
        return result.rows[0].formatted_name;
    }

    public async formatCurrency(amount: number): Promise<string> {
        const pool = await poolPromise;
        const result = await pool.query('SELECT fn_format_currency($1) AS formatted_currency', [amount]);
        return result.rows[0].formatted_currency;
    }

    public async getStatusColor(status: string): Promise<string> {
        const pool = await poolPromise;
        const result = await pool.query('SELECT fn_get_status_color($1) AS status_color', [status]);
        return result.rows[0].status_color;
    }

    public async getPriorityColor(priority: string): Promise<string> {
        const pool = await poolPromise;
        const result = await pool.query('SELECT fn_get_priority_color($1) AS priority_color', [priority]);
        return result.rows[0].priority_color;
    }

    public async getAppointmentTypeIcon(type: string): Promise<string> {
        const pool = await poolPromise;
        const result = await pool.query('SELECT fn_get_appointment_type_icon($1) AS type_icon', [type]);
        return result.rows[0].type_icon;
    }
}

export class NotificationService {
    /**
     * Send email notification
     */
    public async sendEmailNotification(agentId: string, toEmail: string, subject: string, body: string): Promise<NotificationResult> {
        const pool = await poolPromise;
        const result = await pool.query('SELECT * FROM sp_send_email_notification($1, $2, $3, $4)', [agentId, toEmail, subject, body]);
        return result.rows[0];
    }

    /**
     * Send SMS notification
     */
    public async sendSMSNotification(agentId: string, phoneNumber: string, message: string): Promise<NotificationResult> {
        const pool = await poolPromise;
        const result = await pool.query('SELECT * FROM sp_send_sms_notification($1, $2, $3)', [agentId, phoneNumber, message]);
        return result.rows[0];
    }

    /**
     * Send WhatsApp notification
     */
    public async sendWhatsAppNotification(agentId: string, phoneNumber: string, message: string): Promise<NotificationResult> {
        const pool = await poolPromise;
        const result = await pool.query('SELECT * FROM sp_send_whatsapp_notification($1, $2, $3)', [agentId, phoneNumber, message]);
        return result.rows[0];
    }

    /**
     * Send push notification
     */
    public async sendPushNotification(agentId: string, title: string, body: string): Promise<NotificationResult> {
        const pool = await poolPromise;
        const result = await pool.query('SELECT * FROM sp_send_push_notification($1, $2, $3)', [agentId, title, body]);
        return result.rows[0];
    }

    /**
     * Schedule notification
     */
    public async scheduleNotification(
        agentId: string,
        scheduledTime: string,
        notificationType: 'Email' | 'SMS' | 'WhatsApp' | 'Push',
        recipient: string,
        body: string,
        subject?: string
    ): Promise<{ notification_id: string }> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_schedule_notification($1, $2, $3, $4, $5, $6)',
            [agentId, scheduledTime, notificationType, recipient, subject || null, body]
        );
        return result.rows[0];
    }

    /**
     * Cancel scheduled notification
     */
    public async cancelScheduledNotification(notificationId: string, agentId: string): Promise<CancelNotificationResult> {
        const pool = await poolPromise;
        const result = await pool.query('SELECT * FROM sp_cancel_scheduled_notification($1, $2)', [notificationId, agentId]);
        return result.rows[0];
    }

    /**
     * Process scheduled notifications
     */
    public async processScheduledNotifications(): Promise<ScheduledNotification[]> {
        const pool = await poolPromise;
        const result = await pool.query('SELECT * FROM sp_process_scheduled_notifications()');
        return result.rows;
    }

    /**
     * Get notification history
     */
    public async getNotificationHistory(
        agentId: string,
        options?: NotificationHistoryRequest
    ): Promise<NotificationHistoryResult> {
        const pool = await poolPromise;
        
        // First query for notifications
        const notificationsResult = await pool.query(
            'SELECT * FROM sp_get_notification_history($1, $2, $3, $4, $5, $6, $7)',
            [
                agentId,
                options?.StartDate || null,
                options?.EndDate || null,
                options?.NotificationType || null,
                options?.Status || null,
                options?.PageSize || null,
                options?.PageNumber || null
            ]
        );

        // Second query for total count
        const countResult = await pool.query(
            'SELECT * FROM sp_get_notification_history_count($1, $2, $3, $4, $5)',
            [
                agentId,
                options?.StartDate || null,
                options?.EndDate || null,
                options?.NotificationType || null,
                options?.Status || null
            ]
        );

        return {
            notifications: notificationsResult.rows,
            totalRecords: countResult.rows[0]?.total_records || 0
        };
    }

    /**
     * Update notification status
     */
    public async updateNotificationStatus(
        notificationId: string, 
        status: 'Pending' | 'Sent' | 'Failed' | 'Cancelled', 
        errorMessage?: string
    ): Promise<UpdateNotificationStatusResult> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_update_notification_status($1, $2, $3)',
            [notificationId, status, errorMessage || null]
        );
        return result.rows[0];
    }
}

// Export individual service instances
const validationService = new ValidationService();
const utilityService = new UtilityService();
const notificationService = new NotificationService();

// Export ValidationService functions
export const validateEmail = (email: string) => 
    validationService.validateEmail(email);

export const validateNationalId = (nationalId: string) => 
    validationService.validateNationalId(nationalId);

export const validateDate = (dateValue: string, minDate?: string, maxDate?: string) => 
    validationService.validateDate(dateValue, minDate, maxDate);

export const validateTimeRange = (startTime: string, endTime: string) => 
    validationService.validateTimeRange(startTime, endTime);

export const checkDataIntegrity = (agentId: string) => 
    validationService.checkDataIntegrity(agentId);

export const formatPhoneNumber = (phoneNumber: string, countryCode?: string) => 
    validationService.formatPhoneNumber(phoneNumber, countryCode);

// Export UtilityService functions
export const getGreeting = () => 
    utilityService.getGreeting();

export const parseTemplate = (template: string, data?: TemplateData) => 
    utilityService.parseTemplate(template, data);

export const generateRandomPassword = (length?: number) => 
    utilityService.generateRandomPassword(length);

export const calculateAge = (dateOfBirth: string) => 
    utilityService.calculateAge(dateOfBirth);

export const daysUntilExpiry = (expiryDate: string) => 
    utilityService.daysUntilExpiry(expiryDate);

export const formatClientName = (firstName: string, surname: string, lastName?: string) => 
    utilityService.formatClientName(firstName, surname, lastName);

export const formatCurrency = (amount: number) => 
    utilityService.formatCurrency(amount);

export const getStatusColor = (status: string) => 
    utilityService.getStatusColor(status);

export const getPriorityColor = (priority: string) => 
    utilityService.getPriorityColor(priority);

export const getAppointmentTypeIcon = (type: string) => 
    utilityService.getAppointmentTypeIcon(type);

// Export NotificationService functions
export const sendEmailNotification = (agentId: string, toEmail: string, subject: string, body: string) => 
    notificationService.sendEmailNotification(agentId, toEmail, subject, body);

export const sendSMSNotification = (agentId: string, phoneNumber: string, message: string) => 
    notificationService.sendSMSNotification(agentId, phoneNumber, message);

export const sendWhatsAppNotification = (agentId: string, phoneNumber: string, message: string) => 
    notificationService.sendWhatsAppNotification(agentId, phoneNumber, message);

export const sendPushNotification = (agentId: string, title: string, body: string) => 
    notificationService.sendPushNotification(agentId, title, body);

export const scheduleNotification = (
    agentId: string,
    scheduledTime: string,
    notificationType: 'Email' | 'SMS' | 'WhatsApp' | 'Push',
    recipient: string,
    body: string,
    subject?: string
) => notificationService.scheduleNotification(agentId, scheduledTime, notificationType, recipient, body, subject);

export const cancelScheduledNotification = (notificationId: string, agentId: string) => 
    notificationService.cancelScheduledNotification(notificationId, agentId);

export const processScheduledNotifications = () => 
    notificationService.processScheduledNotifications();

export const getNotificationHistory = (agentId: string, options?: NotificationHistoryRequest) => 
    notificationService.getNotificationHistory(agentId, options);

export const updateNotificationStatus = (notificationId: string, status: 'Pending' | 'Sent' | 'Failed' | 'Cancelled', errorMessage?: string) => 
    notificationService.updateNotificationStatus(notificationId, status, errorMessage);