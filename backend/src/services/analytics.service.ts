// // services/analytics.service.ts

import  pool  from '../../db';
import {
    ActivityLog,
    DashboardStatistics,
    PerformanceMetrics,
    TaskSummary,
    MonthlyReport,
    CreateActivityLogRequest,
    DashboardStatsRequest,
    PerformanceMetricsRequest,
    TaskSummaryRequest,
    MonthlyReportRequest,
    DashboardCacheRequest
} from '../interfaces/analytics';

export class AnalyticsService {

    // ----------------- Activity Logs -----------------
    public async createActivityLog(request: CreateActivityLogRequest): Promise<ActivityLog> {
        const query = `
            INSERT INTO activity_log (agent_id, activity_type, entity_type, entity_id, description, additional_data)
            VALUES ($1, $2, $3, $4, $5, $6)
            RETURNING *;
        `;
        const values = [
            request.agentId,
            request.activityType,
            request.entityType,
            request.entityId,
            request.description,
            request.additionalData
        ];
        const result = await pool.query(query, values);
        return this.mapActivityLog(result.rows[0]);
    }

    public async getActivityLogsByAgent(agentId: string, limit: number = 50): Promise<ActivityLog[]> {
        const query = `
            SELECT * FROM activity_log
            WHERE agent_id = $1
            ORDER BY activity_date DESC
            LIMIT $2;
        `;
        const result = await pool.query(query, [agentId, limit]);
        return result.rows.map(this.mapActivityLog);
    }

    public async getActivityLogsByDateRange(agentId: string, startDate: Date, endDate: Date): Promise<ActivityLog[]> {
        const query = `
            SELECT * FROM activity_log
            WHERE agent_id = $1
              AND activity_date BETWEEN $2 AND $3
            ORDER BY activity_date DESC;
        `;
        const result = await pool.query(query, [agentId, startDate, endDate]);
        return result.rows.map(this.mapActivityLog);
    }

    // ----------------- Dashboard Statistics -----------------
    public async getDashboardStatistics(request: DashboardStatsRequest): Promise<DashboardStatistics | null> {
        const query = `
            SELECT * FROM dashboard_statistics
            WHERE agent_id = $1 AND stat_date = $2
            LIMIT 1;
        `;
        const statDate = request.statDate || new Date();
        const result = await pool.query(query, [request.agentId, statDate]);
        return result.rows.length ? this.mapDashboardStatistics(result.rows[0]) : null;
    }

    public async updateDashboardStatistics(agentId: string, stats: Partial<DashboardStatistics>): Promise<DashboardStatistics> {
        const query = `
            INSERT INTO dashboard_statistics (
                agent_id, stat_date, total_clients, total_prospects, active_policies,
                today_appointments, week_appointments, month_appointments,
                completed_appointments, pending_reminders, today_birthdays, expiring_policies
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
            ON CONFLICT (agent_id, stat_date)
            DO UPDATE SET
                total_clients = EXCLUDED.total_clients,
                total_prospects = EXCLUDED.total_prospects,
                active_policies = EXCLUDED.active_policies,
                today_appointments = EXCLUDED.today_appointments,
                week_appointments = EXCLUDED.week_appointments,
                month_appointments = EXCLUDED.month_appointments,
                completed_appointments = EXCLUDED.completed_appointments,
                pending_reminders = EXCLUDED.pending_reminders,
                today_birthdays = EXCLUDED.today_birthdays,
                expiring_policies = EXCLUDED.expiring_policies,
                updated_date = NOW()
            RETURNING *;
        `;
        const statDate = stats.statDate || new Date();
        const values = [
            agentId,
            statDate,
            stats.totalClients || 0,
            stats.totalProspects || 0,
            stats.activePolicies || 0,
            stats.todayAppointments || 0,
            stats.weekAppointments || 0,
            stats.monthAppointments || 0,
            stats.completedAppointments || 0,
            stats.pendingReminders || 0,
            stats.todayBirthdays || 0,
            stats.expiringPolicies || 0
        ];
        const result = await pool.query(query, values);
        return this.mapDashboardStatistics(result.rows[0]);
    }

    // ----------------- Performance Metrics -----------------
    public async getPerformanceMetrics(request: PerformanceMetricsRequest): Promise<PerformanceMetrics[]> {
        const query = `
            SELECT * FROM performance_metrics
            WHERE agent_id = $1
              AND metric_date BETWEEN $2 AND $3
            ORDER BY metric_date DESC;
        `;
        const result = await pool.query(query, [request.agentId, request.startDate, request.endDate]);
        return result.rows.map(this.mapPerformanceMetrics);
    }

    public async updatePerformanceMetrics(agentId: string, metricDate: Date, metrics: Partial<PerformanceMetrics>): Promise<PerformanceMetrics> {
        const query = `
            INSERT INTO performance_metrics (
                agent_id, metric_date, new_clients_added, prospects_converted,
                appointments_completed, policies_sold, reminders_completed,
                messages_set, client_interactions
            )
            VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
            ON CONFLICT (agent_id, metric_date)
            DO UPDATE SET
                new_clients_added = EXCLUDED.new_clients_added,
                prospects_converted = EXCLUDED.prospects_converted,
                appointments_completed = EXCLUDED.appointments_completed,
                policies_sold = EXCLUDED.policies_sold,
                reminders_completed = EXCLUDED.reminders_completed,
                messages_set = EXCLUDED.messages_set,
                client_interactions = EXCLUDED.client_interactions
            RETURNING *;
        `;
        const values = [
            agentId,
            metricDate,
            metrics.newClientsAdded || 0,
            metrics.prospectsConverted || 0,
            metrics.appointmentsCompleted || 0,
            metrics.policiesSold || 0,
            metrics.remindersCompleted || 0,
            metrics.messagesSet || 0,
            metrics.clientInteractions || 0
        ];
        const result = await pool.query(query, values);
        return this.mapPerformanceMetrics(result.rows[0]);
    }

    // ----------------- Task Summary -----------------
    public async createTaskSummary(request: TaskSummaryRequest): Promise<TaskSummary> {
        const query = `
            INSERT INTO task_summary (agent_id, task_date, task_type, task_description, priority, client_id, appointment_id, due_time)
            VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
            RETURNING *;
        `;
        const values = [
            request.agentId,
            request.taskDate,
            request.taskType,
            request.taskDescription,
            request.priority || 'Medium',
            request.clientId,
            request.appointmentId,
            request.dueTime
        ];
        const result = await pool.query(query, values);
        return this.mapTaskSummary(result.rows[0]);
    }

    public async getTasksSummary(agentId: string, taskDate?: Date): Promise<TaskSummary[]> {
        const query = `
            SELECT * FROM task_summary
            WHERE agent_id = $1
            ${taskDate ? 'AND task_date = $2' : ''}
            ORDER BY task_date DESC, due_time ASC;
        `;
        const values = taskDate ? [agentId, taskDate] : [agentId];
        const result = await pool.query(query, values);
        return result.rows.map(this.mapTaskSummary);
    }

    public async updateTaskStatus(taskId: string, status: string, completedDate?: Date): Promise<boolean> {
        const query = `
            UPDATE task_summary
            SET status = $2, completed_date = $3
            WHERE task_id = $1;
        `;
        const result = await pool.query(query, [taskId, status, completedDate]);
        return result.rowCount > 0;
    }

    // ----------------- Monthly Reports -----------------
    public async generateMonthlyReport(request: MonthlyReportRequest): Promise<MonthlyReport> {
        // Assuming you have a stored function in Postgres instead of sp_GenerateMonthlyReport
        const result = await pool.query(`SELECT * FROM generate_monthly_report($1, $2);`, [
            request.agentId,
            request.reportMonth
        ]);
        return this.mapMonthlyReport(result.rows[0]);
    }

    public async getMonthlyReports(agentId: string, startMonth: Date, endMonth: Date): Promise<MonthlyReport[]> {
        const query = `
            SELECT * FROM monthly_reports
            WHERE agent_id = $1
              AND report_month BETWEEN $2 AND $3
            ORDER BY report_month DESC;
        `;
        const result = await pool.query(query, [agentId, startMonth, endMonth]);
        return result.rows.map(this.mapMonthlyReport);
    }

    // ----------------- Dashboard Cache -----------------
    public async getCachedView(agentId: string, viewName: string, cacheDate: Date): Promise<string | null> {
        const query = `
            SELECT cache_data FROM dashboard_views_cache
            WHERE agent_id = $1 AND view_name = $2 AND cache_date = $3
              AND (expires_at IS NULL OR expires_at > NOW())
            LIMIT 1;
        `;
        const result = await pool.query(query, [agentId, viewName, cacheDate]);
        return result.rows.length ? result.rows[0].cache_data : null;
    }

    public async setCachedView(request: DashboardCacheRequest): Promise<void> {
        const query = `
            INSERT INTO dashboard_views_cache (agent_id, view_name, cache_date, cache_data, expires_at)
            VALUES ($1,$2,$3,$4,$5)
            ON CONFLICT (agent_id, view_name, cache_date)
            DO UPDATE SET cache_data = EXCLUDED.cache_data, expires_at = EXCLUDED.expires_at;
        `;
        const cacheDate = new Date();
        const expiresAt = request.expirationHours
            ? new Date(Date.now() + request.expirationHours * 60 * 60 * 1000)
            : null;
        await pool.query(query, [
            request.agentId,
            request.viewName,
            cacheDate,
            request.cacheData,
            expiresAt
        ]);
    }

    public async clearExpiredCache(): Promise<void> {
        await pool.query(`
            DELETE FROM dashboard_views_cache
            WHERE expires_at IS NOT NULL AND expires_at < NOW();
        `);
    }

    // ----------------- Mapping Helpers -----------------
    private mapActivityLog(row: any): ActivityLog {
        return {
            activityId: row.activity_id,
            agentId: row.agent_id,
            activityType: row.activity_type,
            entityType: row.entity_type,
            entityId: row.entity_id,
            description: row.description,
            activityDate: row.activity_date,
            additionalData: row.additional_data
        };
    }

    private mapDashboardStatistics(row: any): DashboardStatistics {
        return {
            statId: row.stat_id,
            agentId: row.agent_id,
            statDate: row.stat_date,
            totalClients: row.total_clients,
            totalProspects: row.total_prospects,
            activePolicies: row.active_policies,
            todayAppointments: row.today_appointments,
            weekAppointments: row.week_appointments,
            monthAppointments: row.month_appointments,
            completedAppointments: row.completed_appointments,
            pendingReminders: row.pending_reminders,
            todayBirthdays: row.today_birthdays,
            expiringPolicies: row.expiring_policies,
            createdDate: row.created_date,
            updatedDate: row.updated_date
        };
    }

    private mapPerformanceMetrics(row: any): PerformanceMetrics {
        return {
            metricId: row.metric_id,
            agentId: row.agent_id,
            metricDate: row.metric_date,
            newClientsAdded: row.new_clients_added,
            prospectsConverted: row.prospects_converted,
            appointmentsCompleted: row.appointments_completed,
            policiesSold: row.policies_sold,
            remindersCompleted: row.reminders_completed,
            messagesSet: row.messages_set,
            clientInteractions: row.client_interactions,
            createdDate: row.created_date
        };
    }

    private mapTaskSummary(row: any): TaskSummary {
        return {
            taskId: row.task_id,
            agentId: row.agent_id,
            taskDate: row.task_date,
            taskType: row.task_type,
            taskDescription: row.task_description,
            priority: row.priority,
            status: row.status,
            clientId: row.client_id,
            appointmentId: row.appointment_id,
            dueTime: row.due_time,
            completedDate: row.completed_date,
            createdDate: row.created_date
        };
    }

    private mapMonthlyReport(row: any): MonthlyReport {
        return {
            reportId: row.report_id,
            agentId: row.agent_id,
            reportMonth: row.report_month,
            totalClientsAdded: row.total_clients_added,
            totalProspectsAdded: row.total_prospects_added,
            prospectsConverted: row.prospects_converted,
            totalAppointments: row.total_appointments,
            completedAppointments: row.completed_appointments,
            cancelledAppointments: row.cancelled_appointments,
            totalReminders: row.total_reminders,
            completedReminders: row.completed_reminders,
            messagesSent: row.messages_sent,
            newPolicies: row.new_policies,
            renewedPolicies: row.renewed_policies,
            expiredPolicies: row.expired_policies,
            generatedDate: row.generated_date
        };
    }
}
