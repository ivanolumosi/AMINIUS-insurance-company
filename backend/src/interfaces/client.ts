// interfaces/Client.ts
export interface Client {
    ClientId: string;
    AgentId: string;
    FirstName: string;
    Surname: string;
    LastName: string;
    PhoneNumber: string;
    Email: string;
    Address: string;
    NationalId: string;
    DateOfBirth: Date;
    IsClient: boolean;
    InsuranceType: string;
    Notes?: string;
    CreatedDate: Date;
    ModifiedDate: Date;
    IsActive: boolean;
    Age?: number;
    PolicyCount?: number;
    NextExpiryDate?: Date;
}

export interface ClientPolicy {
    PolicyId: string;
    ClientId: string;
    PolicyName: string;
    PolicyType: string;
    CompanyName: string;
    Status: 'Active' | 'Inactive' | 'Expired' | 'Lapsed';
    StartDate: Date;
    EndDate: Date;
    DaysToExpiry?: number;
    Notes?: string;
    CreatedDate: Date;
    ModifiedDate: Date;
    IsActive: boolean;
}

export interface ClientWithPolicy extends Client {
    PolicyId?: string;
    PolicyName?: string;
    PolicyType?: string;
    PolicyCompany?: string;
    PolicyStatus?: string;
    PolicyStartDate?: Date;
    PolicyEndDate?: Date;
    PolicyNotes?: string;
}

export interface ClientWithDetails extends Client {
    policies?: ClientPolicy[];
    recentAppointments?: Appointment[];
    activeReminders?: Reminder[];
}

export interface Appointment {
    AppointmentId: string;
    Title: string;
    AppointmentDate: Date;
    StartTime: string;
    EndTime?: string;
    Type: string;
    Status: string;
    Location?: string;
}

export interface Reminder {
    ReminderId: string;
    Title: string;
    ReminderDate: Date;
    ReminderTime?: string;
    ReminderType: string;
    Priority: string;
    Status: string;
}

export interface CreateClientRequest {
    AgentId: string;
    FirstName: string;
    Surname: string;
    LastName: string;
    PhoneNumber: string;
    Email: string;
    Address: string;
    NationalId: string;
    DateOfBirth: Date;
    IsClient?: boolean;
    InsuranceType: string;
    Notes?: string;
}

export interface UpdateClientRequest extends CreateClientRequest {
    ClientId: string;
}

export interface ClientSearchFilters {
    SearchTerm?: string;
    InsuranceType?: string;
    FilterType?: 'all' | 'clients' | 'prospects';
    IsClient?: boolean;
    PageNumber?: number;
    PageSize?: number;
}

export interface ClientStatistics {
    TotalContacts: number;
    TotalClients: number;
    TotalProspects: number;
    TodayBirthdays: number;
    ActivePolicies?: number;
    ExpiringPolicies?: number;
    MonthBirthdays?: number;
    NewThisWeek?: number;
    NewThisMonth?: number;
    InsuranceTypeBreakdown?: string;
}

export interface ClientResponse {
    Success: boolean;
    Message: string;
    ClientId?: string;
}

export interface Birthday extends Client {
    Age: number;
}

export interface ApiResponse<T> {
    Success: boolean;
    Message: string;
    Data?: T;
}