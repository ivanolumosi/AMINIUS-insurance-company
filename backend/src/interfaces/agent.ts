// interfaces/Agent.ts
export interface Agent {
    AgentId: string;
    FirstName: string;
    LastName: string;
    Email: string;
    Phone: string;
    PasswordHash?: string;
    Avatar?: string;
    CreatedDate: Date;
    ModifiedDate: Date;
    IsActive: boolean;
}

export interface AgentSettings {
    SettingId: string;
    AgentId: string;
    DarkMode: boolean;
    EmailNotifications: boolean;
    SmsNotifications: boolean;
    WhatsappNotifications: boolean;
    PushNotifications: boolean;
    SoundEnabled: boolean;
    CreatedDate: Date;
    ModifiedDate: Date;
}

export interface AgentProfile extends Agent {
    DarkMode?: boolean;
    EmailNotifications?: boolean;
    SmsNotifications?: boolean;
    WhatsappNotifications?: boolean;
    PushNotifications?: boolean;
    SoundEnabled?: boolean;
}

export interface LoginRequest {
    Email: string;
    Password: string;
}

export interface LoginResponse {
    Success: boolean;
    Message: string;
    AgentId?: string;
    Token?: string;
    AgentProfile?:  AgentProfile;
    StoredPasswordHash?: string;
}

export interface RegisterRequest {
    FirstName: string;
    LastName: string;
    Email: string;
    Phone: string;
    PasswordHash: string;
    Avatar?: string;
}

export interface RegisterResponse {
    Success: boolean;
    Message: string;
    AgentId?: string;
}

export interface ChangePasswordRequest {
    AgentId: string;
    OldPasswordHash: string;
    NewPasswordHash: string;
}

export interface PasswordResponse {
    Success: boolean;
    Message: string;
}

export interface PasswordResetRequest {
    Email: string;
}

export interface PasswordResetResponse {
    Success: boolean;
    Message: string;
    AgentId?: string;
    Email?: string;
}

export interface InsuranceCompany {
    CompanyId: string;
    CompanyName: string;
}

export interface PolicyType {
    TypeId: string;
    TypeName: string;
}

export interface ApiResponse<T> {
    Success: boolean;
    Message: string;
    Data?: T;
}