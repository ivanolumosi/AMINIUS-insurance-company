// services/appointment.service.ts
import { poolPromise } from "../../db";
import { ClientSearchResult, CreateAppointmentRequest, UpdateAppointmentRequest, Appointment, AppointmentFilters, WeekViewData, CalendarViewData, AppointmentStatistics, ConflictCheckResponse } from "../interfaces/appointment";
import emailService from "../nodemailer/emailservice";



export class AppointmentService {
  
  /**
   * Search clients for autocomplete
   */
  async searchClientsForAutocomplete(searchTerm: string, agentId: string): Promise<ClientSearchResult[]> {
    const pool = await poolPromise;
    const query = `
      SELECT 
        client_id as "clientId",
        (first_name || ' ' || surname || ' ' || last_name) AS "clientName",
        phone_number as "phone",
        email,
        address
      FROM clients
      WHERE agent_id = $1
        AND is_active = TRUE
        AND (
          first_name ILIKE $2 OR
          surname ILIKE $2 OR
          last_name ILIKE $2 OR
          phone_number ILIKE $2 OR
          email ILIKE $2
        )
      ORDER BY first_name
      LIMIT 10;
    `;
    const { rows } = await pool.query(query, [agentId, `%${searchTerm}%`]);
    return rows;
  }

  /**
   * Create appointment using stored procedure
   */
  async createAppointment(agentId: string, data: CreateAppointmentRequest) {
    const pool = await poolPromise;
    
    const query = `
      SELECT * FROM sp_create_appointment(
        $1::UUID, $2::UUID, $3::VARCHAR, $4::TEXT, $5::DATE,
        $6::TIME, $7::TIME, $8::VARCHAR, $9::VARCHAR, $10::VARCHAR,
        $11::VARCHAR, $12::TEXT, $13::BOOLEAN
      );
    `;
    
    const values = [
      agentId,
      data.clientId,
      data.title,
      data.description || null,
      data.appointmentDate,
      data.startTime,
      data.endTime,
      data.location || null,
      data.type,
      data.status || 'Scheduled',
      data.priority || 'Medium',
      data.notes || null,
      data.reminderSet ?? false,
    ];

    const result = await pool.query(query, values);
    const response = result.rows[0];

    if (response.success === 1) {
      // Send email notification
      await this.sendAppointmentNotification(agentId, response.appointment_id);
      return { success: true, appointmentId: response.appointment_id };
    } else {
      throw new Error(response.message);
    }
  }

  /**
   * Update appointment using stored procedure
   */
  async updateAppointment(appointmentId: string, agentId: string, data: UpdateAppointmentRequest) {
    const pool = await poolPromise;
    
    const query = `
      SELECT * FROM sp_update_appointment(
        $1::UUID, $2::UUID, $3::VARCHAR, $4::TEXT, $5::DATE,
        $6::TIME, $7::TIME, $8::VARCHAR, $9::VARCHAR, $10::VARCHAR,
        $11::TEXT, $12::BOOLEAN
      );
    `;
    
    const values = [
      appointmentId,
      agentId,
      data.title || null,
      data.description || null,
      data.appointmentDate || null,
      data.startTime || null,
      data.endTime || null,
      data.location || null,
      data.type || null,
      data.priority || null,
      data.notes || null,
      data.reminderSet ?? null,
    ];

    const result = await pool.query(query, values);
    const response = result.rows[0];

    if (response.success === 1) {
      return { success: true };
    } else {
      throw new Error(response.message);
    }
  }

  /**
   * Get appointment by ID using stored procedure
   */
  async getAppointmentById(appointmentId: string, agentId: string): Promise<Appointment | null> {
    const pool = await poolPromise;
    const query = `SELECT * FROM sp_get_appointment_by_id($1::UUID, $2::UUID);`;
    const { rows } = await pool.query(query, [appointmentId, agentId]);
    return rows.length ? this.mapAppointment(rows[0]) : null;
  }

  /**
   * Get all appointments with filters using stored procedure
   */
  async getAllAppointments(agentId: string, filters: AppointmentFilters = {}) {
    const pool = await poolPromise;
    const query = `
      SELECT * FROM sp_get_all_appointments(
        $1::UUID, $2::DATE, $3::DATE, $4::VARCHAR, $5::VARCHAR,
        $6::VARCHAR, $7::UUID, $8::VARCHAR, $9::INTEGER, $10::INTEGER
      );
    `;
    
    const values = [
      agentId,
      filters.startDate || null,
      filters.endDate || null,
      filters.status === 'all' || !filters.status ? null : filters.status,
      filters.type === 'all' || !filters.type ? null : filters.type,
      filters.priority || null,
      filters.clientId || null,
      filters.searchTerm || null,
      filters.pageSize || 50,
      filters.pageNumber || 1,
    ];

    const { rows } = await pool.query(query, values);
    const appointments = rows.map(this.mapAppointment);
    const total = rows[0]?.total_records || 0;

    return { appointments, total };
  }

  /**
   * Get today's appointments using stored procedure
   */
  async getTodaysAppointments(agentId: string): Promise<Appointment[]> {
    const pool = await poolPromise;
    const query = `SELECT * FROM sp_get_today_appointments($1::UUID);`;
    const { rows } = await pool.query(query, [agentId]);
    return rows.map(this.mapAppointment);
  }

  /**
   * Get appointments for specific date using stored procedure
   */
  async getAppointmentsForDate(agentId: string, appointmentDate: string): Promise<Appointment[]> {
    const pool = await poolPromise;
    const query = `SELECT * FROM sp_get_appointments_for_date($1::UUID, $2::DATE);`;
    const { rows } = await pool.query(query, [agentId, appointmentDate]);
    return rows.map(this.mapAppointment);
  }

  /**
   * Get week view appointments using stored procedure
   */
  async getWeekViewAppointments(agentId: string, weekStartDate?: string): Promise<WeekViewData[]> {
    const pool = await poolPromise;
    const query = `SELECT * FROM sp_get_week_view_appointments($1::UUID, $2::DATE);`;
    const { rows } = await pool.query(query, [agentId, weekStartDate || null]);
    
    // Group appointments by date
    const groupedByDate: { [key: string]: Appointment[] } = {};
    
    rows.forEach(row => {
      const appointment = this.mapAppointment(row);
      const dateKey = new Date(appointment.appointmentDate).toISOString().split('T')[0];
      
      if (!groupedByDate[dateKey]) {
        groupedByDate[dateKey] = [];
      }
      groupedByDate[dateKey].push(appointment);
    });

    // Convert to WeekViewData format
    return Object.keys(groupedByDate).map(date => ({
      date,
      dayName: rows.find(r => new Date(r.appointment_date).toISOString().split('T')[0] === date)?.day_name || '',
      appointments: groupedByDate[date]
    }));
  }

  /**
   * Get calendar appointments using stored procedure
   */
  async getCalendarAppointments(agentId: string, month: number, year: number): Promise<CalendarViewData[]> {
    const pool = await poolPromise;
    const query = `SELECT * FROM sp_get_calendar_appointments($1::UUID, $2::INTEGER, $3::INTEGER);`;
    const { rows } = await pool.query(query, [agentId, month, year]);
    
    // Group appointments by date
    const groupedByDate: { [key: string]: Appointment[] } = {};
    
    rows.forEach(row => {
      const appointment = this.mapAppointment(row);
      const dateKey = new Date(appointment.appointmentDate).toISOString().split('T')[0];
      
      if (!groupedByDate[dateKey]) {
        groupedByDate[dateKey] = [];
      }
      groupedByDate[dateKey].push(appointment);
    });

    // Convert to CalendarViewData format
    return Object.keys(groupedByDate).map(date => ({
      date,
      appointmentCount: groupedByDate[date].length,
      appointments: groupedByDate[date]
    }));
  }

  /**
   * Get appointment statistics using stored procedure
   */
  async getAppointmentStatistics(agentId: string): Promise<AppointmentStatistics> {
    const pool = await poolPromise;
    const query = `SELECT * FROM sp_get_appointment_statistics($1::UUID);`;
    const { rows } = await pool.query(query, [agentId]);
    
    if (!rows.length) {
      return this.getEmptyStatistics();
    }

    const stats = rows[0];
    
    // Get additional breakdowns for frontend
    const breakdownQuery = `
      SELECT 
        status,
        type,
        COUNT(*) as count
      FROM appointments
      WHERE agent_id = $1 AND is_active = TRUE
      GROUP BY ROLLUP(status, type);
    `;
    
    const { rows: breakdownRows } = await pool.query(breakdownQuery, [agentId]);
    
    const statusBreakdown: { [key: string]: number } = {};
    const typeBreakdown: { [key: string]: number } = {};
    
    breakdownRows.forEach(row => {
      if (row.status && !row.type) {
        statusBreakdown[row.status] = parseInt(row.count);
      }
      if (row.type && !row.status) {
        typeBreakdown[row.type] = parseInt(row.count);
      }
    });

    return {
      todayCount: parseInt(stats.today_appointments) || 0,
      weekCount: parseInt(stats.week_appointments) || 0,
      monthCount: parseInt(stats.month_appointments) || 0,
      completedCount: parseInt(stats.completed_appointments) || 0,
      totalAppointments: parseInt(stats.today_appointments) + parseInt(stats.upcoming_appointments) + parseInt(stats.completed_appointments) || 0,
      todayAppointments: parseInt(stats.today_appointments) || 0,
      weekAppointments: parseInt(stats.week_appointments) || 0,
      monthAppointments: parseInt(stats.month_appointments) || 0,
      completedAppointments: parseInt(stats.completed_appointments) || 0,
      pendingAppointments: parseInt(stats.upcoming_appointments) || 0,
      statusBreakdown,
      typeBreakdown,
      scheduledCount: statusBreakdown['Scheduled'] || 0,
      confirmedCount: statusBreakdown['Confirmed'] || 0,
      cancelledCount: parseInt(stats.cancelled_appointments) || 0
    };
  }

  /**
   * Check time conflicts using stored procedure
   */
  async checkTimeConflicts(
    agentId: string, 
    appointmentDate: string, 
    startTime: string, 
    endTime: string, 
    excludeAppointmentId?: string
  ): Promise<ConflictCheckResponse> {
    const pool = await poolPromise;
    const query = `
      SELECT * FROM sp_check_time_conflicts(
        $1::UUID, $2::DATE, $3::TIME, $4::TIME, $5::UUID
      );
    `;
    
    const { rows } = await pool.query(query, [
      agentId, 
      appointmentDate, 
      startTime, 
      endTime, 
      excludeAppointmentId || null
    ]);
    
    const result = rows[0];
    const hasConflicts = result.has_conflict === 1;
    
    let conflictingAppointments: Appointment[] = [];
    
    if (hasConflicts) {
      // Get the actual conflicting appointments
      const conflictQuery = `
        SELECT * FROM appointments
        WHERE agent_id = $1
          AND appointment_date = $2
          AND is_active = TRUE
          AND status NOT IN ('Cancelled')
          AND ($5::UUID IS NULL OR appointment_id <> $5)
          AND NOT ($4::TIME <= start_time OR $3::TIME >= end_time);
      `;
      
      const { rows: conflictRows } = await pool.query(conflictQuery, [
        agentId, appointmentDate, startTime, endTime, excludeAppointmentId || null
      ]);
      
      conflictingAppointments = conflictRows.map(this.mapAppointment);
    }

    return {
      conflicts: result.conflict_count,
      hasConflicts,
      conflictingAppointments,
      message: hasConflicts ? `Found ${result.conflict_count} conflicting appointment(s)` : 'No conflicts found'
    };
  }

  /**
   * Update appointment status using stored procedure
   */
  async updateAppointmentStatus(appointmentId: string, agentId: string, status: string) {
    const pool = await poolPromise;
    const query = `SELECT * FROM sp_update_appointment_status($1::UUID, $2::UUID, $3::VARCHAR);`;
    const { rows } = await pool.query(query, [appointmentId, agentId, status]);
    
    const rowsAffected = rows[0]?.rows_affected || 0;
    return { success: rowsAffected > 0 };
  }

  /**
   * Delete appointment using stored procedure
   */
  async deleteAppointment(appointmentId: string, agentId: string) {
    const pool = await poolPromise;
    const query = `SELECT * FROM sp_delete_appointment($1::UUID, $2::UUID);`;
    const { rows } = await pool.query(query, [appointmentId, agentId]);
    
    const rowsAffected = rows[0]?.rows_affected || 0;
    return { success: rowsAffected > 0 };
  }

  /**
   * Search appointments using stored procedure
   */
  async searchAppointments(agentId: string, searchTerm: string): Promise<Appointment[]> {
    const pool = await poolPromise;
    const query = `SELECT * FROM sp_search_appointments($1::UUID, $2::VARCHAR);`;
    const { rows } = await pool.query(query, [agentId, searchTerm]);
    return rows.map(this.mapAppointment);
  }

  /**
   * Get appointments with filters using stored procedure
   */
  async getAppointments(
    agentId: string,
    dateRangeFilter: string = 'all',
    statusFilter: string = 'all',
    typeFilter: string = 'all',
    searchTerm?: string,
    startDate?: string,
    endDate?: string
  ): Promise<Appointment[]> {
    const pool = await poolPromise;
    const query = `
      SELECT * FROM sp_get_appointments(
        $1::UUID, $2::VARCHAR, $3::VARCHAR, $4::VARCHAR, 
        $5::VARCHAR, $6::DATE, $7::DATE
      );
    `;
    
    const { rows } = await pool.query(query, [
      agentId,
      dateRangeFilter,
      statusFilter,
      typeFilter,
      searchTerm || null,
      startDate || null,
      endDate || null
    ]);
    
    return rows.map(this.mapAppointment);
  }

  /**
   * Send email notification for new appointments
   */
  private async sendAppointmentNotification(agentId: string, appointmentId: string) {
    try {
      const appointment = await this.getAppointmentById(appointmentId, agentId);
      const stats = await this.getAppointmentStatistics(agentId);
      
      if (!appointment) return;

      const body = `
        New appointment created ✅

        Client: ${appointment.clientName}
        Date: ${appointment.appointmentDate}
        Time: ${appointment.startTime} - ${appointment.endTime}
        Location: ${appointment.location || "N/A"}
        Type: ${appointment.type}
        Status: ${appointment.status}

        📊 Statistics:
        Today: ${stats.todayAppointments}
        Week: ${stats.weekAppointments}
        Month: ${stats.monthAppointments}
        Completed: ${stats.completedAppointments}
      `;

      const agentQuery = `SELECT email FROM agent WHERE agent_id = $1`;
      const pool = await poolPromise;
      const agentRes = await pool.query(agentQuery, [agentId]);
      const recipient = agentRes.rows[0]?.email || process.env.FALLBACK_AGENT_EMAIL;
      
      await emailService.sendMail(
        recipient,
        `New Appointment Scheduled: ${appointment.title}`,
        body
      );
    } catch (error) {
      console.error('Failed to send appointment notification:', error);
      // Don't throw - notification failure shouldn't break appointment creation
    }
  }

  /**
   * Map database row to Appointment object
   */
  private mapAppointment(row: any): Appointment {
    return {
      appointmentId: row.appointment_id,
      clientId: row.client_id,
      agentId: row.agent_id,
      clientName: row.client_name || '',
      clientPhone: row.client_phone || null,
      clientEmail: row.client_email || null,
      clientAddress: row.client_address || null,
      title: row.title,
      description: row.description,
      appointmentDate: row.appointment_date,
      startTime: row.start_time,
      endTime: row.end_time,
      location: row.location,
      type: row.type,
      status: row.status,
      priority: row.priority,
      notes: row.notes,
      reminderSet: row.reminder_set || false,
      createdDate: row.created_date,
      modifiedDate: row.modified_date,
      isActive: row.is_active || true,
      formattedTime: row.time_range || `${row.start_time} - ${row.end_time}`
    };
  }

  /**
   * Get empty statistics object
   */
  private getEmptyStatistics(): AppointmentStatistics {
    return {
      todayCount: 0,
      weekCount: 0,
      monthCount: 0,
      completedCount: 0,
      totalAppointments: 0,
      todayAppointments: 0,
      weekAppointments: 0,
      monthAppointments: 0,
      completedAppointments: 0,
      pendingAppointments: 0,
      statusBreakdown: {},
      typeBreakdown: {},
      scheduledCount: 0,
      confirmedCount: 0,
      cancelledCount: 0
    };
  }
}