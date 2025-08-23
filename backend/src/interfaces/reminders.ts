export interface Reminder {
  ReminderId: string;
  ClientId?: string;
  AppointmentId?: string;
  AgentId: string;
  ReminderType: 'Call' | 'Visit' | 'Policy Expiry' | 'Birthday' | 'Holiday' | 'Custom';
  Title: string;
  Description?: string;
  ReminderDate: Date;
  ReminderTime?: string; // TIME format from SQL
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
  CreatedDate: Date;
  ModifiedDate: Date;
  CompletedDate?: Date;
}

export interface ReminderSettings {
    ReminderSettingId: string;
    AgentId: string;
    ReminderType: 'Policy Expiry' | 'Birthday' | 'Appointment' | 'Call' | 'Visit';
    IsEnabled: boolean;
    DaysBefore: number;
    TimeOfDay: string; // TIME format
    RepeatDaily: boolean;
    CreatedDate: Date;
    ModifiedDate: Date;
}

export interface CreateReminderRequest {
    ClientId?: string;
    AppointmentId?: string;
    ReminderType: 'Call' | 'Visit' | 'Policy Expiry' | 'Birthday' | 'Holiday' | 'Custom';
    Title: string;
    Description?: string;
    ReminderDate: Date;
    ReminderTime?: string;
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

export interface UpdateReminderRequest {
    Title?: string;
    Description?: string;
    ReminderDate?: Date;
    ReminderTime?: string;
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

export interface ReminderFilters {
    ReminderType?: 'Call' | 'Visit' | 'Policy Expiry' | 'Birthday' | 'Holiday' | 'Custom';
    Status?: 'Active' | 'Completed' | 'Cancelled';
    Priority?: 'High' | 'Medium' | 'Low';
    StartDate?: Date;
    EndDate?: Date;
    ClientId?: string;
    PageSize?: number;
    PageNumber?: number;
}

export interface PaginatedReminderResponse {
    reminders: Reminder[];
    totalRecords: number;
    currentPage: number;
    totalPages: number;
    pageSize: number;
}

export interface BirthdayReminder {
    ClientId: string;
    FirstName: string;
    Surname: string;
    LastName: string;
    PhoneNumber: string;
    Email: string;
    DateOfBirth: Date;
    Age: number;
}

export interface PolicyExpiryReminder {
    PolicyId: string;
    ClientId: string;
    PolicyName: string;
    PolicyType: string;
    CompanyName: string;
    EndDate: Date;
    FirstName: string;
    Surname: string;
    PhoneNumber: string;
    Email: string;
    DaysUntilExpiry: number;
}

export interface PhoneValidationResult {
    IsValid: boolean;
    FormattedNumber: string;
    ValidationMessage: string;
}