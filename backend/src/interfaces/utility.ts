// interfaces/Utility.ts
export interface GreetingResult {
    Greeting: string;
}

export interface ParsedTemplateResult {
    ParsedTemplate: string;
}

export interface RandomPasswordResult {
    RandomPassword: string;
}

export interface TemplateData {
    ClientName?: string;
    AgentName?: string;
    PolicyType?: string;
    ExpiryDate?: string;
    CompanyName?: string;
}

// interfaces/Notifications.ts
export interface NotificationResult {
    NotificationId: string;
    Success: boolean;
}

export interface Notification {
    NotificationId: string;
    NotificationType: 'Email' | 'SMS' | 'WhatsApp' | 'Push';
    Recipient: string;
    Subject?: string;
    Body: string;
    Status: 'Pending' | 'Sent' | 'Failed' | 'Cancelled';
    ScheduledTime?: string;
    SentTime?: string;
    ErrorMessage?: string;
    RetryCount: number;
    CreatedDate: string;
}

export interface ScheduledNotification {
    NotificationId: string;
    AgentId: string;
    NotificationType: string;
    Recipient: string;
    Subject?: string;
    Body: string;
    ScheduledTime: string;
}

export interface NotificationHistoryRequest {
    StartDate?: string;
    EndDate?: string;
    NotificationType?: 'Email' | 'SMS' | 'WhatsApp' | 'Push';
    Status?: 'Pending' | 'Sent' | 'Failed' | 'Cancelled';
    PageSize?: number;
    PageNumber?: number;
}

export interface NotificationHistoryResult {
    notifications: Notification[];
    totalRecords: number;
}

export interface UpdateNotificationStatusResult {
    RowsAffected: number;
}

export interface CancelNotificationResult {
    RowsAffected: number;
}// interfaces/Utility.ts
export interface GreetingResult {
    Greeting: string;
}

export interface ParsedTemplateResult {
    ParsedTemplate: string;
}

export interface RandomPasswordResult {
    RandomPassword: string;
}

export interface TemplateData {
    ClientName?: string;
    AgentName?: string;
    PolicyType?: string;
    ExpiryDate?: string;
    CompanyName?: string;
}// interfaces/Validation.ts
export interface ValidationResult {
    IsValid: boolean;
    ValidationMessage: string;
}

export interface NationalIdValidationResult extends ValidationResult {
    FormattedNationalId: string;
}

export interface DataIntegrityIssue {
    IssueType: string;
    IssueCount: number;
    Description: string;
}

export interface PhoneNumberFormatResult {
    FormattedPhoneNumber: string;
}