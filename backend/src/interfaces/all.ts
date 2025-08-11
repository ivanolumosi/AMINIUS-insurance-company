// ============================================
// Core Agent Models
// ============================================

export interface Agent {
  agentId: string;
  firstName: string;
  lastName: string;
  email: string;
  passwordHash: string;
  phone: string;
  avatar?: string;
  createdDate: Date;
  modifiedDate: Date;
  isActive: boolean;
}

export interface AgentSettings {
  settingId: string;
  agentId: string;
  darkMode: boolean;
  emailNotifications: boolean;
  smsNotifications: boolean;
  whatsappNotifications: boolean;
  pushNotifications: boolean;
  soundEnabled: boolean;
  createdDate: Date;
  modifiedDate: Date;
}

export interface AgentProfile {
  agentId: string;
  firstName: string;
  lastName: string;
  email: string;
  phone: string;
  avatar?: string;
  // Settings included
  darkMode: boolean;
  emailNotifications: boolean;
  smsNotifications: boolean;
  whatsappNotifications: boolean;
  pushNotifications: boolean;
  soundEnabled: boolean;
}

// ============================================
// Client Management Models
// ============================================

export interface Client {
  clientId: string;
  agentId: string;
  firstName: string;
  surname: string;
  lastName: string;
  phoneNumber: string;
  email: string;
  address: string;
  nationalId: string;
  dateOfBirth: Date;
  isClient: boolean;
  insuranceType: string;
  notes?: string;
  createdDate: Date;
  modifiedDate: Date;
  isActive: boolean;
  // Computed fields
  age?: number;
  fullName?: string;
  // Policy information (when joined)
  policy?: ClientPolicy;
}

export interface ClientPolicy {
  policyId: string;
  clientId: string;
  policyName: string;
  policyType: string;
  companyName: string;
  status: 'Active' | 'Inactive' | 'Expired' | 'Lapsed';
  startDate: Date;
  endDate: Date;
  notes?: string;
  createdDate: Date;
  modifiedDate: Date;
  isActive: boolean;
  // Computed fields
  daysUntilExpiry?: number;
}

export interface ClientWithPolicy extends Client {
  policies: ClientPolicy[];
}

export interface ClientStatistics {
  totalContacts: number;
  totalClients: number;
  totalProspects: number;
  todayBirthdays: number;
}

// ============================================
// Appointment Management Models
// ============================================

export interface Appointment {
  appointmentId: string;
  clientId: string;
  agentId: string;
  clientName: string;
  clientPhone?: string;
  title: string;
  description?: string;
  appointmentDate: Date;
  startTime: string; // TIME format
  endTime: string;
  location?: string;
  type: 'Call' | 'Meeting' | 'Site Visit' | 'Policy Review' | 'Claim Processing';
  status: 'Scheduled' | 'Confirmed' | 'In Progress' | 'Completed' | 'Cancelled' | 'Rescheduled';
  priority: 'High' | 'Medium' | 'Low';
  notes?: string;
  reminderSet: boolean;
  createdDate: Date;
  modifiedDate: Date;
  isActive: boolean;
  // Computed fields
  timeRange?: string;
  clientEmail?: string;
  insuranceType?: string;
}

export interface AppointmentStatistics {
  todayAppointments: number;
  weekAppointments: number;
  monthAppointments: number;
  completedAppointments: number;
  upcomingAppointments: number;
  cancelledAppointments: number;
}

export interface WeekViewDay {
  date: Date;
  dayName: string;
  isToday: boolean;
  appointments: Appointment[];
}

export interface CalendarDay {
  date: Date;
  isCurrentMonth: boolean;
  isToday: boolean;
  isSelected: boolean;
  appointments: Appointment[];
  appointmentCount: number;
}

// ============================================
// Policy Catalog Models
// ============================================

export interface PolicyCatalog {
  policyCatalogId: string;
  agentId: string;
  policyName: string;
  policyType: string;
  companyId: string;
  companyName: string;
  notes?: string;
  isActive: boolean;
  createdDate: Date;
  modifiedDate: Date;
}

export interface InsuranceCompany {
  companyId: string;
  companyName: string;
  isActive: boolean;
  createdDate: Date;
}

export interface PolicyType {
  typeId: string;
  typeName: string;
  isActive: boolean;
  createdDate: Date;
}

export interface PolicyTemplate {
  templateId: string;
  agentId: string;
  templateName: string;
  policyType: string;
  defaultTermMonths?: number;
  defaultPremium?: number;
  coverageDescription?: string;
  terms?: string;
  isActive: boolean;
  createdDate: Date;
}

export interface PolicyStatistics {
  activePolicies: number;
  expiredPolicies: number;
  lapsedPolicies: number;
  expiringPolicies: number;
  policyTypes: number;
  insuranceCompanies: number;
}

// ============================================
// Reminders and Messaging Models
// ============================================

export interface ReminderSettings {
  reminderSettingId: string;
  agentId: string;
  reminderType: 'Policy Expiry' | 'Birthday' | 'Appointment' | 'Call' | 'Visit';
  isEnabled: boolean;
  daysBefore: number;
  timeOfDay: string; // TIME format
  repeatDaily: boolean;
  createdDate: Date;
  modifiedDate: Date;
}

export interface Reminder {
  reminderId: string;
  clientId?: string;
  appointmentId?: string;
  agentId: string;
  reminderType: 'Call' | 'Visit' | 'Policy Expiry' | 'Birthday' | 'Holiday' | 'Custom';
  title: string;
  description?: string;
  reminderDate: Date;
  reminderTime?: string; // TIME format
  clientName?: string;
  priority: 'High' | 'Medium' | 'Low';
  status: 'Active' | 'Completed' | 'Cancelled';
  enableSMS: boolean;
  enableWhatsApp: boolean;
  enablePushNotification: boolean;
  advanceNotice: string;
  customMessage?: string;
  autoSend: boolean;
  notes?: string;
  createdDate: Date;
  modifiedDate: Date;
  completedDate?: Date;
  // Computed fields from joins
  computedClientName?: string;
  clientPhone?: string;
  appointmentTitle?: string;
}

export interface AutomatedMessage {
  messageId: string;
  agentId: string;
  messageType: 'Birthday' | 'Holiday' | 'Policy Expiry' | 'Appointment' | 'Custom';
  title: string;
  template: string;
  scheduledDate: Date;
  deliveryMethod: 'SMS' | 'WhatsApp' | 'Both';
  status: 'Scheduled' | 'Sent' | 'Failed';
  recipients?: string; // JSON array
  createdDate: Date;
  modifiedDate: Date;
  sentDate?: Date;
  // Computed fields
  recipientCount?: number;
  deliveredCount?: number;
  failedCount?: number;
}

export interface MessageRecipient {
  recipientId: string;
  messageId: string;
  clientId?: string;
  phoneNumber: string;
  deliveryStatus: 'Pending' | 'Sent' | 'Delivered' | 'Failed';
  deliveryDate?: Date;
  errorMessage?: string;
}

export interface MessageTemplate {
  templateId: string;
  agentId: string;
  templateName: string;
  messageType: string;
  template: string;
  isDefault: boolean;
  usageCount: number;
  createdDate: Date;
  modifiedDate: Date;
}

export interface DailyNotes {
  noteId: string;
  agentId: string;
  noteDate: Date;
  notes?: string;
  createdDate: Date;
  modifiedDate: Date;
}

// ============================================
// Dashboard and Analytics Models
// ============================================

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

// ============================================
// Settings Models
// ============================================

export interface NotificationPreferences {
  preferenceId: string;
  agentId: string;
  notificationType: string;
  emailEnabled: boolean;
  smsEnabled: boolean;
  whatsAppEnabled: boolean;
  pushEnabled: boolean;
  soundEnabled: boolean;
  advanceNoticeMinutes: number;
  createdDate: Date;
  modifiedDate: Date;
}

export interface SystemPreferences {
  preferenceId: string;
  agentId: string;
  preferenceKey: string;
  preferenceValue: string;
  createdDate: Date;
  modifiedDate: Date;
}

export interface BackupSettings {
  backupId: string;
  agentId: string;
  backupFrequency: 'Daily' | 'Weekly' | 'Monthly';
  lastBackupDate?: Date;
  backupLocation?: string;
  autoBackupEnabled: boolean;
  includeClientData: boolean;
  includeAppointments: boolean;
  includeReminders: boolean;
  includeSettings: boolean;
  createdDate: Date;
  modifiedDate: Date;
}

// ============================================
// Request/Response DTOs
// ============================================

export interface CreateClientRequest {
  firstName: string;
  surname: string;
  lastName: string;
  phoneNumber: string;
  email: string;
  address: string;
  nationalId: string;
  dateOfBirth: Date;
  isClient: boolean;
  insuranceType: string;
  notes?: string;
}

export interface UpdateClientRequest extends CreateClientRequest {
  clientId: string;
}

export interface CreateAppointmentRequest {
  clientId: string;
  clientName: string;
  clientPhone?: string;
  title: string;
  description?: string;
  appointmentDate: Date;
  startTime: string;
  endTime: string;
  location?: string;
  type: string;
  status?: string;
  priority?: string;
  notes?: string;
  reminderSet?: boolean;
}

export interface UpdateAppointmentRequest extends CreateAppointmentRequest {
  appointmentId: string;
}

export interface CreateReminderRequest {
  clientId?: string;
  appointmentId?: string;
  reminderType: string;
  title: string;
  description?: string;
  reminderDate: Date;
  reminderTime?: string;
  clientName?: string;
  priority?: string;
  enableSMS?: boolean;
  enableWhatsApp?: boolean;
  enablePushNotification?: boolean;
  advanceNotice?: string;
  customMessage?: string;
  autoSend?: boolean;
  notes?: string;
}

export interface UpdateReminderRequest extends CreateReminderRequest {
  reminderId: string;
}

export interface CreateAutomatedMessageRequest {
  messageType: string;
  title: string;
  template: string;
  scheduledDate: Date;
  deliveryMethod: string;
  recipients?: string;
}

export interface CreatePolicyCatalogRequest {
  policyName: string;
  policyType: string;
  companyId: string;
  companyName: string;
  notes?: string;
}

export interface UpdatePolicyCatalogRequest extends CreatePolicyCatalogRequest {
  policyCatalogId: string;
}

export interface CreateClientPolicyRequest {
  clientId: string;
  policyName: string;
  policyType: string;
  companyName: string;
  status: string;
  startDate: Date;
  endDate: Date;
  notes?: string;
}

export interface UpdateClientPolicyRequest extends CreateClientPolicyRequest {
  policyId: string;
}

// ============================================
// Filter and Search DTOs
// ============================================

export interface ClientSearchFilters {
  searchTerm?: string;
  filterType?: 'all' | 'clients' | 'prospects';
  insuranceType?: string;
}

export interface AppointmentSearchFilters {
  dateRangeFilter?: 'all' | 'today' | 'week' | 'month';
  statusFilter?: string;
  typeFilter?: string;
  searchTerm?: string;
  startDate?: Date;
  endDate?: Date;
}

export interface ReminderSearchFilters {
  status?: 'Active' | 'Completed' | 'Cancelled' | 'All';
  reminderType?: string;
  startDate?: Date;
  endDate?: Date;
}

export interface PolicySearchFilters {
  policyType?: string;
  companyName?: string;
}

// ============================================
// API Response Wrappers
// ============================================

export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  message?: string;
  error?: string;
}

export interface PaginatedResponse<T> {
  data: T[];
  totalRecords: number;
  pageNumber: number;
  pageSize: number;
  totalPages: number;
}

// ============================================
// Authentication Models
// ============================================

export interface LoginRequest {
  email: string;
  password: string;
}

export interface LoginResponse {
  success: boolean;
  token?: string;
  agent?: AgentProfile;
  message?: string;
}

export interface RegisterRequest {
  firstName: string;
  lastName: string;
  email: string;
  password: string;
  phone: string;
}

// ============================================
// Export Data Models
// ============================================

export interface ExportOptions {
  includeClients: boolean;
  includeAppointments: boolean;
  includeReminders: boolean;
  includePolicies: boolean;
  includeSettings: boolean;
}

export interface ExportData {
  dataType: string;
  records: any[];
}

// ============================================
// Utility Types
// ============================================

export type EntityStatus = 'Active' | 'Inactive' | 'Expired' | 'Lapsed' | 'Pending' | 'Completed' | 'Cancelled';
export type Priority = 'High' | 'Medium' | 'Low';
export type AppointmentType = 'Call' | 'Meeting' | 'Site Visit' | 'Policy Review' | 'Claim Processing';
export type AppointmentStatus = 'Scheduled' | 'Confirmed' | 'In Progress' | 'Completed' | 'Cancelled' | 'Rescheduled';
export type ReminderType = 'Call' | 'Visit' | 'Policy Expiry' | 'Birthday' | 'Holiday' | 'Custom';
export type MessageType = 'Birthday' | 'Holiday' | 'Policy Expiry' | 'Appointment' | 'Custom';
export type DeliveryMethod = 'SMS' | 'WhatsApp' | 'Both';
export type DeliveryStatus = 'Pending' | 'Sent' | 'Delivered' | 'Failed';