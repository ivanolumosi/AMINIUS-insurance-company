// services/analytics.service.ts

import { poolPromise } from '../../db';
import * as sql from 'mssql';
import {
    ActivityLog,
    DashboardStatistics,
    PerformanceMetrics,
    TaskSummary,
    MonthlyReport,
    DashboardViewsCache,
    CreateActivityLogRequest,
    DashboardStatsRequest,
    PerformanceMetricsRequest,
    TaskSummaryRequest,
    MonthlyReportRequest,
    DashboardCacheRequest
} from '../interfaces/analytics';

export class AnalyticsService {
    
    // Activity Log Methods
    public async createActivityLog(request: CreateActivityLogRequest): Promise<ActivityLog> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('agentId', sql.UniqueIdentifier, request.agentId)
            .input('activityType', sql.NVarChar(50), request.activityType)
            .input('entityType', sql.NVarChar(50), request.entityType)
            .input('entityId', sql.UniqueIdentifier, request.entityId)
            .input('description', sql.NVarChar(500), request.description)
            .input('additionalData', sql.NVarChar(sql.MAX), request.additionalData)
            .query(`
                INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description, AdditionalData)
                VALUES (@agentId, @activityType, @entityType, @entityId, @description, @additionalData);
                SELECT * FROM ActivityLog WHERE ActivityId = SCOPE_IDENTITY();
            `);

        return this.mapActivityLog(result.recordset[0]);
    }

    public async getActivityLogsByAgent(agentId: string, limit: number = 50): Promise<ActivityLog[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('agentId', sql.UniqueIdentifier, agentId)
            .input('limit', sql.Int, limit)
            .query(`
                SELECT TOP (@limit) * FROM ActivityLog 
                WHERE AgentId = @agentId 
                ORDER BY ActivityDate DESC
            `);

        return result.recordset.map(this.mapActivityLog);
    }

    public async getActivityLogsByDateRange(agentId: string, startDate: Date, endDate: Date): Promise<ActivityLog[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('agentId', sql.UniqueIdentifier, agentId)
            .input('startDate', sql.DateTime2, startDate)
            .input('endDate', sql.DateTime2, endDate)
            .query(`
                SELECT * FROM ActivityLog 
                WHERE AgentId = @agentId 
                AND ActivityDate BETWEEN @startDate AND @endDate
                ORDER BY ActivityDate DESC
            `);

        return result.recordset.map(this.mapActivityLog);
    }

    // Dashboard Statistics Methods
    public async getDashboardStatistics(request: DashboardStatsRequest): Promise<DashboardStatistics | null> {
        const pool = await poolPromise;
        const statDate = request.statDate || new Date();
        
        const result = await pool.request()
            .input('agentId', sql.UniqueIdentifier, request.agentId)
            .input('statDate', sql.Date, statDate)
            .query(`
                SELECT * FROM DashboardStatistics 
                WHERE AgentId = @agentId AND StatDate = @statDate
            `);

        return result.recordset.length ? this.mapDashboardStatistics(result.recordset[0]) : null;
    }

    public async updateDashboardStatistics(agentId: string, stats: Partial<DashboardStatistics>): Promise<DashboardStatistics> {
        const pool = await poolPromise;
        const statDate = stats.statDate || new Date();
        
        const result = await pool.request()
            .input('agentId', sql.UniqueIdentifier, agentId)
            .input('statDate', sql.Date, statDate)
            .input('totalClients', sql.Int, stats.totalClients || 0)
            .input('totalProspects', sql.Int, stats.totalProspects || 0)
            .input('activePolicies', sql.Int, stats.activePolicies || 0)
            .input('todayAppointments', sql.Int, stats.todayAppointments || 0)
            .input('weekAppointments', sql.Int, stats.weekAppointments || 0)
            .input('monthAppointments', sql.Int, stats.monthAppointments || 0)
            .input('completedAppointments', sql.Int, stats.completedAppointments || 0)
            .input('pendingReminders', sql.Int, stats.pendingReminders || 0)
            .input('todayBirthdays', sql.Int, stats.todayBirthdays || 0)
            .input('expiringPolicies', sql.Int, stats.expiringPolicies || 0)
            .query(`
                MERGE DashboardStatistics AS target
                USING (VALUES (@agentId, @statDate, @totalClients, @totalProspects, @activePolicies, 
                              @todayAppointments, @weekAppointments, @monthAppointments, 
                              @completedAppointments, @pendingReminders, @todayBirthdays, @expiringPolicies)) 
                AS source (AgentId, StatDate, TotalClients, TotalProspects, ActivePolicies,
                          TodayAppointments, WeekAppointments, MonthAppointments,
                          CompletedAppointments, PendingReminders, TodayBirthdays, ExpiringPolicies)
                ON target.AgentId = source.AgentId AND target.StatDate = source.StatDate
                WHEN MATCHED THEN
                    UPDATE SET TotalClients = source.TotalClients,
                              TotalProspects = source.TotalProspects,
                              ActivePolicies = source.ActivePolicies,
                              TodayAppointments = source.TodayAppointments,
                              WeekAppointments = source.WeekAppointments,
                              MonthAppointments = source.MonthAppointments,
                              CompletedAppointments = source.CompletedAppointments,
                              PendingReminders = source.PendingReminders,
                              TodayBirthdays = source.TodayBirthdays,
                              ExpiringPolicies = source.ExpiringPolicies,
                              UpdatedDate = GETUTCDATE()
                WHEN NOT MATCHED THEN
                    INSERT (AgentId, StatDate, TotalClients, TotalProspects, ActivePolicies,
                           TodayAppointments, WeekAppointments, MonthAppointments,
                           CompletedAppointments, PendingReminders, TodayBirthdays, ExpiringPolicies)
                    VALUES (source.AgentId, source.StatDate, source.TotalClients, source.TotalProspects, 
                           source.ActivePolicies, source.TodayAppointments, source.WeekAppointments,
                           source.MonthAppointments, source.CompletedAppointments, source.PendingReminders,
                           source.TodayBirthdays, source.ExpiringPolicies);
                
                SELECT * FROM DashboardStatistics WHERE AgentId = @agentId AND StatDate = @statDate;
            `);

        return this.mapDashboardStatistics(result.recordset[0]);
    }

    // Performance Metrics Methods
    public async getPerformanceMetrics(request: PerformanceMetricsRequest): Promise<PerformanceMetrics[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('agentId', sql.UniqueIdentifier, request.agentId)
            .input('startDate', sql.Date, request.startDate)
            .input('endDate', sql.Date, request.endDate)
            .query(`
                SELECT * FROM PerformanceMetrics 
                WHERE AgentId = @agentId 
                AND MetricDate BETWEEN @startDate AND @endDate
                ORDER BY MetricDate DESC
            `);

        return result.recordset.map(this.mapPerformanceMetrics);
    }

    public async updatePerformanceMetrics(agentId: string, metricDate: Date, metrics: Partial<PerformanceMetrics>): Promise<PerformanceMetrics> {
        const pool = await poolPromise;
        
        const result = await pool.request()
            .input('agentId', sql.UniqueIdentifier, agentId)
            .input('metricDate', sql.Date, metricDate)
            .input('newClientsAdded', sql.Int, metrics.newClientsAdded || 0)
            .input('prospectsConverted', sql.Int, metrics.prospectsConverted || 0)
            .input('appointmentsCompleted', sql.Int, metrics.appointmentsCompleted || 0)
            .input('policiesSold', sql.Int, metrics.policiesSold || 0)
            .input('remindersCompleted', sql.Int, metrics.remindersCompleted || 0)
            .input('messagesSet', sql.Int, metrics.messagesSet || 0)
            .input('clientInteractions', sql.Int, metrics.clientInteractions || 0)
            .query(`
                MERGE PerformanceMetrics AS target
                USING (VALUES (@agentId, @metricDate, @newClientsAdded, @prospectsConverted, 
                              @appointmentsCompleted, @policiesSold, @remindersCompleted, 
                              @messagesSet, @clientInteractions)) 
                AS source (AgentId, MetricDate, NewClientsAdded, ProspectsConverted,
                          AppointmentsCompleted, PoliciesSold, RemindersCompleted,
                          MessagesSet, ClientInteractions)
                ON target.AgentId = source.AgentId AND target.MetricDate = source.MetricDate
                WHEN MATCHED THEN
                    UPDATE SET NewClientsAdded = source.NewClientsAdded,
                              ProspectsConverted = source.ProspectsConverted,
                              AppointmentsCompleted = source.AppointmentsCompleted,
                              PoliciesSold = source.PoliciesSold,
                              RemindersCompleted = source.RemindersCompleted,
                              MessagesSet = source.MessagesSet,
                              ClientInteractions = source.ClientInteractions
                WHEN NOT MATCHED THEN
                    INSERT (AgentId, MetricDate, NewClientsAdded, ProspectsConverted,
                           AppointmentsCompleted, PoliciesSold, RemindersCompleted,
                           MessagesSet, ClientInteractions)
                    VALUES (source.AgentId, source.MetricDate, source.NewClientsAdded,
                           source.ProspectsConverted, source.AppointmentsCompleted,
                           source.PoliciesSold, source.RemindersCompleted,
                           source.MessagesSet, source.ClientInteractions);
                
                SELECT * FROM PerformanceMetrics WHERE AgentId = @agentId AND MetricDate = @metricDate;
            `);

        return this.mapPerformanceMetrics(result.recordset[0]);
    }

    // Task Summary Methods
    public async createTaskSummary(request: TaskSummaryRequest): Promise<TaskSummary> {
        const pool = await poolPromise;
        
        const result = await pool.request()
            .input('agentId', sql.UniqueIdentifier, request.agentId)
            .input('taskDate', sql.Date, request.taskDate)
            .input('taskType', sql.NVarChar(50), request.taskType)
            .input('taskDescription', sql.NVarChar(500), request.taskDescription)
            .input('priority', sql.NVarChar(10), request.priority || 'Medium')
            .input('clientId', sql.UniqueIdentifier, request.clientId)
            .input('appointmentId', sql.UniqueIdentifier, request.appointmentId)
            .input('dueTime', sql.Time, request.dueTime)
            .query(`
                INSERT INTO TaskSummary (AgentId, TaskDate, TaskType, TaskDescription, Priority, ClientId, AppointmentId, DueTime)
                VALUES (@agentId, @taskDate, @taskType, @taskDescription, @priority, @clientId, @appointmentId, @dueTime);
                SELECT * FROM TaskSummary WHERE TaskId = SCOPE_IDENTITY();
            `);

        return this.mapTaskSummary(result.recordset[0]);
    }

    public async getTasksSummary(agentId: string, taskDate?: Date): Promise<TaskSummary[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('agentId', sql.UniqueIdentifier, agentId)
            .input('taskDate', sql.Date, taskDate)
            .query(`
                SELECT * FROM TaskSummary 
                WHERE AgentId = @agentId 
                ${taskDate ? 'AND TaskDate = @taskDate' : ''}
                ORDER BY TaskDate DESC, DueTime ASC
            `);

        return result.recordset.map(this.mapTaskSummary);
    }

    public async updateTaskStatus(taskId: string, status: string, completedDate?: Date): Promise<boolean> {
        const pool = await poolPromise;
        
        const result = await pool.request()
            .input('taskId', sql.UniqueIdentifier, taskId)
            .input('status', sql.NVarChar(20), status)
            .input('completedDate', sql.DateTime2, completedDate)
            .query(`
                UPDATE TaskSummary 
                SET Status = @status, CompletedDate = @completedDate
                WHERE TaskId = @taskId
            `);

        return result.rowsAffected[0] > 0;
    }

    // Monthly Reports Methods
    public async generateMonthlyReport(request: MonthlyReportRequest): Promise<MonthlyReport> {
        const pool = await poolPromise;
        
        const result = await pool.request()
            .input('agentId', sql.UniqueIdentifier, request.agentId)
            .input('reportMonth', sql.Date, request.reportMonth)
            .execute('sp_GenerateMonthlyReport');

        return this.mapMonthlyReport(result.recordset[0]);
    }

    public async getMonthlyReports(agentId: string, startMonth: Date, endMonth: Date): Promise<MonthlyReport[]> {
        const pool = await poolPromise;
        
        const result = await pool.request()
            .input('agentId', sql.UniqueIdentifier, agentId)
            .input('startMonth', sql.Date, startMonth)
            .input('endMonth', sql.Date, endMonth)
            .query(`
                SELECT * FROM MonthlyReports 
                WHERE AgentId = @agentId 
                AND ReportMonth BETWEEN @startMonth AND @endMonth
                ORDER BY ReportMonth DESC
            `);

        return result.recordset.map(this.mapMonthlyReport);
    }

    // Dashboard Views Cache Methods
    public async getCachedView(agentId: string, viewName: string, cacheDate: Date): Promise<string | null> {
        const pool = await poolPromise;
        
        const result = await pool.request()
            .input('agentId', sql.UniqueIdentifier, agentId)
            .input('viewName', sql.NVarChar(100), viewName)
            .input('cacheDate', sql.Date, cacheDate)
            .query(`
                SELECT CacheData FROM DashboardViewsCache 
                WHERE AgentId = @agentId AND ViewName = @viewName AND CacheDate = @cacheDate
                AND (ExpiresAt IS NULL OR ExpiresAt > GETUTCDATE())
            `);

        return result.recordset.length ? result.recordset[0].CacheData : null;
    }

    public async setCachedView(request: DashboardCacheRequest): Promise<void> {
        const pool = await poolPromise;
        const cacheDate = new Date();
        const expiresAt = request.expirationHours ? 
            new Date(Date.now() + (request.expirationHours * 60 * 60 * 1000)) : null;

        await pool.request()
            .input('agentId', sql.UniqueIdentifier, request.agentId)
            .input('viewName', sql.NVarChar(100), request.viewName)
            .input('cacheDate', sql.Date, cacheDate)
            .input('cacheData', sql.NVarChar(sql.MAX), request.cacheData)
            .input('expiresAt', sql.DateTime2, expiresAt)
            .query(`
                MERGE DashboardViewsCache AS target
                USING (VALUES (@agentId, @viewName, @cacheDate, @cacheData, @expiresAt)) 
                AS source (AgentId, ViewName, CacheDate, CacheData, ExpiresAt)
                ON target.AgentId = source.AgentId AND target.ViewName = source.ViewName AND target.CacheDate = source.CacheDate
                WHEN MATCHED THEN
                    UPDATE SET CacheData = source.CacheData, ExpiresAt = source.ExpiresAt
                WHEN NOT MATCHED THEN
                    INSERT (AgentId, ViewName, CacheDate, CacheData, ExpiresAt)
                    VALUES (source.AgentId, source.ViewName, source.CacheDate, source.CacheData, source.ExpiresAt);
            `);
    }

    public async clearExpiredCache(): Promise<void> {
        const pool = await poolPromise;
        
        await pool.request().query(`
            DELETE FROM DashboardViewsCache 
            WHERE ExpiresAt IS NOT NULL AND ExpiresAt < GETUTCDATE()
        `);
    }

    // Private mapping methods
    private mapActivityLog(row: any): ActivityLog {
        return {
            activityId: row.ActivityId,
            agentId: row.AgentId,
            activityType: row.ActivityType,
            entityType: row.EntityType,
            entityId: row.EntityId,
            description: row.Description,
            activityDate: row.ActivityDate,
            additionalData: row.AdditionalData
        };
    }

    private mapDashboardStatistics(row: any): DashboardStatistics {
        return {
            statId: row.StatId,
            agentId: row.AgentId,
            statDate: row.StatDate,
            totalClients: row.TotalClients,
            totalProspects: row.TotalProspects,
            activePolicies: row.ActivePolicies,
            todayAppointments: row.TodayAppointments,
            weekAppointments: row.WeekAppointments,
            monthAppointments: row.MonthAppointments,
            completedAppointments: row.CompletedAppointments,
            pendingReminders: row.PendingReminders,
            todayBirthdays: row.TodayBirthdays,
            expiringPolicies: row.ExpiringPolicies,
            createdDate: row.CreatedDate,
            updatedDate: row.UpdatedDate
        };
    }

    private mapPerformanceMetrics(row: any): PerformanceMetrics {
        return {
            metricId: row.MetricId,
            agentId: row.AgentId,
            metricDate: row.MetricDate,
            newClientsAdded: row.NewClientsAdded,
            prospectsConverted: row.ProspectsConverted,
            appointmentsCompleted: row.AppointmentsCompleted,
            policiesSold: row.PoliciesSold,
            remindersCompleted: row.RemindersCompleted,
            messagesSet: row.MessagesSet,
            clientInteractions: row.ClientInteractions,
            createdDate: row.CreatedDate
        };
    }

    private mapTaskSummary(row: any): TaskSummary {
        return {
            taskId: row.TaskId,
            agentId: row.AgentId,
            taskDate: row.TaskDate,
            taskType: row.TaskType,
            taskDescription: row.TaskDescription,
            priority: row.Priority,
            status: row.Status,
            clientId: row.ClientId,
            appointmentId: row.AppointmentId,
            dueTime: row.DueTime,
            completedDate: row.CompletedDate,
            createdDate: row.CreatedDate
        };
    }

    private mapMonthlyReport(row: any): MonthlyReport {
        return {
            reportId: row.ReportId,
            agentId: row.AgentId,
            reportMonth: row.ReportMonth,
            totalClientsAdded: row.TotalClientsAdded,
            totalProspectsAdded: row.TotalProspectsAdded,
            prospectsConverted: row.ProspectsConverted,
            totalAppointments: row.TotalAppointments,
            completedAppointments: row.CompletedAppointments,
            cancelledAppointments: row.CancelledAppointments,
            totalReminders: row.TotalReminders,
            completedReminders: row.CompletedReminders,
            messagesSent: row.MessagesSent,
            newPolicies: row.NewPolicies,
            renewedPolicies: row.RenewedPolicies,
            expiredPolicies: row.ExpiredPolicies,
            generatedDate: row.GeneratedDate
        };
    }
}