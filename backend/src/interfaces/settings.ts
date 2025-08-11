
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
