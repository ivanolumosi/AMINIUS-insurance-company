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

export interface ReminderStatistics {
  TotalActive: number;
  TotalCompleted: number;
  TodayReminders: number;
  UpcomingReminders: number;
  HighPriority: number;
  Overdue: number;
}

export class ReminderService {
    /** Create a new reminder */
    public async createReminder(agentId: string, reminderData: CreateReminderRequest): Promise<{ ReminderId: string }> {
        console.log('📝 Backend: Creating reminder with raw data:', reminderData);
        
        try {
            // Robust time validation and formatting
            let validatedTime: string | null = null;
            
            if (reminderData.ReminderTime) {
                validatedTime = this.validateAndFormatSQLTime(reminderData.ReminderTime);
                console.log('📝 Backend: Time validated:', reminderData.ReminderTime, '->', validatedTime);
            }
            
            const pool = await poolPromise;
            const request = pool.request()
                .input('AgentId', sql.UniqueIdentifier, agentId)
                .input('ClientId', sql.UniqueIdentifier, reminderData.ClientId ?? null)
                .input('AppointmentId', sql.UniqueIdentifier, reminderData.AppointmentId ?? null)
                .input('ReminderType', sql.NVarChar(50), reminderData.ReminderType)
                .input('Title', sql.NVarChar(200), reminderData.Title)
                .input('Description', sql.NVarChar(sql.MAX), reminderData.Description ?? null)
                .input('ReminderDate', sql.Date, reminderData.ReminderDate)
                .input('ClientName', sql.NVarChar(150), reminderData.ClientName ?? null)
                .input('Priority', sql.NVarChar(10), reminderData.Priority ?? 'Medium')
                .input('EnableSMS', sql.Bit, reminderData.EnableSMS ?? false)
                .input('EnableWhatsApp', sql.Bit, reminderData.EnableWhatsApp ?? false)
                .input('EnablePushNotification', sql.Bit, reminderData.EnablePushNotification ?? true)
                .input('AdvanceNotice', sql.NVarChar(20), reminderData.AdvanceNotice ?? '1 day')
                .input('CustomMessage', sql.NVarChar(sql.MAX), reminderData.CustomMessage ?? null)
                .input('AutoSend', sql.Bit, reminderData.AutoSend ?? false)
                .input('Notes', sql.NVarChar(sql.MAX), reminderData.Notes ?? null);

            // Only add ReminderTime parameter if we have a valid time
            if (validatedTime) {
                request.input('ReminderTime', sql.Time, validatedTime);
            } else {
                // Pass null if no time provided
                request.input('ReminderTime', sql.Time, null);
            }

            console.log('📝 Backend: Executing stored procedure with validated time:', validatedTime);
            
            const result = await request.execute('sp_CreateReminder');
            
            console.log('✅ Backend: Reminder created successfully');
            return result.recordset[0];
            
        } catch (error: unknown) {
            console.error('❌ Backend: Error creating reminder:', error);
            console.error('❌ Original reminder data:', reminderData);
            
            const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
            throw new Error(`Failed to create reminder: ${errorMessage}`);
        }
    }

    // Add this robust time validation method to your ReminderService class
    private validateAndFormatSQLTime(timeString: string | null | undefined): string | null {
        console.log('🕐 Backend: Validating SQL time:', timeString, typeof timeString);
        
        if (!timeString || timeString === 'null' || timeString === 'undefined') {
            console.log('🕐 Backend: No valid time provided, returning null');
            return null;
        }
        
        // Clean the input
        let cleanTime = timeString.toString().trim();
        console.log('🕐 Backend: Cleaned time:', cleanTime);
        
        // Handle various time formats
        try {
            // Format 1: Already HH:MM:SS
            if (/^\d{2}:\d{2}:\d{2}$/.test(cleanTime)) {
                const [h, m, s] = cleanTime.split(':').map(Number);
                if (h >= 0 && h <= 23 && m >= 0 && m <= 59 && s >= 0 && s <= 59) {
                    console.log('🕐 Backend: Valid HH:MM:SS format');
                    return cleanTime;
                }
                throw new Error('Invalid time ranges');
            }
            
            // Format 2: HH:MM
            if (/^\d{1,2}:\d{2}$/.test(cleanTime)) {
                const [h, m] = cleanTime.split(':').map(Number);
                if (h >= 0 && h <= 23 && m >= 0 && m <= 59) {
                    const formatted = `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}:00`;
                    console.log('🕐 Backend: Converted HH:MM to HH:MM:SS:', cleanTime, '->', formatted);
                    return formatted;
                }
                throw new Error('Invalid time ranges for HH:MM');
            }
            
            // Format 3: Try parsing as ISO datetime and extract time
            if (cleanTime.includes('T') || cleanTime.includes('-')) {
                const date = new Date(cleanTime);
                if (!isNaN(date.getTime())) {
                    const hours = date.getUTCHours().toString().padStart(2, '0');
                    const minutes = date.getUTCMinutes().toString().padStart(2, '0');
                    const seconds = date.getUTCSeconds().toString().padStart(2, '0');
                    const formatted = `${hours}:${minutes}:${seconds}`;
                    console.log('🕐 Backend: Extracted time from datetime:', cleanTime, '->', formatted);
                    return formatted;
                }
            }
            
            // Format 4: Try creating a date with the time
            const testDate = new Date(`1970-01-01T${cleanTime}`);
            if (!isNaN(testDate.getTime())) {
                const hours = testDate.getUTCHours().toString().padStart(2, '0');
                const minutes = testDate.getUTCMinutes().toString().padStart(2, '0');
                const seconds = testDate.getUTCSeconds().toString().padStart(2, '0');
                const formatted = `${hours}:${minutes}:${seconds}`;
                console.log('🕐 Backend: Parsed with date constructor:', cleanTime, '->', formatted);
                return formatted;
            }
            
            throw new Error(`Cannot parse time format: ${cleanTime}`);
            
        } catch (error: unknown) {
            const errorMessage = error instanceof Error ? error.message : 'Unknown validation error';
            console.error('🕐 Backend: Time validation failed:', errorMessage);
            console.error('🕐 Backend: Original input was:', timeString);
            
            // Instead of throwing, return null to let the database handle it
            console.log('🕐 Backend: Returning null due to validation failure');
            return null;
        }
    }

    /** Get all reminders with filters and pagination */
    public async getAllReminders(agentId: string, filters: ReminderFilters = {}): Promise<PaginatedReminderResponse> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('StartDate', sql.Date, filters.StartDate ?? null)
            .input('EndDate', sql.Date, filters.EndDate ?? null)
            .input('PageSize', sql.Int, filters.PageSize ?? 20)
            .input('PageNumber', sql.Int, filters.PageNumber ?? 1)
            .execute('sp_GetAllReminders');

        const reminders: Reminder[] = result.recordset;
        const pageSize = filters.PageSize ?? 20;

        return {
            reminders,
            totalRecords: reminders.length, // ideally add COUNT(*) in SP for accuracy
            currentPage: filters.PageNumber ?? 1,
            totalPages: Math.ceil(reminders.length / pageSize),
            pageSize
        };
    }

    /** Get reminder by ID */
    public async getReminderById(reminderId: string, agentId: string): Promise<Reminder | null> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('ReminderId', sql.UniqueIdentifier, reminderId)
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .execute('sp_GetReminderById');

        return result.recordset.length ? result.recordset[0] : null;
    }

    /** Update a reminder */
    public async updateReminder(reminderId: string, agentId: string, updateData: UpdateReminderRequest): Promise<{ RowsAffected: number }> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('ReminderId', sql.UniqueIdentifier, reminderId)
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('Title', sql.NVarChar(200), updateData.Title ?? null)
            .input('Description', sql.NVarChar(sql.MAX), updateData.Description ?? null)
            .input('ReminderDate', sql.Date, updateData.ReminderDate ?? null)
            .input('ReminderTime', sql.Time, updateData.ReminderTime ?? null)
            .input('Priority', sql.NVarChar(10), updateData.Priority ?? null)
            .input('Status', sql.NVarChar(20), updateData.Status ?? null)
            .input('EnableSMS', sql.Bit, updateData.EnableSMS ?? false)
            .input('EnableWhatsApp', sql.Bit, updateData.EnableWhatsApp ?? false)
            .input('EnablePushNotification', sql.Bit, updateData.EnablePushNotification ?? false)
            .input('AdvanceNotice', sql.NVarChar(20), updateData.AdvanceNotice ?? null)
            .input('CustomMessage', sql.NVarChar(sql.MAX), updateData.CustomMessage ?? null)
            .input('AutoSend', sql.Bit, updateData.AutoSend ?? false)
            .input('Notes', sql.NVarChar(sql.MAX), updateData.Notes ?? null)
            .execute('sp_UpdateReminder');

        return result.recordset[0];
    }

    /** Delete a reminder */
    public async deleteReminder(reminderId: string, agentId: string): Promise<{ RowsAffected: number }> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('ReminderId', sql.UniqueIdentifier, reminderId)
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .execute('sp_DeleteReminder');

        return result.recordset[0];
    }

    /** Complete a reminder */
    public async completeReminder(reminderId: string, agentId: string, notes?: string): Promise<{ RowsAffected: number }> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('ReminderId', sql.UniqueIdentifier, reminderId)
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('Notes', sql.NVarChar(sql.MAX), notes ?? null)
            .execute('sp_CompleteReminder');

        return result.recordset[0];
    }

    /** Get today's reminders */
    public async getTodayReminders(agentId: string): Promise<Reminder[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .execute('sp_GetTodayReminders');

        return result.recordset;
    }

    /** Get reminder settings */
    public async getReminderSettings(agentId: string): Promise<ReminderSettings[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .execute('sp_GetReminderSettings');

        return result.recordset;
    }

    /** Update reminder settings */
    public async updateReminderSettings(agentId: string, reminderType: string, isEnabled: boolean, daysBefore: number, timeOfDay: string, repeatDaily: boolean = false): Promise<void> {
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
     * Get reminder statistics by AgentId
     */
    public async getReminderStatistics(agentId: string): Promise<ReminderStatistics> {
        try {
            const pool = await poolPromise;
            const result = await pool.request()
                .input('AgentId', sql.UniqueIdentifier, agentId)
                .execute('sp_GetReminderStatistics');

            if (result.recordset.length === 0) {
                return {
                    TotalActive: 0,
                    TotalCompleted: 0,
                    TodayReminders: 0,
                    UpcomingReminders: 0,
                    HighPriority: 0,
                    Overdue: 0
                };
            }

            return result.recordset[0] as ReminderStatistics;
        } catch (error: unknown) {
            console.error('Error fetching reminder statistics:', error);
            throw error;
        }
    }

    /**
     * Get reminders filtered by ReminderType
     */
    async getRemindersByType(agentId: string, reminderType: string): Promise<Reminder[]> {
        try {
            const pool = await poolPromise;
            const result = await pool.request()
                .input('AgentId', sql.UniqueIdentifier, agentId)
                .input('ReminderType', sql.NVarChar(50), reminderType)
                .execute('spGetRemindersByType');

            return result.recordset as Reminder[];
        } catch (error: unknown) {
            console.error('Error fetching reminders by type:', error);
            throw error;
        }
    }

    /**
     * Get reminders filtered by Status
     */
    async getRemindersByStatus(agentId: string, status: string): Promise<Reminder[]> {
        try {
            const pool = await poolPromise;
            const result = await pool.request()
                .input('AgentId', sql.UniqueIdentifier, agentId)
                .input('Status', sql.NVarChar(20), status)
                .execute('spGetRemindersByStatus');

            return result.recordset as Reminder[];
        } catch (error: unknown) {
            console.error('Error fetching reminders by status:', error);
            throw error;
        }
    }
}