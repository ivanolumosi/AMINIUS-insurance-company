import { poolPromise } from '../../db';
import * as sql from 'mssql';
  import emailService from '../nodemailer/emailservice';
import {
    Appointment,
    CreateAppointmentRequest,
    UpdateAppointmentRequest,
    AppointmentFilters,
    AppointmentStatistics,
    TimeConflictCheck,
    WeekViewAppointment,
    CalendarAppointment
} from '../interfaces/appointment';

export class AppointmentService {
    
    
    
    /**
     * Search clients for autocomplete dropdown
     * @param searchTerm - partial text to match name or phone
     * @param agentId - filter by agent to avoid showing other agents' clients
     */
    async searchClientsForAutocomplete(searchTerm: string, agentId: string) {
        try {
            const pool = await poolPromise;

            const result = await pool.request()
                .input('SearchTerm', sql.NVarChar, `%${searchTerm}%`)
                .input('AgentId', sql.UniqueIdentifier, agentId)
                .query(`
                    SELECT TOP 10 
                        ClientId,
                        CONCAT(FirstName, ' ', Surname, ' ', LastName) AS FullName,
                        PhoneNumber,
                        Email
                    FROM Clients
                    WHERE AgentId = @AgentId
                      AND IsActive = 1
                      AND (
                          FirstName LIKE @SearchTerm OR
                          Surname LIKE @SearchTerm OR
                          LastName LIKE @SearchTerm OR
                          PhoneNumber LIKE @SearchTerm OR
                          Email LIKE @SearchTerm
                      )
                    ORDER BY FirstName
                `);

            return result.recordset;
        } catch (error) {
            console.error('Error searching clients:', error);
            throw error;
        }
    }




public async createAppointment(agentId: string, appointmentData: CreateAppointmentRequest) {
  const pool = await poolPromise;
  const result = await pool.request()
    .input('AgentId', sql.UniqueIdentifier, agentId)
    .input('ClientId', sql.UniqueIdentifier, appointmentData.clientId)
    .input('Title', sql.NVarChar(200), appointmentData.title)
    .input('Description', sql.NVarChar(sql.MAX), appointmentData.description || null)
    .input('AppointmentDate', sql.Date, appointmentData.appointmentDate)
    .input('StartTime', sql.Time, new Date(`1970-01-01T${appointmentData.startTime}Z`))
    .input('EndTime', sql.Time, new Date(`1970-01-01T${appointmentData.endTime}Z`))
    .input('Location', sql.NVarChar(200), appointmentData.location || null)
    .input('Type', sql.NVarChar(50), appointmentData.type)
    .input('Status', sql.NVarChar(20), appointmentData.status || 'Scheduled') // ✅ include status

    .input('Priority', sql.NVarChar(10), appointmentData.priority || 'Medium')
    .input('Notes', sql.NVarChar(sql.MAX), appointmentData.notes || null)
    .input('ReminderSet', sql.Bit, appointmentData.reminderSet || false)
    .execute('sp_CreateAppointment');

  const response = result.recordset[0];

  if (response.Success === 1) {
    // Fetch weekly schedule & stats
    const weekAppointments = await this.getWeekViewAppointments(agentId);
    const stats = await this.getAppointmentStatistics(agentId);

    // Format week view
    const scheduleList = weekAppointments.map(a =>
      `- ${a.dayName} (${a.appointmentDate.toDateString()}): ${a.title} with ${a.clientName}`
    ).join('\n');

    const body = `
      Hello Stephen,

      A new appointment has been scheduled.

      Details:
      - Client: ${appointmentData.clientId}
      - Date: ${appointmentData.appointmentDate}
      - Time: ${appointmentData.startTime} - ${appointmentData.endTime}
      - Location: ${appointmentData.location || 'N/A'}
      - Type: ${appointmentData.type}
      - Priority: ${appointmentData.priority || 'Medium'}
      - Status: Scheduled

      📅 This Week's Schedule:
      ${scheduleList}

      📊 Appointment Statistics:
      - Today: ${stats.todayAppointments}
      - This Week: ${stats.weekAppointments}
      - This Month: ${stats.monthAppointments}
      - Completed: ${stats.completedAppointments}
      - Upcoming: ${stats.upcomingAppointments}
      - Cancelled: ${stats.cancelledAppointments}
    `;

    // 🔑 Fetch agent’s email dynamically instead of hardcoding
    const agentResult = await pool.request()
      .input('AgentId', sql.UniqueIdentifier, agentId)
      .query(`SELECT Email FROM Agent WHERE AgentId = @AgentId`);

    const recipient = agentResult.recordset[0]?.Email || process.env.FALLBACK_AGENT_EMAIL;

    // ✅ Use transporter via EmailService
    await emailService.sendMail(
      recipient, 
      `New Appointment Scheduled: ${appointmentData.title}`, 
      body
    );
  }

  return {
    success: response.Success === 1,
    message: response.Message,
    appointmentId: response.AppointmentId
  };
}


    public async updateAppointment(appointmentId: string, agentId: string, appointmentData: UpdateAppointmentRequest): Promise<{ success: boolean; message: string }> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AppointmentId', sql.UniqueIdentifier, appointmentId)
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('Title', sql.NVarChar(200), appointmentData.title || null)
            .input('Description', sql.NVarChar(sql.MAX), appointmentData.description || null)
            .input('AppointmentDate', sql.Date, appointmentData.appointmentDate || null)
            .input('StartTime', sql.Time, appointmentData.startTime || null)
            .input('EndTime', sql.Time, appointmentData.endTime || null)
            .input('Location', sql.NVarChar(200), appointmentData.location || null)
            .input('Type', sql.NVarChar(50), appointmentData.type || null)
            .input('Status', sql.NVarChar(20), appointmentData.status || null) 

            .input('Priority', sql.NVarChar(10), appointmentData.priority || null)
            .input('Notes', sql.NVarChar(sql.MAX), appointmentData.notes || null)
            .input('ReminderSet', sql.Bit, appointmentData.reminderSet || null)
            .execute('sp_UpdateAppointment');

        const response = result.recordset[0];
        return {
            success: response.Success === 1,
            message: response.Message
        };
    }

    public async getAppointmentById(appointmentId: string, agentId: string): Promise<Appointment | null> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AppointmentId', sql.UniqueIdentifier, appointmentId)
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .execute('sp_GetAppointmentById');

        return result.recordset.length ? this.mapAppointment(result.recordset[0]) : null;
    }
public async getAllAppointments(
    agentId: string,
    filters: AppointmentFilters
): Promise<{ appointments: Appointment[]; totalRecords: number }> {
    const pool = await poolPromise;
    const result = await pool.request()
        .input('AgentId', sql.UniqueIdentifier, agentId)
        .input('StartDate', sql.Date, filters.startDate || null)
        .input('EndDate', sql.Date, filters.endDate || null)
        .input('Status', sql.NVarChar(20), filters.statusFilter === 'all' ? null : filters.statusFilter)
        .input('Type', sql.NVarChar(50), filters.typeFilter === 'all' ? null : filters.typeFilter)
        .input('Priority', sql.NVarChar(10), filters.priority || null)
        .input('ClientId', sql.UniqueIdentifier, filters.clientId || null)
        .input('SearchTerm', sql.NVarChar(200), filters.searchTerm || null)
        .input('PageSize', sql.Int, filters.pageSize || 50)
        .input('PageNumber', sql.Int, filters.pageNumber || 1)
        .execute('sp_GetAllAppointments');

    // Narrow type to array
    const recordsets = result.recordsets as sql.IRecordSet<any>[];

    const appointments = recordsets[0].map(this.mapAppointment);
    const totalRecords = recordsets[1]?.[0]?.TotalRecords || 0;

    return { appointments, totalRecords };
}


    public async getAppointmentsWithFilters(agentId: string, filters: AppointmentFilters): Promise<Appointment[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('DateRangeFilter', sql.NVarChar(20), filters.dateRangeFilter || 'all')
            .input('StatusFilter', sql.NVarChar(20), filters.statusFilter || 'all')
            .input('TypeFilter', sql.NVarChar(50), filters.typeFilter || 'all')
            .input('SearchTerm', sql.NVarChar(100), filters.searchTerm || null)
            .input('StartDate', sql.Date, filters.startDate || null)
            .input('EndDate', sql.Date, filters.endDate || null)
            .execute('sp_GetAppointments');

        return result.recordset.map(this.mapAppointment);
    }

    public async getTodayAppointments(agentId: string): Promise<Appointment[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .execute('sp_GetTodayAppointments');

        return result.recordset.map(this.mapAppointment);
    }

    public async getAppointmentsForDate(agentId: string, appointmentDate: Date): Promise<Appointment[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('AppointmentDate', sql.Date, appointmentDate)
            .execute('sp_GetAppointmentsForDate');

        return result.recordset.map(this.mapAppointment);
    }

    public async getWeekViewAppointments(agentId: string, weekStartDate?: Date): Promise<WeekViewAppointment[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('WeekStartDate', sql.Date, weekStartDate || null)
            .execute('sp_GetWeekViewAppointments');

        return result.recordset.map(record => ({
            appointmentId: record.AppointmentId,
            clientId: record.ClientId,
            clientName: record.ClientName,
            title: record.Title,
            appointmentDate: record.AppointmentDate,
            startTime: record.StartTime,
            endTime: record.EndTime,
            location: record.Location,
            type: record.Type,
            status: record.Status,
            priority: record.Priority,
            dayName: record.DayName,
            dayNumber: record.DayNumber
        }));
    }

    public async getCalendarAppointments(agentId: string, month: number, year: number): Promise<CalendarAppointment[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('Month', sql.Int, month)
            .input('Year', sql.Int, year)
            .execute('sp_GetCalendarAppointments');

        return result.recordset.map(record => ({
            appointmentId: record.AppointmentId,
            clientId: record.ClientId,
            clientName: record.ClientName,
            title: record.Title,
            appointmentDate: record.AppointmentDate,
            startTime: record.StartTime,
            type: record.Type,
            status: record.Status,
            priority: record.Priority,
            dayNumber: record.DayNumber,
            appointmentsOnDay: record.AppointmentsOnDay
        }));
    }

    public async updateAppointmentStatus(appointmentId: string, agentId: string, status: string): Promise<number> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AppointmentId', sql.UniqueIdentifier, appointmentId)
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('Status', sql.NVarChar(20), status)
            .execute('sp_UpdateAppointmentStatus');

        return result.recordset[0]?.RowsAffected || 0;
    }

    public async deleteAppointment(appointmentId: string, agentId: string): Promise<number> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AppointmentId', sql.UniqueIdentifier, appointmentId)
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .execute('sp_DeleteAppointment');

        return result.recordset[0]?.RowsAffected || 0;
    }

    public async searchAppointments(agentId: string, searchTerm: string): Promise<Appointment[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('SearchTerm', sql.NVarChar(200), searchTerm)
            .execute('sp_SearchAppointments');

        return result.recordset.map(this.mapAppointment);
    }

    public async checkTimeConflicts(agentId: string, appointmentDate: Date, startTime: string, endTime: string, excludeAppointmentId?: string): Promise<TimeConflictCheck> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .input('AppointmentDate', sql.Date, appointmentDate)
            .input('StartTime', sql.Time, startTime)
            .input('EndTime', sql.Time, endTime)
            .input('ExcludeAppointmentId', sql.UniqueIdentifier, excludeAppointmentId || null)
            .execute('sp_CheckTimeConflicts');

        const response = result.recordset[0];
        return {
            hasConflict: response.HasConflict === 1,
            conflictCount: response.ConflictCount
        };
    }

    public async getAppointmentStatistics(agentId: string): Promise<AppointmentStatistics> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .execute('sp_GetAppointmentStatistics');

        const stats = result.recordset[0];
        return {
            todayAppointments: stats.TodayAppointments,
            weekAppointments: stats.WeekAppointments,
            monthAppointments: stats.MonthAppointments,
            completedAppointments: stats.CompletedAppointments,
            upcomingAppointments: stats.UpcomingAppointments,
            cancelledAppointments: stats.CancelledAppointments
        };
    }

    private mapAppointment(record: any): Appointment {
        return {
            appointmentId: record.AppointmentId,
            clientId: record.ClientId,
            agentId: record.AgentId,
            clientName: record.ClientName,
            clientPhone: record.ClientPhone,
            title: record.Title,
            description: record.Description,
            appointmentDate: record.AppointmentDate,
            startTime: record.StartTime,
            endTime: record.EndTime,
            location: record.Location,
            type: record.Type,
            status: record.Status,
            priority: record.Priority,
            notes: record.Notes,
            reminderSet: record.ReminderSet,
            createdDate: record.CreatedDate,
            modifiedDate: record.ModifiedDate,
            isActive: record.IsActive,
            clientEmail: record.ClientEmail,
            clientAddress: record.ClientAddress
        };
    }
}