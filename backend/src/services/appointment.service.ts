// services/appointment.service.ts
import { poolPromise } from "../../db";
import emailService from "../nodemailer/emailservice";

import {
  Appointment,
  AppointmentFilters,
  AppointmentStatistics,
  CreateAppointmentRequest,
  UpdateAppointmentRequest,
  WeekViewAppointment,
  CalendarAppointment,
  TimeConflictCheck,
} from "../interfaces/appointment";
import { QueryResult } from "pg";

export class AppointmentService {
  /**
   * 🔎 Search clients for autocomplete
   */
  async searchClientsForAutocomplete(searchTerm: string, agentId: string) {
    const pool = await poolPromise;
    const query = `
      SELECT 
        "ClientId",
        CONCAT("FirstName",' ',"Surname",' ',"LastName") AS "FullName",
        "PhoneNumber","Email"
      FROM "Clients"
      WHERE "AgentId"=$1
        AND "IsActive"=TRUE
        AND (
          "FirstName" ILIKE $2 OR
          "Surname" ILIKE $2 OR
          "LastName" ILIKE $2 OR
          "PhoneNumber" ILIKE $2 OR
          "Email" ILIKE $2
        )
      ORDER BY "FirstName"
      LIMIT 10;
    `;
    const { rows } = await pool.query(query, [agentId, `%${searchTerm}%`]);
    return rows;
  }

  /**
   * 📅 Create appointment
   */
  async createAppointment(agentId: string, data: CreateAppointmentRequest) {
    const pool = await poolPromise;
    const insertQuery = `
      INSERT INTO "Appointments" (
        "AgentId","ClientId","Title","Description","AppointmentDate",
        "StartTime","EndTime","Location","Type","Status","Priority",
        "Notes","ReminderSet","CreatedDate","IsActive"
      ) VALUES (
        $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,NOW(),TRUE
      )
      RETURNING "AppointmentId";
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
      data.status || "Scheduled",
      data.priority || "Medium",
      data.notes || null,
      data.reminderSet ?? false,
    ];
    const res = await pool.query(insertQuery, values);
    const appointmentId = res.rows[0].AppointmentId;

    // Notify agent via email
    const stats = await this.getAppointmentStatistics(agentId);
    const weekView = await this.getWeekViewAppointments(agentId);

    const scheduleList = weekView
      .map(
        (a) =>
          `- ${a.dayName} (${new Date(a.appointmentDate).toDateString()}): ${
            a.title
          } with ${a.clientName}`
      )
      .join("\n");

    const body = `
      New appointment created ✅

      Client: ${data.clientId}
      Date: ${data.appointmentDate}
      Time: ${data.startTime} - ${data.endTime}
      Location: ${data.location || "N/A"}
      Type: ${data.type}
      Status: Scheduled

      📅 Weekly Schedule:
      ${scheduleList}

      📊 Statistics:
      Today: ${stats.todayAppointments}
      Week: ${stats.weekAppointments}
      Month: ${stats.monthAppointments}
      Completed: ${stats.completedAppointments}
      Upcoming: ${stats.upcomingAppointments}
      Cancelled: ${stats.cancelledAppointments}
    `;

    const agentRes = await pool.query(
      `SELECT "Email" FROM "Agent" WHERE "AgentId"=$1`,
      [agentId]
    );
    const recipient = agentRes.rows[0]?.Email || process.env.FALLBACK_AGENT_EMAIL;
    await emailService.sendMail(
      recipient,
      `New Appointment Scheduled: ${data.title}`,
      body
    );

    return { success: true, appointmentId };
  }

  /**
   * ✏️ Update appointment
   */
  async updateAppointment(
    appointmentId: string,
    agentId: string,
    data: UpdateAppointmentRequest
  ) {
    const pool = await poolPromise;
    const query = `
      UPDATE "Appointments"
      SET "Title"=$1,"Description"=$2,"AppointmentDate"=$3,
          "StartTime"=$4,"EndTime"=$5,"Location"=$6,"Type"=$7,
          "Status"=$8,"Priority"=$9,"Notes"=$10,"ReminderSet"=$11,
          "ModifiedDate"=NOW()
      WHERE "AppointmentId"=$12 AND "AgentId"=$13
    `;
    const values = [
      data.title,
      data.description,
      data.appointmentDate,
      data.startTime,
      data.endTime,
      data.location,
      data.type,
      data.status,
      data.priority,
      data.notes,
      data.reminderSet ?? false,
      appointmentId,
      agentId,
    ];
const { rowCount } = await pool.query(query, values);
return { success: (rowCount ?? 0) > 0 }; // defensive, but not needed

  }

  /**
   * 📖 Get appointment by ID
   */
 async getAppointmentById(appointmentId: string, agentId: string) {
  const pool = await poolPromise;
  const query = `
    SELECT a.*, 
           CONCAT(c."FirstName",' ',c."Surname",' ',c."LastName") AS "FullName",
           c."PhoneNumber", c."Email", c."Address"
    FROM "Appointments" a
    JOIN "Clients" c ON a."ClientId"=c."ClientId"
    WHERE a."AppointmentId"=$1 AND a."AgentId"=$2
  `;
  const { rows } = await pool.query(query, [appointmentId, agentId]);
  return rows.length ? this.mapAppointment(rows[0]) : null;
}


  /**
   * 📋 Get all appointments (with filters)*/
async getAllAppointments(agentId: string, filters: AppointmentFilters) {
  const pool = await poolPromise;
  const query = `
    SELECT a.*, 
           CONCAT(c."FirstName",' ',c."Surname",' ',c."LastName") AS "FullName",
           c."PhoneNumber", c."Email", c."Address",
           COUNT(*) OVER() as total
    FROM "Appointments" a
    JOIN "Clients" c ON a."ClientId"=c."ClientId"
    WHERE a."AgentId"=$1
      AND ($2::DATE IS NULL OR a."AppointmentDate">=$2)
      AND ($3::DATE IS NULL OR a."AppointmentDate"<=$3)
      AND ($4::TEXT IS NULL OR a."Status"=$4)
      AND ($5::TEXT IS NULL OR a."Type"=$5)
      AND ($6::TEXT IS NULL OR a."Priority"=$6)
      AND ($7::UUID IS NULL OR a."ClientId"=$7)
      AND ($8::TEXT IS NULL OR a."Title" ILIKE '%'||$8||'%')
    ORDER BY a."AppointmentDate" DESC
    LIMIT $9 OFFSET (($10-1)*$9);
  `;
  const values = [
    agentId,
    filters.startDate || null,
    filters.endDate || null,
    filters.statusFilter === "all" ? null : filters.statusFilter,
    filters.typeFilter === "all" ? null : filters.typeFilter,
    filters.priority || null,
    filters.clientId || null,
    filters.searchTerm || null,
    filters.pageSize || 50,
    filters.pageNumber || 1,
  ];
  const { rows } = await pool.query(query, values);
  return { appointments: rows.map(this.mapAppointment), total: rows[0]?.total || 0 };
}


  /**
   * 📊 Appointment stats
   */
  async getAppointmentStatistics(agentId: string): Promise<AppointmentStatistics> {
    const pool = await poolPromise;
    const query = `
      SELECT
        COUNT(*) FILTER (WHERE DATE("AppointmentDate")=CURRENT_DATE) AS "todayAppointments",
        COUNT(*) FILTER (WHERE DATE_TRUNC('week',"AppointmentDate")=DATE_TRUNC('week',CURRENT_DATE)) AS "weekAppointments",
        COUNT(*) FILTER (WHERE DATE_TRUNC('month',"AppointmentDate")=DATE_TRUNC('month',CURRENT_DATE)) AS "monthAppointments",
        COUNT(*) FILTER (WHERE "Status"='Completed') AS "completedAppointments",
        COUNT(*) FILTER (WHERE "Status"='Scheduled' AND "AppointmentDate">=CURRENT_DATE) AS "upcomingAppointments",
        COUNT(*) FILTER (WHERE "Status"='Cancelled') AS "cancelledAppointments"
      FROM "Appointments"
      WHERE "AgentId"=$1;
    `;
    const { rows } = await pool.query(query, [agentId]);
    return rows[0];
  }

  /**
   * 📆 Week view
   */
  async getWeekViewAppointments(agentId: string): Promise<WeekViewAppointment[]> {
    const pool = await poolPromise;
    const query = `
      SELECT "AppointmentId","Title","AppointmentDate","StartTime","EndTime",
             EXTRACT(DOW FROM "AppointmentDate") AS "dayOfWeek",
             TO_CHAR("AppointmentDate",'Day') AS "dayName"
      FROM "Appointments"
      WHERE "AgentId"=$1
        AND DATE_TRUNC('week',"AppointmentDate")=DATE_TRUNC('week',CURRENT_DATE)
      ORDER BY "AppointmentDate","StartTime";
    `;
    const { rows } = await pool.query(query, [agentId]);
    return rows;
  }

  /**
   * 🗓️ Calendar appointments
   */
  async getCalendarAppointments(agentId: string, month: number, year: number): Promise<CalendarAppointment[]> {
    const pool = await poolPromise;
    const query = `
      SELECT "AppointmentId","Title","AppointmentDate","StartTime","EndTime","Status"
      FROM "Appointments"
      WHERE "AgentId"=$1
        AND EXTRACT(MONTH FROM "AppointmentDate")=$2
        AND EXTRACT(YEAR FROM "AppointmentDate")=$3
      ORDER BY "AppointmentDate";
    `;
    const { rows } = await pool.query(query, [agentId, month, year]);
    return rows;
  }

  /**
   * ⏰ Time conflict check
   */
  async checkTimeConflicts(agentId: string, date: string, startTime: string, endTime: string): Promise<TimeConflictCheck[]> {
    const pool = await poolPromise;
    const query = `
      SELECT "AppointmentId","Title","StartTime","EndTime"
      FROM "Appointments"
      WHERE "AgentId"=$1
        AND "AppointmentDate"=$2
        AND ("StartTime"<$3 AND "EndTime">$4)
    `;
    const { rows } = await pool.query(query, [agentId, date, endTime, startTime]);
    return rows;
  }

  /**
   * ❌ Delete appointment
   */
  

async deleteAppointment(agentId: string, appointmentId: string) {
  const pool = await poolPromise;
  const result: QueryResult = await pool.query(
    `DELETE FROM "Appointments" WHERE "AgentId"=$1 AND "AppointmentId"=$2`,
    [agentId, appointmentId]
  );
  return { success: (result.rowCount ?? 0) > 0 };
}

  /**
   * 🛠️ Map DB row → Appointment
   */
  private mapAppointment(row: any): Appointment {
  return {
    appointmentId: row.AppointmentId,
    clientId: row.ClientId,
    agentId: row.AgentId,
    clientName: row.FullName || row.ClientName || "",
    clientPhone: row.PhoneNumber || null,
    clientEmail: row.Email || null,
    clientAddress: row.Address || null,
    title: row.Title,
    description: row.Description,
    appointmentDate: row.AppointmentDate,
    startTime: row.StartTime,
    endTime: row.EndTime,
    location: row.Location,
    type: row.Type,
    status: row.Status,
    priority: row.Priority,
    notes: row.Notes,
    reminderSet: row.ReminderSet,
    createdDate: row.CreatedDate,
    modifiedDate: row.ModifiedDate,
    isActive: row.IsActive,
  };
}

}
