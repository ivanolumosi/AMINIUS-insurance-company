// interfaces/Analytics.ts

export interface ActivityLog {
    activityId: string;
    agentId: string;
    activityType: string;
    entityType?: string;
    entityId?: string;
    description?: string;
    activityDate: Date;
    additionalData?: string;
}

export interface DashboardStatistics {
    statId: string;
    agentId: string;
    statDate: Date;
    totalClients: number;
    totalProspects: number;
    activePolicies: number;
    todayAppointments: number;
    weekAppointments: number;
    monthAppointments: number;
    completedAppointments: number;
    pendingReminders: number;
    todayBirthdays: number;
    expiringPolicies: number;
    createdDate: Date;
    updatedDate: Date;
}

export interface PerformanceMetrics {
    metricId: string;
    agentId: string;
    metricDate: Date;
    newClientsAdded: number;
    prospectsConverted: number;
    appointmentsCompleted: number;
    policiesSold: number;
    remindersCompleted: number;
    messagesSet: number;
    clientInteractions: number;
    createdDate: Date;
}

export interface TaskSummary {
    taskId: string;
    agentId: string;
    taskDate: Date;
    taskType: string;
    taskDescription?: string;
    priority: 'High' | 'Medium' | 'Low';
    status: 'Pending' | 'In Progress' | 'Completed' | 'Cancelled';
    clientId?: string;
    appointmentId?: string;
    dueTime?: string;
    completedDate?: Date;
    createdDate: Date;
}

export interface MonthlyReport {
    reportId: string;
    agentId: string;
    reportMonth: Date;
    totalClientsAdded: number;
    totalProspectsAdded: number;
    prospectsConverted: number;
    totalAppointments: number;
    completedAppointments: number;
    cancelledAppointments: number;
    totalReminders: number;
    completedReminders: number;
    messagesSent: number;
    newPolicies: number;
    renewedPolicies: number;
    expiredPolicies: number;
    generatedDate: Date;
}

export interface DashboardViewsCache {
    cacheId: string;
    agentId: string;
    viewName: string;
    cacheDate: Date;
    cacheData?: string;
    expiresAt?: Date;
    createdDate: Date;
}

// Request/Response DTOs
export interface CreateActivityLogRequest {
    agentId: string;
    activityType: string;
    entityType?: string;
    entityId?: string;
    description?: string;
    additionalData?: string;
}

export interface DashboardStatsRequest {
    agentId: string;
    statDate?: Date;
}

export interface PerformanceMetricsRequest {
    agentId: string;
    startDate: Date;
    endDate: Date;
}

export interface TaskSummaryRequest {
    agentId: string;
    taskDate: Date;
    taskType: string;
    taskDescription?: string;
    priority?: 'High' | 'Medium' | 'Low';
    clientId?: string;
    appointmentId?: string;
    dueTime?: string;
}

export interface MonthlyReportRequest {
    agentId: string;
    reportMonth: Date;
}

export interface DashboardCacheRequest {
    agentId: string;
    viewName: string;
    cacheData: string;
    expirationHours?: number;
}