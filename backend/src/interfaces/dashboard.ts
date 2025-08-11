
export interface DashboardOverview {
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
}

export interface DashboardActivity {
  activityType: 'appointment' | 'reminder' | 'birthday';
  entityId: string;
  clientName: string;
  title: string;
  timeRange: string;
  location?: string;
  type: string;
  status: string;
  notes?: string;
  priority: string;
  clientPhone?: string;
}

export interface ActivityLog {
  activityId: string;
  agentId: string;
  activityType: string;
  entityType?: string;
  entityId?: string;
  description: string;
  activityDate: Date;
  additionalData?: string; // JSON
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