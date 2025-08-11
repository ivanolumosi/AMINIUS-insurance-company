// services/reminders.service.ts

import { poolPromise } from '../../db';
import * as sql from 'mssql';
import {
    Reminder,
    ReminderSettings,
    CreateReminderRequest,
    UpdateReminderRequest,
    ReminderFilters,
    PaginatedReminderResponse,
    BirthdayReminder,
    PolicyExpiryReminder,
    PhoneValidationResult
} from '../interfaces/reminders';

export class ReminderService {
    /**
     * Create a new reminder
     */
    public async createReminder(agentId: string, reminderData: CreateReminderRequest): Promise<{ ReminderId: string }> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('ClientId', sql.UniqueIdentifier, reminderData.ClientId || null)
            .input('AppointmentId', sql.UniqueIdentifier, reminderData.AppointmentId || null)
            .input('ReminderType', sql.NVarChar(50), reminderData.ReminderType)
            .input('Title', sql.NVarChar(200), reminderData.Title)
            .input('Description', sql.NVarChar(sql.MAX), reminderData.Description || null)
            .input('ReminderDate', sql.Date, reminderData.ReminderDate)
            .input('ReminderTime', sql.Time, reminderData.ReminderTime || null)
            .input('ClientName', sql.NVarChar(150), reminderData.ClientName || null)
            .input('Priority', sql.NVarChar(10), reminderData.Priority || 'Medium')
            .input('EnableSMS', sql.Bit, reminderData.EnableSMS || false)
            .input('EnableWhatsApp', sql.Bit, reminderData.EnableWhatsApp || false)
            .input('EnablePushNotification', sql.Bit, reminderData.EnablePushNotification || true)
            .input('AdvanceNotice', sql.NVarChar(20), reminderData.AdvanceNotice || '1 day')
            .input('CustomMessage', sql.NVarChar(sql.MAX), reminderData.CustomMessage || null)
            .input('AutoSend', sql.Bit, reminderData.AutoSend || false)
            .input('Notes', sql.NVarChar(sql.MAX), reminderData.Notes || null)
            .execute('sp_CreateReminder');

        return result.recordset[0];
    }

    /**
     * Get all reminders with filters and pagination
     */
   public async getAllReminders(
    agentId: string,
    filters: ReminderFilters = {}
): Promise<PaginatedReminderResponse> {
    const pool = await poolPromise;
    const result = await pool.request()
        .input('AgentId', sql.UniqueIdentifier, agentId)
        .input('ReminderType', sql.NVarChar(50), filters.ReminderType || null)
        .input('Status', sql.NVarChar(20), filters.Status || null)
        .input('Priority', sql.NVarChar(10), filters.Priority || null)
        .input('StartDate', sql.Date, filters.StartDate || null)
        .input('EndDate', sql.Date, filters.EndDate || null)
        .input('ClientId', sql.UniqueIdentifier, filters.ClientId || null)
        .input('PageSize', sql.Int, filters.PageSize || 50)
        .input('PageNumber', sql.Int, filters.PageNumber || 1)
        .execute('sp_GetAllReminders');

    // Narrow type so TS knows it's an array
    const recordsets = result.recordsets as sql.IRecordSet<any>[];

    const reminders: Reminder[] = recordsets[0];
    const totalRecords = recordsets[1]?.[0]?.TotalRecords || 0;
    const pageSize = filters.PageSize || 50;
    const currentPage = filters.PageNumber || 1;
    const totalPages = Math.ceil(totalRecords / pageSize);

    return {
        reminders,
        totalRecords,
        currentPage,
        totalPages,
        pageSize
    };
}


    /**
     * Get reminder by ID
     */
    public async getReminderById(reminderId: string, agentId: string): Promise<Reminder | null> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('ReminderId', sql.UniqueIdentifier, reminderId)
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .execute('sp_GetReminderById');

        return result.recordset.length ? result.recordset[0] : null;
    }

    /**
     * Update a reminder
     */
    public async updateReminder(reminderId: string, agentId: string, updateData: UpdateReminderRequest): Promise<{ RowsAffected: number }> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('ReminderId', sql.UniqueIdentifier, reminderId)
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('Title', sql.NVarChar(200), updateData.Title || null)
            .input('Description', sql.NVarChar(sql.MAX), updateData.Description || null)
            .input('ReminderDate', sql.Date, updateData.ReminderDate || null)
            .input('ReminderTime', sql.Time, updateData.ReminderTime || null)
            .input('Priority', sql.NVarChar(10), updateData.Priority || null)
            .input('Status', sql.NVarChar(20), updateData.Status || null)
            .input('EnableSMS', sql.Bit, updateData.EnableSMS)
            .input('EnableWhatsApp', sql.Bit, updateData.EnableWhatsApp)
            .input('EnablePushNotification', sql.Bit, updateData.EnablePushNotification)
            .input('AdvanceNotice', sql.NVarChar(20), updateData.AdvanceNotice || null)
            .input('CustomMessage', sql.NVarChar(sql.MAX), updateData.CustomMessage || null)
            .input('AutoSend', sql.Bit, updateData.AutoSend)
            .input('Notes', sql.NVarChar(sql.MAX), updateData.Notes || null)
            .execute('sp_UpdateReminder');

        return result.recordset[0];
    }

    /**
     * Delete a reminder
     */
    public async deleteReminder(reminderId: string, agentId: string): Promise<{ RowsAffected: number }> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('ReminderId', sql.UniqueIdentifier, reminderId)
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .execute('sp_DeleteReminder');

        return result.recordset[0];
    }

    /**
     * Complete a reminder
     */
    public async completeReminder(reminderId: string, agentId: string, notes?: string): Promise<{ RowsAffected: number }> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('ReminderId', sql.UniqueIdentifier, reminderId)
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('Notes', sql.NVarChar(sql.MAX), notes || null)
            .execute('sp_CompleteReminder');

        return result.recordset[0];
    }

    /**
     * Get today's reminders
     */
    public async getTodayReminders(agentId: string): Promise<Reminder[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .execute('sp_GetTodayReminders');

        return result.recordset;
    }

    /**
     * Get upcoming reminders
     */
    public async getUpcomingReminders(agentId: string, daysAhead: number = 7): Promise<Reminder[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('DaysAhead', sql.Int, daysAhead)
            .execute('sp_GetUpcomingReminders');

        return result.recordset;
    }

    /**
     * Get completed reminders
     */
    public async getCompletedReminders(
        agentId: string,
        startDate?: Date,
        endDate?: Date,
        pageSize: number = 50,
        pageNumber: number = 1
    ): Promise<Reminder[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('StartDate', sql.Date, startDate || null)
            .input('EndDate', sql.Date, endDate || null)
            .input('PageSize', sql.Int, pageSize)
            .input('PageNumber', sql.Int, pageNumber)
            .execute('sp_GetCompletedReminders');

        return result.recordset;
    }

    /**
     * Get birthday reminders for today
     */
    public async getTodayBirthdayReminders(agentId: string): Promise<BirthdayReminder[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .execute('sp_GetTodayBirthdayReminders');

        return result.recordset;
    }

    /**
     * Get policy expiry reminders
     */
    public async getPolicyExpiryReminders(agentId: string, daysAhead: number = 30): Promise<PolicyExpiryReminder[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('DaysAhead', sql.Int, daysAhead)
            .execute('sp_GetPolicyExpiryReminders');

        return result.recordset;
    }

    /**
     * Validate phone number
     */
    public async validatePhoneNumber(phoneNumber: string, countryCode: string = '+254'): Promise<PhoneValidationResult> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('PhoneNumber', sql.NVarChar(20), phoneNumber)
            .input('CountryCode', sql.NVarChar(5), countryCode)
            .execute('sp_ValidatePhoneNumber');

        return result.recordset[0];
    }

    // Reminder Settings Methods

    /**
     * Get reminder settings for an agent
     */
    public async getReminderSettings(agentId: string): Promise<ReminderSettings[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .execute('sp_GetReminderSettings');

        return result.recordset;
    }

    /**
     * Update reminder settings
     */
    public async updateReminderSettings(
        agentId: string,
        reminderType: 'Policy Expiry' | 'Birthday' | 'Appointment' | 'Call' | 'Visit',
        isEnabled: boolean,
        daysBefore: number,
        timeOfDay: string,
        repeatDaily: boolean = false
    ): Promise<void> {
        const pool = await poolPromise;
        await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('ReminderType', sql.NVarChar(50), reminderType)
            .input('IsEnabled', sql.Bit, isEnabled)
            .input('DaysBefore', sql.Int, daysBefore)
            .input('TimeOfDay', sql.Time, timeOfDay)
            .input('RepeatDaily', sql.Bit, repeatDaily)
            .execute('sp_UpdateReminderSettings');
    }

    /**
     * Create bulk reminders for policy expiries
     */
    public async createPolicyExpiryReminders(agentId: string, daysAhead: number = 30): Promise<number> {
        const policyExpiries = await this.getPolicyExpiryReminders(agentId, daysAhead);
        let reminderCount = 0;

        for (const policy of policyExpiries) {
            try {
                await this.createReminder(agentId, {
                    ClientId: policy.ClientId,
                    ReminderType: 'Policy Expiry',
                    Title: `Policy Expiry: ${policy.PolicyName}`,
                    Description: `${policy.PolicyType} policy from ${policy.CompanyName} expires on ${policy.EndDate.toDateString()}`,
                    ReminderDate: new Date(policy.EndDate.getTime() - (7 * 24 * 60 * 60 * 1000)), // 7 days before
                    ClientName: `${policy.FirstName} ${policy.Surname}`,
                    Priority: policy.DaysUntilExpiry <= 7 ? 'High' : 'Medium',
                    EnableSMS: true,
                    EnableWhatsApp: true,
                    CustomMessage: `Dear ${policy.FirstName}, your ${policy.PolicyType} policy expires in ${policy.DaysUntilExpiry} days. Please contact us to discuss renewal.`
                });
                reminderCount++;
            } catch (error) {
                console.error(`Failed to create reminder for policy ${policy.PolicyId}:`, error);
            }
        }

        return reminderCount;
    }

    /**
     * Create bulk reminders for birthdays
     */
    public async createBirthdayReminders(agentId: string): Promise<number> {
        const birthdays = await this.getTodayBirthdayReminders(agentId);
        let reminderCount = 0;

        for (const birthday of birthdays) {
            try {
                await this.createReminder(agentId, {
                    ClientId: birthday.ClientId,
                    ReminderType: 'Birthday',
                    Title: `Birthday: ${birthday.FirstName} ${birthday.Surname}`,
                    Description: `${birthday.FirstName} ${birthday.Surname} turns ${birthday.Age} today`,
                    ReminderDate: new Date(),
                    ClientName: `${birthday.FirstName} ${birthday.Surname}`,
                    Priority: 'Medium',
                    EnableSMS: true,
                    EnableWhatsApp: true,
                    CustomMessage: `Happy Birthday ${birthday.FirstName}! Wishing you health, happiness and prosperity in the year ahead.`
                });
                reminderCount++;
            } catch (error) {
                console.error(`Failed to create birthday reminder for client ${birthday.ClientId}:`, error);
            }
        }

        return reminderCount;
    }

    /**
     * Get reminder statistics
     */
    public async getReminderStatistics(agentId: string): Promise<{
        totalActive: number;
        totalCompleted: number;
        todayReminders: number;
        upcomingReminders: number;
        highPriority: number;
        overdue: number;
    }> {
        const pool = await poolPromise;
        
        // Get various counts in parallel
        const [activeResult, completedResult, todayResult, upcomingResult, highPriorityResult, overdueResult] = await Promise.all([
            pool.request()
                .input('AgentId', sql.UniqueIdentifier, agentId)
                .query("SELECT COUNT(*) as count FROM Reminders WHERE AgentId = @AgentId AND Status = 'Active'"),
            
            pool.request()
                .input('AgentId', sql.UniqueIdentifier, agentId)
                .query("SELECT COUNT(*) as count FROM Reminders WHERE AgentId = @AgentId AND Status = 'Completed'"),
            
            pool.request()
                .input('AgentId', sql.UniqueIdentifier, agentId)
                .query("SELECT COUNT(*) as count FROM Reminders WHERE AgentId = @AgentId AND Status = 'Active' AND ReminderDate = CAST(GETDATE() AS DATE)"),
            
            pool.request()
                .input('AgentId', sql.UniqueIdentifier, agentId)
                .query("SELECT COUNT(*) as count FROM Reminders WHERE AgentId = @AgentId AND Status = 'Active' AND ReminderDate BETWEEN CAST(GETDATE() AS DATE) AND DATEADD(DAY, 7, CAST(GETDATE() AS DATE))"),
            
            pool.request()
                .input('AgentId', sql.UniqueIdentifier, agentId)
                .query("SELECT COUNT(*) as count FROM Reminders WHERE AgentId = @AgentId AND Status = 'Active' AND Priority = 'High'"),
            
            pool.request()
                .input('AgentId', sql.UniqueIdentifier, agentId)
                .query("SELECT COUNT(*) as count FROM Reminders WHERE AgentId = @AgentId AND Status = 'Active' AND ReminderDate < CAST(GETDATE() AS DATE)")
        ]);

        return {
            totalActive: activeResult.recordset[0].count,
            totalCompleted: completedResult.recordset[0].count,
            todayReminders: todayResult.recordset[0].count,
            upcomingReminders: upcomingResult.recordset[0].count,
            highPriority: highPriorityResult.recordset[0].count,
            overdue: overdueResult.recordset[0].count
        };
    }
}