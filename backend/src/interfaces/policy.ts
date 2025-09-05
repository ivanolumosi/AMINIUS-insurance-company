// Base Entity Interfaces
export interface PolicyCatalog {
    policyId: string;
    agentId: string;
    policyName: string;
    companyId: string;
    companyName?: string;
    notes?: string;
    isActive: boolean;
    createdDate: Date;
    modifiedDate?: Date;
    categoryId?: string;
    categoryName?: string;
    typeId?: string;
    typeName?: string;
}

export interface ClientPolicy {
    policyId: string;
    clientId: string;
    policyName: string;
    status: string;
    startDate: Date;
    endDate: Date;
    notes?: string;
    createdDate: Date;
    modifiedDate?: Date;
    isActive: boolean;
    policyCatalogId?: string;
    catalogPolicyName?: string;
    typeId?: string;
    typeName?: string;
    companyId?: string;
    companyName?: string;
    daysUntilExpiry?: number;
}

export interface PolicyTemplate {
    templateId: string;
    agentId: string;
    templateName: string;
    defaultTermMonths?: number;
    defaultPremium?: number;
    coverageDescription?: string;
    terms?: string;
    isActive: boolean;
    createdDate: Date;
    categoryId?: string;
    categoryName?: string;
    policyCatalogId?: string;
    catalogPolicyName?: string;
    typeId?: string;
    typeName?: string;
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

// Statistics and Analytics Interfaces
export interface PolicyStatistics {
    totalPolicies: number;
    activePolicies: number;
    expiredPolicies: number;
    cancelledPolicies: number;
    expiringIn30Days: number;
    expiringIn60Days: number;
}

export interface PolicyStatisticsDetailed {
    groupType: string;
    groupName: string;
    policyCount: number;
    activeCount: number;
}

export interface AgentDashboardSummary {
    totalPolicies: number;
    activePolicies: number;
    expiringIn30Days: number;
    expiringIn60Days: number;
    totalCompanies: number;
    totalClients: number;
    inactivePolicies: number;
}

export interface PolicyRenewalCandidate {
    policyId: string;
    clientId: string;
    policyName: string;
    status: string;
    startDate: Date;
    endDate: Date;
    companyId: string;
    companyName: string;
    typeId?: string;
    typeName?: string;
    daysUntilExpiry: number;
    renewalPriority: 'Urgent' | 'Soon' | 'Upcoming';
}

export interface PolicyHistory {
    policyId: string;
    clientId: string;
    policyName: string;
    status: string;
    startDate: Date;
    endDate: Date;
    notes?: string;
    createdDate: Date;
    modifiedDate?: Date;
    companyId?: string;
    companyName?: string;
    typeId?: string;
    typeName?: string;
    policyDurationDays: number;
    policyState: 'Current' | 'Expired' | string;
}

// Request Interfaces for Policy Catalog
export interface PolicyCatalogFilterRequest {
    agentId?: string;
    companyId?: string;
    categoryId?: string;
    typeId?: string;
    companyName?: string;   // ✅ Added
    searchTerm?: string;    // ✅ Added
    isActive?: boolean;
}

export interface CreatePolicyCatalogRequest {
    agentId: string;
    policyName: string;
    companyId: string;
    notes?: string;
    categoryId?: string;
    typeId?: string;
    isActive?: boolean;     
}

export interface UpdatePolicyCatalogRequest {
    policyCatalogId: string;
    policyName?: string;
    companyId?: string;
    notes?: string;
    categoryId?: string;
    typeId?: string;
    isActive?: boolean;
    agentId?: string;     
}

export interface UpsertPolicyCatalogRequest {
    policyCatalogId?: string;
    agentId: string;
    policyName: string;
    companyId: string;
    notes?: string;
    categoryId?: string;
    typeId?: string;
    isActive?: boolean;     
}

export interface DeletePolicyCatalogRequest {
    policyCatalogId: string;
    agentId: string;
}


// Request Interfaces for Client Policies
export interface ClientPolicyFilterRequest {
    clientId?: string;
    agentId?: string;
    status?: string;
    isActive?: boolean;
}

export interface CreateClientPolicyRequest {
    clientId: string;
    policyName: string;
    status?: string;
    startDate: Date;
    endDate: Date;
    notes?: string;
    policyCatalogId?: string;
    typeId?: string;
    companyId?: string;
}

export interface UpdateClientPolicyRequest {
    policyId: string;
    policyName?: string;
    status?: string;
    startDate?: Date;
    endDate?: Date;
    notes?: string;
    policyCatalogId?: string;
    typeId?: string;
    companyId?: string;
    isActive?: boolean;
}

export interface UpsertClientPolicyRequest {
    policyId?: string;
    clientId: string;
    policyName: string;
    status?: string;
    startDate: Date;
    endDate: Date;
    notes?: string;
    policyCatalogId?: string;
    typeId?: string;
    companyId?: string;
}

export interface ExpiringPoliciesRequest {
    agentId?: string;
    daysAhead?: number;
    status?: string;
}

export interface PolicyRenewalRequest {
    policyId: string;
    newStartDate: Date;
    newEndDate: Date;
    newPolicyName?: string;
    notes?: string;
}

export interface BulkUpdatePolicyStatusRequest {
    policyIds: string[];
    newStatus: string;
}

// Request Interfaces for Policy Templates
export interface PolicyTemplateFilterRequest {
    agentId?: string;
    categoryId?: string;
    typeId?: string;
    isActive?: boolean;
}

export interface CreatePolicyTemplateRequest {
    agentId: string;
    templateName: string;
    defaultTermMonths?: number;
    defaultPremium?: number;
    coverageDescription?: string;
    terms?: string;
    categoryId?: string;
    policyCatalogId?: string;
    typeId?: string;
}

export interface UpdatePolicyTemplateRequest {
    templateId: string;
    templateName?: string;
    defaultTermMonths?: number;
    defaultPremium?: number;
    coverageDescription?: string;
    terms?: string;
    categoryId?: string;
    policyCatalogId?: string;
    typeId?: string;
    isActive?: boolean;
}

// Request Interfaces for Search and Filtering
export interface SearchPoliciesRequest {
    searchTerm?: string;
    agentId?: string;
    clientId?: string;
    companyId?: string;
    typeId?: string;
    status?: string;
    startDate?: Date;
    endDate?: Date;
    pageSize?: number;
    pageNumber?: number;
}

export interface GetPoliciesByStatusRequest {
    status: string;
    agentId?: string;
}

export interface PolicyStatisticsRequest {
    agentId?: string;
    startDate?: Date;
    endDate?: Date;
}

// Request Interfaces for Reference Data
export interface CreatePolicyCategoryRequest {
    categoryName: string;
    description?: string;
}

export interface UpdatePolicyCategoryRequest {
    categoryId: string;
    categoryName?: string;
    description?: string;
    isActive?: boolean;
}

export interface CreateInsuranceCompanyRequest {
    companyName: string;
}

export interface UpdateInsuranceCompanyRequest {
    companyId: string; // Made required to match service usage
    companyName?: string;
    isActive?: boolean;
}

export interface CreatePolicyTypeRequest {
    typeName: string;
}

export interface UpdatePolicyTypeRequest {
    typeId: string; // Made required to match service usage
    typeName?: string;
    isActive?: boolean;
}

// Utility Request Interfaces
export interface GetPolicyHistoryRequest {
    clientId: string;
    includeInactive?: boolean;
}

export interface GetRenewalCandidatesRequest {
    agentId?: string;
    daysAhead?: number;
}

export interface BatchExpirePoliciesRequest {
    asOfDate?: Date;
}

export interface CleanupSoftDeletedRequest {
    daysOld?: number;
    dryRun?: boolean;
}

export interface DeleteRequest {
    hardDelete?: boolean;
}

// Response Interfaces
export interface PolicyResponse<T> {
    success: boolean;
    data?: T;
    message?: string;
    rowsAffected?: number;
}

export interface PaginatedResponse<T> {
    data: T[];
    total: number;
    pageNumber: number;
    pageSize: number;
    hasNextPage: boolean;
    hasPreviousPage: boolean;
}

export interface CreateResponse {
    id: string;
}

export interface UpdateResponse {
    rowsAffected: number;
}

export interface DeleteResponse {
    rowsAffected: number;
}

export interface RenewalResponse {
    newPolicyId: string;
    rowsAffected: number;
}

export interface CleanupResponse {
    tableName?: string;
    recordsToDelete?: number;
    totalRecordsDeleted?: number;
}

// Validation interfaces
export interface PolicyValidationRequest {
    policyData: any;
}

export interface PolicyValidationResponse {
    isValid: boolean;
    errors: string[];
    warnings?: string[];
}

// Soft delete response interface
export interface SoftDeleteResponse {
    success: number;
    message: string;
}

// Database validation response interface
export interface DatabaseValidationResponse {
    isValid: boolean;
    validationErrors: string;
}

// Legacy interfaces for backward compatibility
export interface PolicyCompanyRelationship {
    policyId: string;
    companyId: string;
    companyName?: string;
}

// interfaces/policy.ts (or inside your service file if kept together)

export interface ClientPolicyLite {
  policyId: string;
  policyName: string;
  status: string;
  startDate: Date;
  endDate: Date;
  notes?: string;
  createdDate: Date;
  modifiedDate: Date;
  isActive: boolean;
  policyCatalogId: string;
  catalogPolicyName: string;
  typeId: string;
  typeName: string;
  companyId: string;
  companyName: string;
  daysUntilExpiry: number;
}

export interface ClientWithPolicies {
  clientId: string;
  agentId: string;
  firstName: string;
  surname: string;
  lastName: string;
  fullName: string;
  phoneNumber: string;
  email: string;
  address: string;
  nationalId: string;
  dateOfBirth: Date;
  isClient: boolean;
  insuranceType: string;
  clientNotes?: string;
  clientCreatedDate: Date;
  clientModifiedDate: Date;
  clientIsActive: boolean;

  // ✅ Instead of duplicating policy fields here, use array of ClientPolicyLite
  policies: ClientPolicyLite[];
}

export interface ClientWithPoliciesFilterRequest {
  agentId?: string;
  clientId?: string;
  includeInactive?: boolean;
}
