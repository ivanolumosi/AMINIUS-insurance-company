// services/reminders.service.ts
import { Pool } from 'pg';
import { poolPromise } from '../../db'; // Assuming this now returns a PostgreSQL pool
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
                validatedTime = this.validateAndFormatPostgreSQLTime(reminderData.ReminderTime);
                console.log('📝 Backend: Time validated:', reminderData.ReminderTime, '->', validatedTime);
            }
            
            const pool = await poolPromise as Pool;
            const client = await pool.connect();
            
            try {
                const query = `
                    SELECT sp_create_reminder(
                        $1::uuid, $2::uuid, $3::uuid, $4::varchar(50), $5::varchar(200),
                        $6::text, $7::date, $8::time, $9::varchar(150), $10::varchar(10),
                        $11::boolean, $12::boolean, $13::boolean, $14::varchar(20),
                        $15::text, $16::boolean, $17::text
                    ) as reminder_id
                `;
                
                const values = [
                    agentId,
                    reminderData.ClientId || null,
                    reminderData.AppointmentId || null,
                    reminderData.ReminderType,
                    reminderData.Title,
                    reminderData.Description || null,
                    reminderData.ReminderDate,
                    validatedTime,
                    reminderData.ClientName || null,
                    reminderData.Priority || 'Medium',
                    reminderData.EnableSMS || false,
                    reminderData.EnableWhatsApp || false,
                    reminderData.EnablePushNotification || true,
                    reminderData.AdvanceNotice || '1 day',
                    reminderData.CustomMessage || null,
                    reminderData.AutoSend || false,
                    reminderData.Notes || null
                ];

                console.log('📝 Backend: Executing query with validated time:', validatedTime);
                
                const result = await client.query(query, values);
                
                console.log('✅ Backend: Reminder created successfully');
                return { ReminderId: result.rows[0].reminder_id };
                
            } finally {
                client.release();
            }
            
        } catch (error: unknown) {
            console.error('❌ Backend: Error creating reminder:', error);
            console.error('❌ Original reminder data:', reminderData);
            
            const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
            throw new Error(`Failed to create reminder: ${errorMessage}`);
        }
    }

    // PostgreSQL time validation method
    private validateAndFormatPostgreSQLTime(timeString: string | null | undefined): string | null {
        console.log('🕐 Backend: Validating PostgreSQL time:', timeString, typeof timeString);
        
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
        const pool = await poolPromise as Pool;
        const client = await pool.connect();
        
        try {
            const query = `
                SELECT * FROM get_all_reminders(
                    $1::uuid, $2::date, $3::date, $4::integer, $5::integer
                )
            `;
            
            const values = [
                agentId,
                filters.StartDate || null,
                filters.EndDate || null,
                filters.PageSize || 20,
                filters.PageNumber || 1
            ];
            
            const result = await client.query(query, values);
            const reminders: Reminder[] = result.rows;
            const pageSize = filters.PageSize || 20;

            // Get total count for pagination
            const countQuery = `
                SELECT COUNT(*) as total FROM reminders 
                WHERE agent_id = $1 
                AND ($2::date IS NULL OR reminder_date >= $2)
                AND ($3::date IS NULL OR reminder_date <= $3)
            `;
            const countResult = await client.query(countQuery, [
                agentId, 
                filters.StartDate || null, 
                filters.EndDate || null
            ]);
            const totalRecords = parseInt(countResult.rows[0].total);

            return {
                reminders,
                totalRecords,
                currentPage: filters.PageNumber || 1,
                totalPages: Math.ceil(totalRecords / pageSize),
                pageSize
            };
        } finally {
            client.release();
        }
    }

    /** Get reminder by ID */
    public async getReminderById(reminderId: string, agentId: string): Promise<Reminder | null> {
        const pool = await poolPromise as Pool;
        const client = await pool.connect();
        
        try {
            const query = `
                SELECT * FROM get_reminder_by_id($1::uuid, $2::uuid)
            `;
            
            const result = await client.query(query, [reminderId, agentId]);
            return result.rows.length ? result.rows[0] : null;
        } finally {
            client.release();
        }
    }

    /** Update a reminder */
    public async updateReminder(reminderId: string, agentId: string, updateData: UpdateReminderRequest): Promise<{ RowsAffected: number }> {
        const pool = await poolPromise as Pool;
        const client = await pool.connect();
        
        try {
            const query = `
                SELECT update_reminder(
                    $1::uuid, $2::uuid, $3::varchar(200), $4::text, $5::date,
                    $6::time, $7::varchar(10), $8::varchar(20), $9::boolean,
                    $10::boolean, $11::boolean, $12::varchar(20), $13::text,
                    $14::boolean, $15::text
                ) as rows_affected
            `;
            
            const values = [
                reminderId,
                agentId,
                updateData.Title || null,
                updateData.Description || null,
                updateData.ReminderDate || null,
                updateData.ReminderTime || null,
                updateData.Priority || null,
                updateData.Status || null,
                updateData.EnableSMS || false,
                updateData.EnableWhatsApp || false,
                updateData.EnablePushNotification || false,
                updateData.AdvanceNotice || null,
                updateData.CustomMessage || null,
                updateData.AutoSend || false,
                updateData.Notes || null
            ];
            
            const result = await client.query(query, values);
            return { RowsAffected: result.rows[0].rows_affected };
        } finally {
            client.release();
        }
    }

    /** Delete a reminder */
    public async deleteReminder(reminderId: string, agentId: string): Promise<{ RowsAffected: number }> {
        const pool = await poolPromise as Pool;
        const client = await pool.connect();
        
        try {
            const query = `
                SELECT delete_reminder($1::uuid, $2::uuid) as rows_affected
            `;
            
            const result = await client.query(query, [reminderId, agentId]);
            return { RowsAffected: result.rows[0].rows_affected };
        } finally {
            client.release();
        }
    }

    /** Complete a reminder */
    public async completeReminder(reminderId: string, agentId: string, notes?: string): Promise<{ RowsAffected: number }> {
        const pool = await poolPromise as Pool;
        const client = await pool.connect();
        
        try {
            const query = `
                SELECT complete_reminder($1::uuid, $2::uuid, $3::text) as rows_affected
            `;
            
            const result = await client.query(query, [reminderId, agentId, notes || null]);
            return { RowsAffected: result.rows[0].rows_affected };
        } finally {
            client.release();
        }
    }

    /** Get today's reminders */
    public async getTodayReminders(agentId: string): Promise<Reminder[]> {
        const pool = await poolPromise as Pool;
        const client = await pool.connect();
        
        try {
            const query = `
                SELECT * FROM get_today_reminders($1::uuid)
            `;
            
            const result = await client.query(query, [agentId]);
            return result.rows;
        } finally {
            client.release();
        }
    }

    /** Get reminder settings */
    public async getReminderSettings(agentId: string): Promise<ReminderSettings[]> {
        const pool = await poolPromise as Pool;
        const client = await pool.connect();
        
        try {
            const query = `
                SELECT * FROM get_reminder_settings($1::uuid)
            `;
            
            const result = await client.query(query, [agentId]);
            return result.rows;
        } finally {
            client.release();
        }
    }

    /** Update reminder settings */
    public async updateReminderSettings(agentId: string, reminderType: string, isEnabled: boolean, daysBefore: number, timeOfDay: string, repeatDaily: boolean = false): Promise<void> {
        const pool = await poolPromise as Pool;
        const client = await pool.connect();
        
        try {
            const query = `
                SELECT update_reminder_settings(
                    $1::uuid, $2::varchar(50), $3::boolean, $4::integer, $5::time, $6::boolean
                )
            `;
            
            await client.query(query, [agentId, reminderType, isEnabled, daysBefore, timeOfDay, repeatDaily]);
        } finally {
            client.release();
        }
    }

    /**
     * Get reminder statistics by AgentId
     */
    public async getReminderStatistics(agentId: string): Promise<ReminderStatistics> {
        try {
            const pool = await poolPromise as Pool;
            const client = await pool.connect();
            
            try {
                const query = `
                    SELECT * FROM get_reminder_statistics($1::uuid)
                `;
                
                const result = await client.query(query, [agentId]);

                if (result.rows.length === 0) {
                    return {
                        TotalActive: 0,
                        TotalCompleted: 0,
                        TodayReminders: 0,
                        UpcomingReminders: 0,
                        HighPriority: 0,
                        Overdue: 0
                    };
                }

                const row = result.rows[0];
                return {
                    TotalActive: parseInt(row.total_active) || 0,
                    TotalCompleted: parseInt(row.total_completed) || 0,
                    TodayReminders: parseInt(row.today_reminders) || 0,
                    UpcomingReminders: parseInt(row.upcoming_reminders) || 0,
                    HighPriority: parseInt(row.high_priority) || 0,
                    Overdue: parseInt(row.overdue) || 0
                };
            } finally {
                client.release();
            }
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
            const pool = await poolPromise as Pool;
            const client = await pool.connect();
            
            try {
                const query = `
                    SELECT * FROM get_reminders_by_type($1::uuid, $2::varchar(50))
                `;
                
                const result = await client.query(query, [agentId, reminderType]);
                return result.rows;
            } finally {
                client.release();
            }
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
            const pool = await poolPromise as Pool;
            const client = await pool.connect();
            
            try {
                const query = `
                    SELECT * FROM get_reminders_by_status($1::uuid, $2::varchar(20))
                `;
                
                const result = await client.query(query, [agentId, status]);
                return result.rows;
            } finally {
                client.release();
            }
        } catch (error: unknown) {
            console.error('Error fetching reminders by status:', error);
            throw error;
        }
    }
}