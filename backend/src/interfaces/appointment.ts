export interface Appointment {
    appointmentId: string;
    clientId: string;
    agentId: string;
    clientName: string;
    clientPhone?: string;
    title: string;
    description?: string;
    appointmentDate: Date;
    startTime: string; // TIME format as string
    endTime: string; // TIME format as string
    location?: string;
    type: 'Call' | 'Meeting' | 'Site Visit' | 'Policy Review' | 'Claim Processing';
    status: 'Scheduled' | 'Confirmed' | 'In Progress' | 'Completed' | 'Cancelled' | 'Rescheduled';
    priority: 'High' | 'Medium' | 'Low';
    notes?: string;
    reminderSet: boolean;
    createdDate: Date;
    modifiedDate: Date;
    isActive: boolean;
    clientEmail?: string;
    clientAddress?: string;
}

export interface CreateAppointmentRequest {
    clientId: string;
    title: string;
    description?: string;
    appointmentDate: Date;
    startTime: string;
    endTime: string;
    location?: string;
    type: 'Call' | 'Meeting' | 'Site Visit' | 'Policy Review' | 'Claim Processing';
    status?: 'Scheduled' | 'Confirmed' | 'In Progress' | 'Completed' | 'Cancelled' | 'Rescheduled'; // ✅ optional

    priority?: 'High' | 'Medium' | 'Low';
    notes?: string;
    reminderSet?: boolean;
}

export interface UpdateAppointmentRequest {
    title?: string;
    description?: string;
    appointmentDate?: Date;
    startTime?: string;
    endTime?: string;
    location?: string;
    type?: 'Call' | 'Meeting' | 'Site Visit' | 'Policy Review' | 'Claim Processing';
   status?: 'Scheduled' | 'Confirmed' | 'In Progress' | 'Completed' | 'Cancelled' | 'Rescheduled'; // ✅ optional

    priority?: 'High' | 'Medium' | 'Low';
    notes?: string;
    reminderSet?: boolean;
}

export interface AppointmentFilters {
    dateRangeFilter?: 'all' | 'today' | 'week' | 'month';
    statusFilter?: 'all' | string;
    typeFilter?: 'all' | string;
    searchTerm?: string;
    startDate?: Date;
    endDate?: Date;
    clientId?: string;
    priority?: 'High' | 'Medium' | 'Low';
    pageSize?: number;
    pageNumber?: number;
}

export interface AppointmentStatistics {
    todayAppointments: number;
    weekAppointments: number;
    monthAppointments: number;
    completedAppointments: number;
    upcomingAppointments: number;
    cancelledAppointments: number;
}

export interface TimeConflictCheck {
    hasConflict: boolean;
    conflictCount: number;
}

export interface WeekViewAppointment {
    appointmentId: string;
    clientId: string;
    clientName: string;
    title: string;
    appointmentDate: Date;
    startTime: string;
    endTime: string;
    location?: string;
    type: string;
    status: string;
    priority: string;
    dayName: string;
    dayNumber: number;
}

export interface CalendarAppointment {
    appointmentId: string;
    clientId: string;
    clientName: string;
    title: string;
    appointmentDate: Date;
    startTime: string;
    type: string;
    status: string;
    priority: string;
    dayNumber: number;
    appointmentsOnDay: number;
}