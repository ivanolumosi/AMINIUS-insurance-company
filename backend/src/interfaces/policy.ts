// interfaces/Policy.ts

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
    companyActive?: boolean;
}

export interface ClientPolicy {
    policyId: string;
    clientId: string;
    policyName: string;
    policyType: string;
    companyName: string;
    status: string;
    startDate: Date;
    endDate: Date;
    notes?: string;
    createdDate: Date;
    modifiedDate: Date;
    isActive: boolean;
    daysUntilExpiry?: number;
    clientName?: string;
    clientPhone?: string;
    clientEmail?: string;
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

export interface PolicyCategory {
    categoryId: string;
    categoryName: string;
    description?: string;
    isActive: boolean;
    createdDate: Date;
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

export interface PolicyStatistics {
    totalPolicies: number;
    activePolicies: number;
    expiredPolicies: number;
    lapsedPolicies: number;
    inactivePolicies: number;
    expiringIn30Days: number;
    expiringIn7Days: number;
    newPoliciesThisMonth: number;
    motorPolicies: number;
    lifePolicies: number;
    healthPolicies: number;
    travelPolicies: number;
    propertyPolicies: number;
    marinePolicies: number;
    businessPolicies: number;
    catalogPolicies: number;
}

export interface PolicyCompanyRelationship {
    relationshipId: string;
    policyCatalogId: string;
    companyId: string;
    basePremium?: number;
    commissionRate?: number;
    isPreferred: boolean;
    createdDate: Date;
}

// Request/Response DTOs
export interface CreatePolicyCatalogRequest {
    agentId: string;
    policyName: string;
    policyType: string;
    companyId: string;
    notes?: string;
}

export interface UpdatePolicyCatalogRequest {
    policyCatalogId: string;
    agentId: string;
    policyName?: string;
    policyType?: string;
    companyId?: string;
    notes?: string;
    isActive?: boolean;
}

export interface PolicyCatalogFilterRequest {
    agentId: string;
    policyType?: string;
    companyId?: string;
    companyName?: string;
    searchTerm?: string;
    isActive?: boolean;
}

export interface CreateClientPolicyRequest {
    clientId: string;
    policyName: string;
    policyType: string;
    companyName: string;
    status?: string;
    startDate: Date;
    endDate: Date;
    notes?: string;
}

export interface UpdateClientPolicyRequest {
    policyId: string;
    policyName?: string;
    policyType?: string;
    companyName?: string;
    status?: string;
    startDate?: Date;
    endDate?: Date;
    notes?: string;
    isActive?: boolean;
}

export interface ClientPolicyFilterRequest {
    clientId: string;
    status?: string;
    policyType?: string;
}

export interface ExpiringPoliciesRequest {
    agentId: string;
    daysAhead?: number;
}

export interface CreatePolicyTemplateRequest {
    agentId: string;
    templateName: string;
    policyType: string;
    defaultTermMonths?: number;
    defaultPremium?: number;
    coverageDescription?: string;
    terms?: string;
}

export interface PolicyTemplateFilterRequest {
    agentId: string;
    policyType?: string;
    isActive?: boolean;
}

export interface UpsertPolicyCatalogRequest {
    policyCatalogId?: string;
    agentId: string;
    policyName: string;
    policyType: string;
    companyId: string;
    companyName: string;
    notes?: string;
}

export interface UpsertClientPolicyRequest {
    policyId?: string;
    clientId: string;
    policyName: string;
    policyType: string;
    companyName: string;
    status: string;
    startDate: Date;
    endDate: Date;
    notes?: string;
}

export interface PolicyValidationRequest {
    policyName: string;
    policyType: string;
    companyId?: string;
    startDate?: Date;
    endDate?: Date;
}

export interface PolicyValidationResponse {
    isValid: boolean;
    validationErrors: string;
}