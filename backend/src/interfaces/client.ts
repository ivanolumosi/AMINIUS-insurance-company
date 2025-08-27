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
  dateOfBirth: string; // ISO string
  isClient: boolean;
  insuranceType: string;
  notes?: string;
  createdDate: string;
  modifiedDate: string;
  isActive: boolean;
  age?: number;
  policyCount?: number;
  nextExpiryDate?: string;
}

export interface ClientPolicy {
  policyId: string;
  clientId: string;
  policyName: string;
  policyType: string;
  companyName: string;
  status: 'Active' | 'Inactive' | 'Expired' | 'Lapsed';
  startDate: string;
  endDate: string;
  daysToExpiry?: number;
  notes?: string;
  createdDate: string;
  modifiedDate: string;
  isActive: boolean;
}

export interface ClientWithPolicy extends Client {
  policyId?: string;
  policyName?: string;
  policyType?: string;
  policyCompany?: string;
  policyStatus?: string;
  policyStartDate?: string;
  policyEndDate?: string;
  policyNotes?: string;
}

export interface ClientWithDetails extends Client {
  policies?: ClientPolicy[];
  recentAppointments?: Appointment[];
  activeReminders?: Reminder[];
}

export interface Appointment {
  appointmentId: string;
  title: string;
  appointmentDate: string;
  startTime: string;
  endTime?: string;
  type: string;
  status: string;
  location?: string;
}

export interface Reminder {
  reminderId: string;
  title: string;
  reminderDate: string;
  reminderTime?: string;
  reminderType: string;
  priority: string;
  status: string;
}

export interface CreateClientRequest {
  agentId: string;
  firstName: string;
  surname: string;
  lastName: string;
  phoneNumber: string;
  email: string;
  address: string;
  nationalId: string;
  dateOfBirth: string; // ISO string
  isClient?: boolean;
  insuranceType: string;
  notes?: string;
}

export interface UpdateClientRequest extends CreateClientRequest {
  clientId: string;
}

export interface ClientSearchFilters {
  searchTerm?: string;
  insuranceType?: string;
  filterType?: 'all' | 'clients' | 'prospects';
  isClient?: boolean;
  pageNumber?: number;
  pageSize?: number;
}

export interface ClientStatistics {
  totalContacts: number;
  totalClients: number;
  totalProspects: number;
  todayBirthdays: number;
  activePolicies?: number;
  expiringPolicies?: number;
  monthBirthdays?: number;
  newThisWeek?: number;
  newThisMonth?: number;
  insuranceTypeBreakdown?: string;
}

export interface ClientResponse {
  success: boolean;
  message: string;
  clientId?: string;
}

export interface Birthday extends Client {
  age: number;
}

export interface ApiResponse<T> {
  success: boolean;
  message: string;
  data?: T;
}
