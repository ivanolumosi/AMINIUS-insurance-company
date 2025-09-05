// =============================================
// UPDATED INTERFACES - interfaces/reminders.ts
// Aligned with Frontend Requirements
// =============================================

// Reminder record - Updated to match frontend expectations exactly
export interface Reminder {
    ReminderId: string;
    ClientId?: string;
    AppointmentId?: string;
    AgentId: string;
    ReminderType: 
        'Call' 
        | 'Visit' 
        | 'Policy Expiry' 
        | 'Maturing Policy' 
        | 'Birthday' 
        | 'Holiday' 
        | 'Custom' 
        | 'Appointment';   
    Title: string;
    Description?: string;
    ReminderDate: string; // ISO string for frontend
    ReminderTime?: string; 
    ClientName?: string;
    Priority: 'High' | 'Medium' | 'Low';
    Status: 'Active' | 'Completed' | 'Cancelled';
    EnableSMS: boolean;
    EnableWhatsApp: boolean;
    EnablePushNotification: boolean;
    AdvanceNotice: string;
    CustomMessage?: string;
    AutoSend: boolean;
    Notes?: string;
    CreatedDate: string;
    ModifiedDate: string;
    CompletedDate?: string;
    ClientPhone?: string;
    ClientEmail?: string;
    FullClientName?: string;
}

// Reminder settings - Updated to match frontend types exactly
export interface ReminderSettings {
    ReminderSettingId: string;
    AgentId: string;
    ReminderType: 
        'Policy Expiry' 
        | 'Birthday' 
        | 'Appointment' 
        | 'Call' 
        | 'Visit' 
        | 'Maturing Policy' 
        | 'Holiday' 
        | 'Custom';
    IsEnabled: boolean;
    DaysBefore: number;
    TimeOfDay: string; // SQL TIME format (HH:MM:SS)
    RepeatDaily: boolean;
    CreatedDate: string; // ISO string format
    ModifiedDate: string; // ISO string format
}

// Request to create a reminder - Updated to include all frontend types
export interface CreateReminderRequest {
    ClientId?: string;
    AppointmentId?: string;
    ReminderType: 
        'Call' 
        | 'Visit' 
        | 'Policy Expiry' 
        | 'Maturing Policy' 
        | 'Birthday' 
        | 'Holiday' 
        | 'Custom' 
        | 'Appointment';
    Title: string;
    Description?: string;
    ReminderDate: string; // ISO string format (YYYY-MM-DD)
    ReminderTime?: string; // HH:MM or HH:MM:SS format
    ClientName?: string;
    Priority?: 'High' | 'Medium' | 'Low';
    EnableSMS?: boolean;
    EnableWhatsApp?: boolean;
    EnablePushNotification?: boolean;
    AdvanceNotice?: string;
    CustomMessage?: string;
    AutoSend?: boolean;
    Notes?: string;
}

// Request to update a reminder - Matches frontend exactly
export interface UpdateReminderRequest {
    Title?: string;
    Description?: string;
    ReminderDate?: string; // ISO string format (YYYY-MM-DD)
    ReminderTime?: string; // HH:MM or HH:MM:SS format
    Priority?: 'High' | 'Medium' | 'Low';
    Status?: 'Active' | 'Completed' | 'Cancelled';
    EnableSMS?: boolean;
    EnableWhatsApp?: boolean;
    EnablePushNotification?: boolean;
    AdvanceNotice?: string;
    CustomMessage?: string;
    AutoSend?: boolean;
    Notes?: string;
}

// Filters for listing reminders - Updated to include all frontend types
export interface ReminderFilters {
    ReminderType?: 
        'Call' 
        | 'Visit' 
        | 'Policy Expiry' 
        | 'Maturing Policy' 
        | 'Birthday' 
        | 'Holiday' 
        | 'Custom' 
        | 'Appointment';
    Status?: 'Active' | 'Completed' | 'Cancelled';
    Priority?: 'High' | 'Medium' | 'Low';
    StartDate?: string; // ISO string format
    EndDate?: string; // ISO string format
    ClientId?: string;
    PageSize?: number;
    PageNumber?: number;
}

// Paged reminder response - Matches frontend exactly
export interface PaginatedReminderResponse {
    reminders: Reminder[];
    totalRecords: number;
    currentPage: number;
    totalPages: number;
    pageSize: number;
}

// Birthday reminder view - Matches frontend expectations exactly
export interface BirthdayReminder {
    ClientId: string;
    FirstName: string;
    Surname: string;
    LastName: string;
    PhoneNumber: string;
    Email: string;
    DateOfBirth: string; // ISO string format
    Age: number;
}

// Policy expiry reminder view - Matches frontend expectations exactly
export interface PolicyExpiryReminder {
    PolicyId: string;
    ClientId: string;
    PolicyName: string;
    PolicyType: string;
    CompanyName: string;
    EndDate: string; // ISO string format
    FirstName: string;
    Surname: string;
    PhoneNumber: string;
    Email: string;
    DaysUntilExpiry: number;
}

// Phone validation response - Matches frontend exactly
export interface PhoneValidationResult {
    IsValid: boolean;
    FormattedNumber: string;
    ValidationMessage: string;
}

// Statistics interface - Matches frontend expectations exactly
export interface ReminderStatistics {
    TotalActive: number;
    TotalCompleted: number;
    TodayReminders: number;
    UpcomingReminders: number;
    HighPriority: number;
    Overdue: number;
}