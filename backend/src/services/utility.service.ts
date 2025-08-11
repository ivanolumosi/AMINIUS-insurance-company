// services/utility.service.ts
import { poolPromise } from '../../db';
import * as sql from 'mssql';
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
        const result = await pool.request()
            .input('Email', sql.NVarChar(100), email)
            .execute('sp_ValidateEmail');

        return result.recordset[0];
    }

    /**
     * Validate Kenyan National ID
     */
    public async validateNationalId(nationalId: string): Promise<NationalIdValidationResult> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('NationalId', sql.NVarChar(20), nationalId)
            .execute('sp_ValidateNationalId');

        return result.recordset[0];
    }

    /**
     * Validate date with optional range
     */
    public async validateDate(dateValue: string, minDate?: string, maxDate?: string): Promise<ValidationResult> {
        const pool = await poolPromise;
        const request = pool.request()
            .input('DateValue', sql.Date, dateValue);

        if (minDate) {
            request.input('MinDate', sql.Date, minDate);
        }
        if (maxDate) {
            request.input('MaxDate', sql.Date, maxDate);
        }

        const result = await request.execute('sp_ValidateDate');
        return result.recordset[0];
    }

    /**
     * Validate time range
     */
    public async validateTimeRange(startTime: string, endTime: string): Promise<ValidationResult> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('StartTime', sql.Time, startTime)
            .input('EndTime', sql.Time, endTime)
            .execute('sp_ValidateTimeRange');

        return result.recordset[0];
    }

    /**
     * Check data integrity for an agent
     */
    public async checkDataIntegrity(agentId: string): Promise<DataIntegrityIssue[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .execute('sp_CheckDataIntegrity');

        return result.recordset;
    }

    /**
     * Format phone number
     */
    public async formatPhoneNumber(phoneNumber: string, countryCode: string = '+254'): Promise<PhoneNumberFormatResult> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('PhoneNumber', sql.NVarChar(20), phoneNumber)
            .input('CountryCode', sql.NVarChar(5), countryCode)
            .execute('sp_FormatPhoneNumber');

        return result.recordset[0];
    }
}

export class UtilityService {
    /**
     * Get time-based greeting
     */
    public async getGreeting(): Promise<GreetingResult> {
        const pool = await poolPromise;
        const result = await pool.request()
            .execute('sp_GetGreeting');

        return result.recordset[0];
    }

    /**
     * Parse template with data
     */
    public async parseTemplate(template: string, data?: TemplateData): Promise<ParsedTemplateResult> {
        const pool = await poolPromise;
        const request = pool.request()
            .input('Template', sql.NVarChar(sql.MAX), template);

        if (data?.ClientName) {
            request.input('ClientName', sql.NVarChar(150), data.ClientName);
        }
        if (data?.AgentName) {
            request.input('AgentName', sql.NVarChar(100), data.AgentName);
        }
        if (data?.PolicyType) {
            request.input('PolicyType', sql.NVarChar(50), data.PolicyType);
        }
        if (data?.ExpiryDate) {
            request.input('ExpiryDate', sql.Date, data.ExpiryDate);
        }
        if (data?.CompanyName) {
            request.input('CompanyName', sql.NVarChar(100), data.CompanyName);
        }

        const result = await request.execute('sp_ParseTemplate');
        return result.recordset[0];
    }

    /**
     * Generate random password
     */
    public async generateRandomPassword(length: number = 12): Promise<RandomPasswordResult> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('Length', sql.Int, length)
            .execute('sp_GenerateRandomPassword');

        return result.recordset[0];
    }

    /**
     * Utility functions using SQL functions (implemented as direct queries)
     */
    public async calculateAge(dateOfBirth: string): Promise<number> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('DateOfBirth', sql.Date, dateOfBirth)
            .query('SELECT dbo.fn_CalculateAge(@DateOfBirth) AS Age');

        return result.recordset[0].Age;
    }

    public async daysUntilExpiry(expiryDate: string): Promise<number> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('ExpiryDate', sql.Date, expiryDate)
            .query('SELECT dbo.fn_DaysUntilExpiry(@ExpiryDate) AS DaysUntil');

        return result.recordset[0].DaysUntil;
    }

    public async formatClientName(firstName: string, surname: string, lastName?: string): Promise<string> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('FirstName', sql.NVarChar(50), firstName)
            .input('Surname', sql.NVarChar(50), surname)
            .input('LastName', sql.NVarChar(50), lastName)
            .query('SELECT dbo.fn_FormatClientName(@FirstName, @Surname, @LastName) AS FormattedName');

        return result.recordset[0].FormattedName;
    }

    public async formatCurrency(amount: number): Promise<string> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('Amount', sql.Decimal(10, 2), amount)
            .query('SELECT dbo.fn_FormatCurrency(@Amount) AS FormattedCurrency');

        return result.recordset[0].FormattedCurrency;
    }

    public async getStatusColor(status: string): Promise<string> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('Status', sql.NVarChar(20), status)
            .query('SELECT dbo.fn_GetStatusColor(@Status) AS StatusColor');

        return result.recordset[0].StatusColor;
    }

    public async getPriorityColor(priority: string): Promise<string> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('Priority', sql.NVarChar(10), priority)
            .query('SELECT dbo.fn_GetPriorityColor(@Priority) AS PriorityColor');

        return result.recordset[0].PriorityColor;
    }

    public async getAppointmentTypeIcon(type: string): Promise<string> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('Type', sql.NVarChar(50), type)
            .query('SELECT dbo.fn_GetAppointmentTypeIcon(@Type) AS TypeIcon');

        return result.recordset[0].TypeIcon;
    }
}

export class NotificationService {
    /**
     * Send email notification
     */
    public async sendEmailNotification(agentId: string, toEmail: string, subject: string, body: string): Promise<NotificationResult> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('ToEmail', sql.NVarChar(200), toEmail)
            .input('Subject', sql.NVarChar(200), subject)
            .input('Body', sql.NVarChar(sql.MAX), body)
            .execute('sp_SendEmailNotification');

        return result.recordset[0];
    }

    /**
     * Send SMS notification
     */
    public async sendSMSNotification(agentId: string, phoneNumber: string, message: string): Promise<NotificationResult> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('PhoneNumber', sql.NVarChar(20), phoneNumber)
            .input('Message', sql.NVarChar(sql.MAX), message)
            .execute('sp_SendSMSNotification');

        return result.recordset[0];
    }

    /**
     * Send WhatsApp notification
     */
    public async sendWhatsAppNotification(agentId: string, phoneNumber: string, message: string): Promise<NotificationResult> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('PhoneNumber', sql.NVarChar(20), phoneNumber)
            .input('Message', sql.NVarChar(sql.MAX), message)
            .execute('sp_SendWhatsAppNotification');

        return result.recordset[0];
    }

    /**
     * Send push notification
     */
    public async sendPushNotification(agentId: string, title: string, body: string): Promise<NotificationResult> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('Title', sql.NVarChar(200), title)
            .input('Body', sql.NVarChar(sql.MAX), body)
            .execute('sp_SendPushNotification');

        return result.recordset[0];
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
    ): Promise<{ NotificationId: string }> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('ScheduledTime', sql.DateTime2, scheduledTime)
            .input('NotificationType', sql.NVarChar(20), notificationType)
            .input('Recipient', sql.NVarChar(200), recipient)
            .input('Subject', sql.NVarChar(200), subject)
            .input('Body', sql.NVarChar(sql.MAX), body)
            .execute('sp_ScheduleNotification');

        return result.recordset[0];
    }

    /**
     * Cancel scheduled notification
     */
    public async cancelScheduledNotification(notificationId: string, agentId: string): Promise<CancelNotificationResult> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('NotificationId', sql.UniqueIdentifier, notificationId)
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .execute('sp_CancelScheduledNotification');

        return result.recordset[0];
    }

    /**
     * Process scheduled notifications
     */
    public async processScheduledNotifications(): Promise<ScheduledNotification[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .execute('sp_ProcessScheduledNotifications');

        return result.recordset;
    }

public async getNotificationHistory(
    agentId: string,
    options?: NotificationHistoryRequest
): Promise<NotificationHistoryResult> {
    const pool = await poolPromise;
    const request = pool.request()
        .input('AgentId', sql.UniqueIdentifier, agentId);

    if (options?.StartDate) {
        request.input('StartDate', sql.Date, options.StartDate);
    }
    if (options?.EndDate) {
        request.input('EndDate', sql.Date, options.EndDate);
    }
    if (options?.NotificationType) {
        request.input('NotificationType', sql.NVarChar(20), options.NotificationType);
    }
    if (options?.Status) {
        request.input('Status', sql.NVarChar(20), options.Status);
    }
    if (options?.PageSize) {
        request.input('PageSize', sql.Int, options.PageSize);
    }
    if (options?.PageNumber) {
        request.input('PageNumber', sql.Int, options.PageNumber);
    }

    const result = await request.execute('sp_GetNotificationHistory');

    // Narrow type so TS knows it's an array
    const recordsets = result.recordsets as sql.IRecordSet<any>[];

    return {
        notifications: recordsets[0],
        totalRecords: recordsets[1]?.[0]?.TotalRecords ?? 0
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
        const result = await pool.request()
            .input('NotificationId', sql.UniqueIdentifier, notificationId)
            .input('Status', sql.NVarChar(20), status)
            .input('ErrorMessage', sql.NVarChar(500), errorMessage)
            .execute('sp_UpdateNotificationStatus');

        return result.recordset[0];
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