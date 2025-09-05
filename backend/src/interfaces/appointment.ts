export interface Appointment {
  appointmentId: string;
  clientId: string;
  agentId: string;
  clientName: string;
  clientPhone?: string;
  title: string;
  description?: string;
  appointmentDate: string | Date;
  startTime: string;
  endTime: string;
  location?: string;
  type: 'Call' | 'Meeting' | 'Site Visit' | 'Policy Review' | 'Claim Processing';
  status: 'Scheduled' | 'Confirmed' | 'In Progress' | 'Completed' | 'Cancelled' | 'Rescheduled';
  priority: 'High' | 'Medium' | 'Low';
  notes?: string;
  reminderSet: boolean;
  createdDate: string;
  modifiedDate?: string | Date;
  isActive: boolean;
  clientEmail?: string;
  clientAddress?: string;
  formattedTime?: string;
}

export interface CreateAppointmentRequest {
  clientId: string;
  title: string;
  description?: string;
  appointmentDate: string;
  startTime: string;
  endTime: string;
  location?: string;
  type: 'Call' | 'Meeting' | 'Site Visit' | 'Policy Review' | 'Claim Processing';
  status: 'Scheduled' | 'Confirmed' | 'In Progress' | 'Completed' | 'Cancelled' | 'Rescheduled';
  priority?: 'High' | 'Medium' | 'Low';
  notes?: string;
  reminderSet?: boolean;
}

export interface UpdateAppointmentRequest {
  clientId?: string;
  title?: string;
  description?: string;
  appointmentDate?: string;
  startTime?: string;
  endTime?: string;
  location?: string;
  type?: 'Call' | 'Meeting' | 'Site Visit' | 'Policy Review' | 'Claim Processing';
  status?: 'Scheduled' | 'Confirmed' | 'In Progress' | 'Completed' | 'Cancelled' | 'Rescheduled';
  priority?: 'High' | 'Medium' | 'Low';
  notes?: string;
  reminderSet?: boolean;
}

export interface AppointmentFilters {
  pageSize?: number;
  pageNumber?: number;
  status?: string;
  type?: string;
  priority?: string;
  startDate?: string;
  endDate?: string;
  clientId?: string;
  searchTerm?: string;
}

export interface AppointmentStatistics {
  todayCount: number;
  weekCount: number;
  monthCount: number;
  completedCount: number;
  totalAppointments: number;
  todayAppointments: number;
  weekAppointments: number;
  monthAppointments: number;
  completedAppointments: number;
  pendingAppointments: number;
  statusBreakdown: { [key: string]: number };
  typeBreakdown: { [key: string]: number };
  scheduledCount: number;
  confirmedCount: number;
  cancelledCount: number;
}

export interface WeekViewData {
  date: string;
  dayName: string;
  appointments: Appointment[];
}

export interface CalendarViewData {
  date: string;
  appointmentCount: number;
  appointments: Appointment[];
}

export interface ConflictCheckRequest {
  appointmentDate: string;
  startTime: string;
  endTime: string;
  excludeAppointmentId?: string;
}

export interface ConflictCheckResponse {
  conflicts: any;
  hasConflicts: boolean;
  conflictingAppointments?: Appointment[];
  message?: string;
}

export interface ClientSearchResult {
  clientId: string;
  clientName: string;
  phone?: string;
  email?: string;
  address?: string;
  policyNumber?: string;
  status?: string;
}

export interface AppointmentResponse {
  Success: boolean;
  Message: string;
  AppointmentId?: string;
  Appointment?: Appointment;
}
