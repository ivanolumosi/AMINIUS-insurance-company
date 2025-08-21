// services/policy.service.ts
import { poolPromise } from '../../db';
import * as sql from 'mssql';
import {
    PolicyCatalog,
    ClientPolicy,
    PolicyTemplate,
    PolicyCategory,
    InsuranceCompany,
    PolicyType,
    PolicyStatistics,
    PolicyStatisticsDetailed,
    AgentDashboardSummary,
    PolicyRenewalCandidate,
    PolicyHistory,
    CreatePolicyCatalogRequest,
    UpdatePolicyCatalogRequest,
    PolicyCatalogFilterRequest,
    UpsertPolicyCatalogRequest,
    CreateClientPolicyRequest,
    UpdateClientPolicyRequest,
    ClientPolicyFilterRequest,
    UpsertClientPolicyRequest,
    ExpiringPoliciesRequest,
    PolicyRenewalRequest,
    BulkUpdatePolicyStatusRequest,
    CreatePolicyTemplateRequest,
    UpdatePolicyTemplateRequest,
    PolicyTemplateFilterRequest,
    SearchPoliciesRequest,
    GetPoliciesByStatusRequest,
    PolicyStatisticsRequest,
    CreatePolicyCategoryRequest,
    UpdatePolicyCategoryRequest,
    CreateInsuranceCompanyRequest,
    UpdateInsuranceCompanyRequest,
    CreatePolicyTypeRequest,
    UpdatePolicyTypeRequest,
    GetPolicyHistoryRequest,
    GetRenewalCandidatesRequest,
    BatchExpirePoliciesRequest,
    CleanupSoftDeletedRequest,
    DeleteRequest,
    PolicyResponse,
    PaginatedResponse,
    CreateResponse,
    UpdateResponse,
    DeleteResponse,
    RenewalResponse,
    CleanupResponse,
    PolicyValidationRequest,
    PolicyValidationResponse
} from '../interfaces/policy';
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

  policyId?: string;
  policyName?: string;
  status?: string;
  startDate?: Date;
  endDate?: Date;
  policyNotes?: string;
  policyCreatedDate?: Date;
  policyModifiedDate?: Date;
  policyIsActive?: boolean;
  policyCatalogId?: string;
  catalogPolicyName?: string;
  typeId?: string;
  typeName?: string;
  companyId?: string;
  companyName?: string;
  daysUntilExpiry?: number;
}

export interface ClientWithPoliciesFilterRequest {
  agentId?: string;
  clientId?: string;
  includeInactive?: boolean;
}

export class PolicyService {
    static softDeletePolicyType(typeId: string) {
        throw new Error('Method not implemented.');
    }

    // ============================================
    // POLICY CATALOG MANAGEMENT
    // ============================================

    public async getPolicyCatalog(request: PolicyCatalogFilterRequest): Promise<PolicyCatalog[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, request.agentId || null)
            .input('CompanyId', sql.UniqueIdentifier, request.companyId || null)
            .input('CategoryId', sql.UniqueIdentifier, request.categoryId || null)
            .input('TypeId', sql.UniqueIdentifier, request.typeId || null)
            .input('IsActive', sql.Bit, request.isActive !== undefined ? request.isActive : 1)
            .execute('GetPolicyCatalog');

        return result.recordset.map(this.mapPolicyCatalogFromDb);
    }
    public async getClientsWithPolicies(
    request: ClientWithPoliciesFilterRequest
  ): Promise<ClientWithPolicies[]> {
    const pool = await poolPromise;
    const result = await pool.request()
      .input('AgentId', sql.UniqueIdentifier, request.agentId || null)
      .input('ClientId', sql.UniqueIdentifier, request.clientId || null)
      .input('IncludeInactive', sql.Bit, request.includeInactive ? 1 : 0)
      .execute('GetClientsWithPolicies');

    return result.recordset.map(this.mapClientWithPoliciesFromDb);
  }
  
  private mapClientWithPoliciesFromDb(record: any): ClientWithPolicies {
    return {
      clientId: record.ClientId,
      agentId: record.AgentId,
      firstName: record.FirstName,
      surname: record.Surname,
      lastName: record.LastName,
      fullName: record.FullName,
      phoneNumber: record.PhoneNumber,
      email: record.Email,
      address: record.Address,
      nationalId: record.NationalId,
      dateOfBirth: record.DateOfBirth,
      isClient: record.IsClient,
      insuranceType: record.InsuranceType,
      clientNotes: record.ClientNotes,
      clientCreatedDate: record.ClientCreatedDate,
      clientModifiedDate: record.ClientModifiedDate,
      clientIsActive: record.ClientIsActive,

      policyId: record.PolicyId,
      policyName: record.PolicyName,
      status: record.Status,
      startDate: record.StartDate,
      endDate: record.EndDate,
      policyNotes: record.PolicyNotes,
      policyCreatedDate: record.PolicyCreatedDate,
      policyModifiedDate: record.PolicyModifiedDate,
      policyIsActive: record.PolicyIsActive,
      policyCatalogId: record.PolicyCatalogId,
      catalogPolicyName: record.CatalogPolicyName,
      typeId: record.TypeId,
      typeName: record.TypeName,
      companyId: record.CompanyId,
      companyName: record.CompanyName,
      daysUntilExpiry: record.DaysUntilExpiry,
    };
  }




    public async createPolicyCatalogItem(request: CreatePolicyCatalogRequest): Promise<CreateResponse> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, request.agentId)
            .input('PolicyName', sql.NVarChar(100), request.policyName)
            .input('CompanyId', sql.UniqueIdentifier, request.companyId)
            .input('Notes', sql.NVarChar(sql.MAX), request.notes || null)
            .input('CategoryId', sql.UniqueIdentifier, request.categoryId || null)
            .input('TypeId', sql.UniqueIdentifier, request.typeId || null)
            .output('PolicyCatalogId', sql.UniqueIdentifier)
            .execute('CreatePolicyCatalogItem');

        return {
            id: result.recordset[0].PolicyCatalogId
        };
    }

    public async updatePolicyCatalogItem(request: UpdatePolicyCatalogRequest): Promise<UpdateResponse> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('PolicyCatalogId', sql.UniqueIdentifier, request.policyCatalogId)
            .input('PolicyName', sql.NVarChar(100), request.policyName || null)
            .input('CompanyId', sql.UniqueIdentifier, request.companyId || null)
            .input('Notes', sql.NVarChar(sql.MAX), request.notes || null)
            .input('CategoryId', sql.UniqueIdentifier, request.categoryId || null)
            .input('TypeId', sql.UniqueIdentifier, request.typeId || null)
            .input('IsActive', sql.Bit, request.isActive !== undefined ? request.isActive : null)
            .execute('UpdatePolicyCatalogItem');

        return {
            rowsAffected: result.recordset[0].RowsAffected
        };
    }

    public async deletePolicyCatalogItem(policyCatalogId: string, hardDelete: boolean = false): Promise<DeleteResponse> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('PolicyCatalogId', sql.UniqueIdentifier, policyCatalogId)
            .input('HardDelete', sql.Bit, hardDelete)
            .execute('DeletePolicyCatalogItem');

        return {
            rowsAffected: result.recordset[0].RowsAffected
        };
    }

    public async upsertPolicyCatalog(request: UpsertPolicyCatalogRequest): Promise<CreateResponse> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('PolicyCatalogId', sql.UniqueIdentifier, request.policyCatalogId || null)
            .input('AgentId', sql.UniqueIdentifier, request.agentId)
            .input('PolicyName', sql.NVarChar(100), request.policyName)
            .input('CompanyId', sql.UniqueIdentifier, request.companyId)
            .input('Notes', sql.NVarChar(sql.MAX), request.notes || null)
            .input('CategoryId', sql.UniqueIdentifier, request.categoryId || null)
            .input('TypeId', sql.UniqueIdentifier, request.typeId || null)
            .execute('UpsertPolicyCatalog');

        return {
            id: result.recordset[0].PolicyCatalogId
        };
    }

    // ============================================
    // CLIENT POLICIES MANAGEMENT
    // ============================================

    public async getClientPolicies(request: ClientPolicyFilterRequest): Promise<ClientPolicy[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('ClientId', sql.UniqueIdentifier, request.clientId || null)
            .input('AgentId', sql.UniqueIdentifier, request.agentId || null)
            .input('Status', sql.NVarChar(20), request.status || null)
            .input('IsActive', sql.Bit, request.isActive !== undefined ? request.isActive : 1)
            .execute('GetClientPolicies');

        return result.recordset.map(this.mapClientPolicyFromDb);
    }

    public async getPolicyById(policyId: string): Promise<ClientPolicy | null> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('PolicyId', sql.UniqueIdentifier, policyId)
            .execute('GetPolicyById');

        return result.recordset.length > 0 ? this.mapClientPolicyFromDb(result.recordset[0]) : null;
    }

    public async createClientPolicy(request: CreateClientPolicyRequest): Promise<CreateResponse> {
    const pool = await poolPromise;
    const result = await pool.request()
        .input('ClientId', sql.UniqueIdentifier, request.clientId)
        .input('PolicyName', sql.NVarChar(100), request.policyName)
        .input('Status', sql.NVarChar(20), request.status || 'Active')
        .input('StartDate', sql.Date, request.startDate)
        .input('EndDate', sql.Date, request.endDate)
        .input('Notes', sql.NVarChar(sql.MAX), request.notes || null)
        .input('PolicyCatalogId', sql.UniqueIdentifier, request.policyCatalogId) // required
        .output('PolicyId', sql.UniqueIdentifier)
        .execute('CreateClientPolicy');

    return {
        id: result.recordset[0].PolicyId
    };
}


    public async updateClientPolicy(request: UpdateClientPolicyRequest): Promise<UpdateResponse> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('PolicyId', sql.UniqueIdentifier, request.policyId)
            .input('PolicyName', sql.NVarChar(100), request.policyName || null)
            .input('Status', sql.NVarChar(20), request.status || null)
            .input('StartDate', sql.Date, request.startDate || null)
            .input('EndDate', sql.Date, request.endDate || null)
            .input('Notes', sql.NVarChar(sql.MAX), request.notes || null)
            .input('PolicyCatalogId', sql.UniqueIdentifier, request.policyCatalogId || null)
            .input('TypeId', sql.UniqueIdentifier, request.typeId || null)
            .input('CompanyId', sql.UniqueIdentifier, request.companyId || null)
            .input('IsActive', sql.Bit, request.isActive !== undefined ? request.isActive : null)
            .execute('UpdateClientPolicy');

        return {
            rowsAffected: result.recordset[0].RowsAffected
        };
    }

    public async deleteClientPolicy(policyId: string, hardDelete: boolean = false): Promise<DeleteResponse> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('PolicyId', sql.UniqueIdentifier, policyId)
            .input('HardDelete', sql.Bit, hardDelete)
            .execute('DeleteClientPolicy');

        return {
            rowsAffected: result.recordset[0].RowsAffected
        };
    }

    public async upsertClientPolicy(request: UpsertClientPolicyRequest): Promise<CreateResponse> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('PolicyId', sql.UniqueIdentifier, request.policyId || null)
            .input('ClientId', sql.UniqueIdentifier, request.clientId)
            .input('PolicyName', sql.NVarChar(100), request.policyName)
            .input('Status', sql.NVarChar(20), request.status || 'Active')
            .input('StartDate', sql.Date, request.startDate)
            .input('EndDate', sql.Date, request.endDate)
            .input('Notes', sql.NVarChar(sql.MAX), request.notes || null)
            .input('PolicyCatalogId', sql.UniqueIdentifier, request.policyCatalogId || null)
            .input('TypeId', sql.UniqueIdentifier, request.typeId || null)
            .input('CompanyId', sql.UniqueIdentifier, request.companyId || null)
            .execute('UpsertClientPolicy');

        return {
            id: result.recordset[0].PolicyId
        };
    }

    public async getExpiringPolicies(request: ExpiringPoliciesRequest): Promise<ClientPolicy[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, request.agentId || null)
            .input('DaysAhead', sql.Int, request.daysAhead || 30)
            .input('Status', sql.NVarChar(20), request.status || 'Active')
            .execute('GetExpiringPolicies');

        return result.recordset.map(this.mapClientPolicyFromDb);
    }

    public async renewPolicy(request: PolicyRenewalRequest): Promise<RenewalResponse> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('PolicyId', sql.UniqueIdentifier, request.policyId)
            .input('NewStartDate', sql.Date, request.newStartDate)
            .input('NewEndDate', sql.Date, request.newEndDate)
            .input('NewPolicyName', sql.NVarChar(100), request.newPolicyName || null)
            .input('Notes', sql.NVarChar(sql.MAX), request.notes || null)
            .execute('RenewPolicy');

        return {
            newPolicyId: result.recordset[0].NewPolicyId,
            rowsAffected: result.recordset[0].RowsAffected
        };
    }

    public async bulkUpdatePolicyStatus(request: BulkUpdatePolicyStatusRequest): Promise<UpdateResponse> {
        const pool = await poolPromise;
        const policyIdsString = request.policyIds.join(',');
        
        const result = await pool.request()
            .input('PolicyIds', sql.NVarChar(sql.MAX), policyIdsString)
            .input('NewStatus', sql.NVarChar(20), request.newStatus)
            .execute('BulkUpdatePolicyStatus');

        return {
            rowsAffected: result.recordset[0].RowsAffected
        };
    }

    // ============================================
    // POLICY SEARCH AND FILTERING
    // ============================================

    public async searchPolicies(request: SearchPoliciesRequest): Promise<PaginatedResponse<ClientPolicy>> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('SearchTerm', sql.NVarChar(100), request.searchTerm || null)
            .input('AgentId', sql.UniqueIdentifier, request.agentId || null)
            .input('ClientId', sql.UniqueIdentifier, request.clientId || null)
            .input('CompanyId', sql.UniqueIdentifier, request.companyId || null)
            .input('TypeId', sql.UniqueIdentifier, request.typeId || null)
            .input('Status', sql.NVarChar(20), request.status || null)
            .input('StartDate', sql.Date, request.startDate || null)
            .input('EndDate', sql.Date, request.endDate || null)
            .input('PageSize', sql.Int, request.pageSize || 50)
            .input('PageNumber', sql.Int, request.pageNumber || 1)
            .execute('SearchPolicies');

        const policies = result.recordset.map(this.mapClientPolicyFromDb);
        
        // Get total count for pagination
        const countResult = await this.getSearchCount(request);
        const total = countResult;
        const pageSize = request.pageSize || 50;
        const pageNumber = request.pageNumber || 1;

        return {
            data: policies,
            total,
            pageNumber,
            pageSize,
            hasNextPage: pageNumber * pageSize < total,
            hasPreviousPage: pageNumber > 1
        };
    }

    public async getPoliciesByStatus(request: GetPoliciesByStatusRequest): Promise<ClientPolicy[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('Status', sql.NVarChar(20), request.status)
            .input('AgentId', sql.UniqueIdentifier, request.agentId || null)
            .execute('GetPoliciesByStatus');

        return result.recordset.map(this.mapClientPolicyFromDb);
    }

    // ============================================
    // POLICY TEMPLATES MANAGEMENT
    // ============================================

    public async getPolicyTemplates(request: PolicyTemplateFilterRequest): Promise<PolicyTemplate[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, request.agentId || null)
            .input('CategoryId', sql.UniqueIdentifier, request.categoryId || null)
            .input('TypeId', sql.UniqueIdentifier, request.typeId || null)
            .input('IsActive', sql.Bit, request.isActive !== undefined ? request.isActive : 1)
            .execute('GetPolicyTemplates');

        return result.recordset.map(this.mapPolicyTemplateFromDb);
    }

    public async createPolicyTemplate(request: CreatePolicyTemplateRequest): Promise<CreateResponse> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, request.agentId)
            .input('TemplateName', sql.NVarChar(100), request.templateName)
            .input('DefaultTermMonths', sql.Int, request.defaultTermMonths || null)
            .input('DefaultPremium', sql.Decimal(18, 2), request.defaultPremium || null)
            .input('CoverageDescription', sql.NVarChar(sql.MAX), request.coverageDescription || null)
            .input('Terms', sql.NVarChar(sql.MAX), request.terms || null)
            .input('CategoryId', sql.UniqueIdentifier, request.categoryId || null)
            .input('PolicyCatalogId', sql.UniqueIdentifier, request.policyCatalogId || null)
            .input('TypeId', sql.UniqueIdentifier, request.typeId || null)
            .output('TemplateId', sql.UniqueIdentifier)
            .execute('CreatePolicyTemplate');

        return {
            id: result.recordset[0].TemplateId
        };
    }

    public async updatePolicyTemplate(request: UpdatePolicyTemplateRequest): Promise<UpdateResponse> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('TemplateId', sql.UniqueIdentifier, request.templateId)
            .input('TemplateName', sql.NVarChar(100), request.templateName || null)
            .input('DefaultTermMonths', sql.Int, request.defaultTermMonths || null)
            .input('DefaultPremium', sql.Decimal(18, 2), request.defaultPremium || null)
            .input('CoverageDescription', sql.NVarChar(sql.MAX), request.coverageDescription || null)
            .input('Terms', sql.NVarChar(sql.MAX), request.terms || null)
            .input('CategoryId', sql.UniqueIdentifier, request.categoryId || null)
            .input('PolicyCatalogId', sql.UniqueIdentifier, request.policyCatalogId || null)
            .input('TypeId', sql.UniqueIdentifier, request.typeId || null)
            .input('IsActive', sql.Bit, request.isActive !== undefined ? request.isActive : null)
            .execute('UpdatePolicyTemplate');

        return {
            rowsAffected: result.recordset[0].RowsAffected
        };
    }

    public async deletePolicyTemplate(templateId: string, hardDelete: boolean = false): Promise<DeleteResponse> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('TemplateId', sql.UniqueIdentifier, templateId)
            .input('HardDelete', sql.Bit, hardDelete)
            .execute('DeletePolicyTemplate');

        return {
            rowsAffected: result.recordset[0].RowsAffected
        };
    }

    // ============================================
    // REFERENCE DATA MANAGEMENT
    // ============================================

    public async getInsuranceCompanies(isActive: boolean = true): Promise<InsuranceCompany[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('IsActive', sql.Bit, isActive)
            .execute('GetInsuranceCompanies');

        return result.recordset.map(this.mapInsuranceCompanyFromDb);
    }

    public async createInsuranceCompany(request: CreateInsuranceCompanyRequest): Promise<CreateResponse> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('CompanyName', sql.NVarChar(100), request.companyName)
            .output('CompanyId', sql.UniqueIdentifier)
            .execute('CreateInsuranceCompany');

        return {
            id: result.recordset[0].CompanyId
        };
    }

    public async updateInsuranceCompany(request: UpdateInsuranceCompanyRequest): Promise<UpdateResponse> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('CompanyId', sql.UniqueIdentifier, request.companyId)
            .input('CompanyName', sql.NVarChar(100), request.companyName || null)
            .input('IsActive', sql.Bit, request.isActive !== undefined ? request.isActive : null)
            .execute('UpdateInsuranceCompany');

        return {
            rowsAffected: result.recordset[0].RowsAffected
        };
    }

    public async getPolicyTypes(isActive: boolean = true): Promise<PolicyType[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('IsActive', sql.Bit, isActive)
            .execute('GetPolicyTypes');

        return result.recordset.map(this.mapPolicyTypeFromDb);
    }

    public async createPolicyType(request: CreatePolicyTypeRequest): Promise<CreateResponse> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('TypeName', sql.NVarChar(50), request.typeName)
            .output('TypeId', sql.UniqueIdentifier)
            .execute('CreatePolicyType');

        return {
            id: result.recordset[0].TypeId
        };
    }

    public async updatePolicyType(request: UpdatePolicyTypeRequest): Promise<UpdateResponse> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('TypeId', sql.UniqueIdentifier, request.typeId)
            .input('TypeName', sql.NVarChar(50), request.typeName || null)
            .input('IsActive', sql.Bit, request.isActive !== undefined ? request.isActive : null)
            .execute('UpdatePolicyType');

        return {
            rowsAffected: result.recordset[0].RowsAffected
        };
    }

    public async getPolicyCategories(isActive: boolean = true): Promise<PolicyCategory[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('IsActive', sql.Bit, isActive)
            .execute('GetPolicyCategories');

        return result.recordset.map(this.mapPolicyCategoryFromDb);
    }

    public async createPolicyCategory(request: CreatePolicyCategoryRequest): Promise<CreateResponse> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('CategoryName', sql.NVarChar(50), request.categoryName)
            .input('Description', sql.NVarChar(200), request.description || null)
            .output('CategoryId', sql.UniqueIdentifier)
            .execute('CreatePolicyCategory');

        return {
            id: result.recordset[0].CategoryId
        };
    }

    public async updatePolicyCategory(request: UpdatePolicyCategoryRequest): Promise<UpdateResponse> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('CategoryId', sql.UniqueIdentifier, request.categoryId)
            .input('CategoryName', sql.NVarChar(50), request.categoryName || null)
            .input('Description', sql.NVarChar(200), request.description || null)
            .input('IsActive', sql.Bit, request.isActive !== undefined ? request.isActive : null)
            .execute('UpdatePolicyCategory');

        return {
            rowsAffected: result.recordset[0].RowsAffected
        };
    }

    // ============================================
    // ANALYTICS AND REPORTING
    // ============================================

    public async getPolicyStatistics(request: PolicyStatisticsRequest): Promise<PolicyStatistics> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, request.agentId || null)
            .input('StartDate', sql.Date, request.startDate || null)
            .input('EndDate', sql.Date, request.endDate || null)
            .execute('GetPolicyStatistics');

        return this.mapPolicyStatisticsFromDb(result.recordset[0]);
    }

    public async getPolicyStatisticsDetailed(request: PolicyStatisticsRequest): Promise<PolicyStatisticsDetailed[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, request.agentId || null)
            .input('StartDate', sql.Date, request.startDate || null)
            .input('EndDate', sql.Date, request.endDate || null)
            .execute('GetPolicyStatisticsDetailed');

        return result.recordset.map(this.mapPolicyStatisticsDetailedFromDb);
    }

    public async getAgentDashboardSummary(agentId: string): Promise<AgentDashboardSummary> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, agentId)
            .execute('GetAgentDashboardSummary');

        return this.mapAgentDashboardSummaryFromDb(result.recordset[0]);
    }

    public async getPolicyRenewalCandidates(request: GetRenewalCandidatesRequest): Promise<PolicyRenewalCandidate[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AgentId', sql.UniqueIdentifier, request.agentId || null)
            .input('DaysAhead', sql.Int, request.daysAhead || 60)
            .execute('GetPolicyRenewalCandidates');

        return result.recordset.map(this.mapPolicyRenewalCandidateFromDb);
    }

    public async getPolicyHistory(request: GetPolicyHistoryRequest): Promise<PolicyHistory[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('ClientId', sql.UniqueIdentifier, request.clientId)
            .input('IncludeInactive', sql.Bit, request.includeInactive || false)
            .execute('GetPolicyHistoryForClient');

        return result.recordset.map(this.mapPolicyHistoryFromDb);
    }

    // ============================================
    // UTILITY METHODS
    // ============================================

    public async batchExpirePolicies(request: BatchExpirePoliciesRequest): Promise<UpdateResponse> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('AsOfDate', sql.Date, request.asOfDate || null)
            .execute('BatchExpirePolicies');

        return {
            rowsAffected: result.recordset[0].PoliciesExpired
        };
    }

    public async cleanupSoftDeletedRecords(request: CleanupSoftDeletedRequest): Promise<CleanupResponse[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('DaysOld', sql.Int, request.daysOld || 365)
            .input('DryRun', sql.Bit, request.dryRun !== undefined ? request.dryRun : true)
            .execute('CleanupSoftDeletedRecords');

        return result.recordset.map(row => ({
            tableName: row.TableName,
            recordsToDelete: row.RecordsToDelete,
            totalRecordsDeleted: row.TotalRecordsDeleted
        }));
    }

    // ============================================
    // PRIVATE MAPPING METHODS
    // ============================================

    private mapPolicyCatalogFromDb(row: any): PolicyCatalog {
        return {
            policyId: row.PolicyCatalogId,
            agentId: row.AgentId,
            policyName: row.PolicyName,
            companyId: row.CompanyId,
            companyName: row.CompanyName,
            notes: row.Notes,
            isActive: row.IsActive,
            createdDate: new Date(row.CreatedDate),
            modifiedDate: row.ModifiedDate ? new Date(row.ModifiedDate) : undefined,
            categoryId: row.CategoryId,
            categoryName: row.CategoryName,
            typeId: row.TypeId,
            typeName: row.TypeName
        };
    }

    private mapClientPolicyFromDb(row: any): ClientPolicy {
        return {
            policyId: row.PolicyId,
            clientId: row.ClientId,
            policyName: row.PolicyName,
            status: row.Status,
            startDate: new Date(row.StartDate),
            endDate: new Date(row.EndDate),
            notes: row.Notes,
            createdDate: new Date(row.CreatedDate),
            modifiedDate: row.ModifiedDate ? new Date(row.ModifiedDate) : undefined,
            isActive: row.IsActive,
            policyCatalogId: row.PolicyCatalogId,
            catalogPolicyName: row.CatalogPolicyName,
            typeId: row.TypeId,
            typeName: row.TypeName,
            companyId: row.CompanyId,
            companyName: row.CompanyName,
            daysUntilExpiry: row.DaysUntilExpiry
        };
    }

    private mapPolicyTemplateFromDb(row: any): PolicyTemplate {
        return {
            templateId: row.TemplateId,
            agentId: row.AgentId,
            templateName: row.TemplateName,
            defaultTermMonths: row.DefaultTermMonths,
            defaultPremium: row.DefaultPremium,
            coverageDescription: row.CoverageDescription,
            terms: row.Terms,
            isActive: row.IsActive,
            createdDate: new Date(row.CreatedDate),
            categoryId: row.CategoryId,
            categoryName: row.CategoryName,
            policyCatalogId: row.PolicyCatalogId,
            catalogPolicyName: row.CatalogPolicyName,
            typeId: row.TypeId,
            typeName: row.TypeName
        };
    }

    private mapInsuranceCompanyFromDb(row: any): InsuranceCompany {
        return {
            companyId: row.CompanyId,
            companyName: row.CompanyName,
            isActive: row.IsActive,
            createdDate: new Date(row.CreatedDate)
        };
    }

    private mapPolicyTypeFromDb(row: any): PolicyType {
        return {
            typeId: row.TypeId,
            typeName: row.TypeName,
            isActive: row.IsActive,
            createdDate: new Date(row.CreatedDate)
        };
    }

    private mapPolicyCategoryFromDb(row: any): PolicyCategory {
        return {
            categoryId: row.CategoryId,
            categoryName: row.CategoryName,
            description: row.Description,
            isActive: row.IsActive,
            createdDate: new Date(row.CreatedDate)
        };
    }

    private mapPolicyStatisticsFromDb(row: any): PolicyStatistics {
        return {
            totalPolicies: row.TotalPolicies,
            activePolicies: row.ActivePolicies,
            expiredPolicies: row.ExpiredPolicies,
            cancelledPolicies: row.CancelledPolicies,
            expiringIn30Days: row.ExpiringIn30Days,
            expiringIn60Days: row.ExpiringIn60Days
        };
    }

    private mapPolicyStatisticsDetailedFromDb(row: any): PolicyStatisticsDetailed {
        return {
            groupType: row.GroupType,
            groupName: row.GroupName,
            policyCount: row.PolicyCount,
            activeCount: row.ActiveCount
        };
    }

    private mapAgentDashboardSummaryFromDb(row: any): AgentDashboardSummary {
        return {
            totalPolicies: row.TotalPolicies,
            activePolicies: row.ActivePolicies,
            expiringIn30Days: row.ExpiringIn30Days,
            expiringIn60Days: row.ExpiringIn60Days,
            totalCompanies: row.TotalCompanies,
            totalClients: row.TotalClients,
            inactivePolicies: row.InactivePolicies
        };
    }

    private mapPolicyRenewalCandidateFromDb(row: any): PolicyRenewalCandidate {
        return {
            policyId: row.PolicyId,
            clientId: row.ClientId,
            policyName: row.PolicyName,
            status: row.Status,
            startDate: new Date(row.StartDate),
            endDate: new Date(row.EndDate),
            companyId: row.CompanyId,
            companyName: row.CompanyName,
            typeId: row.TypeId,
            typeName: row.TypeName,
            daysUntilExpiry: row.DaysUntilExpiry,
            renewalPriority: row.RenewalPriority as 'Urgent' | 'Soon' | 'Upcoming'
        };
    }

    private mapPolicyHistoryFromDb(row: any): PolicyHistory {
        return {
            policyId: row.PolicyId,
            clientId: row.ClientId,
            policyName: row.PolicyName,
            status: row.Status,
            startDate: new Date(row.StartDate),
            endDate: new Date(row.EndDate),
            notes: row.Notes,
            createdDate: new Date(row.CreatedDate),
            modifiedDate: row.ModifiedDate ? new Date(row.ModifiedDate) : undefined,
            companyId: row.CompanyId,
            companyName: row.CompanyName,
            typeId: row.TypeId,
            typeName: row.TypeName,
            policyDurationDays: row.PolicyDurationDays,
            policyState: row.PolicyState
        };
    }

    // ============================================
    // HELPER METHODS
    // ============================================

    private async getSearchCount(request: SearchPoliciesRequest): Promise<number> {
        // This would typically be a separate stored procedure or a modified version of SearchPolicies
        // For now, we'll use a simple count query
        const pool = await poolPromise;
        const result = await pool.request()
            .input('SearchTerm', sql.NVarChar(100), request.searchTerm || null)
            .input('AgentId', sql.UniqueIdentifier, request.agentId || null)
            .input('ClientId', sql.UniqueIdentifier, request.clientId || null)
            .input('CompanyId', sql.UniqueIdentifier, request.companyId || null)
            .input('TypeId', sql.UniqueIdentifier, request.typeId || null)
            .input('Status', sql.NVarChar(20), request.status || null)
            .input('StartDate', sql.Date, request.startDate || null)
            .input('EndDate', sql.Date, request.endDate || null)
            .query(`
                SELECT COUNT(*) as TotalCount
                FROM ClientPolicies cp
                    LEFT JOIN PolicyCatalog pc ON cp.PolicyCatalogId = pc.PolicyCatalogId
                    LEFT JOIN PolicyTypes pt ON cp.TypeId = pt.TypeId
                    LEFT JOIN InsuranceCompanies ic ON cp.CompanyId = ic.CompanyId
                WHERE cp.IsActive = 1
                    AND (@SearchTerm IS NULL OR cp.PolicyName LIKE '%' + @SearchTerm + '%' OR cp.Notes LIKE '%' + @SearchTerm + '%')
                    AND (@AgentId IS NULL OR pc.AgentId = @AgentId)
                    AND (@ClientId IS NULL OR cp.ClientId = @ClientId)
                    AND (@CompanyId IS NULL OR cp.CompanyId = @CompanyId)
                    AND (@TypeId IS NULL OR cp.TypeId = @TypeId)
                    AND (@Status IS NULL OR cp.Status = @Status)
                    AND (@StartDate IS NULL OR cp.StartDate >= @StartDate)
                    AND (@EndDate IS NULL OR cp.EndDate <= @EndDate)
            `);

        return result.recordset[0].TotalCount;
    }

    // ============================================
    // VALIDATION METHODS
    // ============================================

    public async validatePolicy(request: PolicyValidationRequest): Promise<PolicyValidationResponse> {
        const errors: string[] = [];
        const warnings: string[] = [];

        // Basic validation logic - you can expand this based on business rules
        const policyData = request.policyData;

        if (!policyData.policyName || policyData.policyName.trim().length === 0) {
            errors.push('Policy name is required');
        }

        if (!policyData.clientId) {
            errors.push('Client ID is required');
        }

        if (!policyData.startDate) {
            errors.push('Start date is required');
        }

        if (!policyData.endDate) {
            errors.push('End date is required');
        }

        if (policyData.startDate && policyData.endDate) {
            const startDate = new Date(policyData.startDate);
            const endDate = new Date(policyData.endDate);
            
            if (endDate <= startDate) {
                errors.push('End date must be after start date');
            }

            // Check if policy is expiring soon
            const today = new Date();
            const daysUntilExpiry = Math.ceil((endDate.getTime() - today.getTime()) / (1000 * 60 * 60 * 24));
            
            if (daysUntilExpiry <= 30 && daysUntilExpiry > 0) {
                warnings.push('Policy expires within 30 days');
            }
        }

        return {
            isValid: errors.length === 0,
            errors,
            warnings
        };
    }

    // ============================================
    // BATCH OPERATIONS
    // ============================================

    public async bulkCreatePolicies(policies: CreateClientPolicyRequest[]): Promise<CreateResponse[]> {
        const results: CreateResponse[] = [];
        const pool = await poolPromise;
        
        const transaction = pool.transaction();
        
        try {
            await transaction.begin();
            
            for (const policyRequest of policies) {
                const request = transaction.request();
                const result = await request
                    .input('ClientId', sql.UniqueIdentifier, policyRequest.clientId)
                    .input('PolicyName', sql.NVarChar(100), policyRequest.policyName)
                    .input('Status', sql.NVarChar(20), policyRequest.status || 'Active')
                    .input('StartDate', sql.Date, policyRequest.startDate)
                    .input('EndDate', sql.Date, policyRequest.endDate)
                    .input('Notes', sql.NVarChar(sql.MAX), policyRequest.notes || null)
                    .input('PolicyCatalogId', sql.UniqueIdentifier, policyRequest.policyCatalogId || null)
                    .input('TypeId', sql.UniqueIdentifier, policyRequest.typeId || null)
                    .input('CompanyId', sql.UniqueIdentifier, policyRequest.companyId || null)
                    .output('PolicyId', sql.UniqueIdentifier)
                    .execute('CreateClientPolicy');

                results.push({
                    id: result.recordset[0].PolicyId
                });
            }

            await transaction.commit();
            return results;
            
        } catch (error) {
            await transaction.rollback();
            throw error;
        }
    }

    public async bulkUpdatePolicies(updates: UpdateClientPolicyRequest[]): Promise<UpdateResponse[]> {
        const results: UpdateResponse[] = [];
        const pool = await poolPromise;
        
        const transaction = pool.transaction();
        
        try {
            await transaction.begin();
            
            for (const updateRequest of updates) {
                const request = transaction.request();
                const result = await request
                    .input('PolicyId', sql.UniqueIdentifier, updateRequest.policyId)
                    .input('PolicyName', sql.NVarChar(100), updateRequest.policyName || null)
                    .input('Status', sql.NVarChar(20), updateRequest.status || null)
                    .input('StartDate', sql.Date, updateRequest.startDate || null)
                    .input('EndDate', sql.Date, updateRequest.endDate || null)
                    .input('Notes', sql.NVarChar(sql.MAX), updateRequest.notes || null)
                    .input('PolicyCatalogId', sql.UniqueIdentifier, updateRequest.policyCatalogId || null)
                    .input('TypeId', sql.UniqueIdentifier, updateRequest.typeId || null)
                    .input('CompanyId', sql.UniqueIdentifier, updateRequest.companyId || null)
                    .input('IsActive', sql.Bit, updateRequest.isActive !== undefined ? updateRequest.isActive : null)
                    .execute('UpdateClientPolicy');

                results.push({
                    rowsAffected: result.recordset[0].RowsAffected
                });
            }

            await transaction.commit();
            return results;
            
        } catch (error) {
            await transaction.rollback();
            throw error;
        }
    }

    // ============================================
    // EXPORT/IMPORT METHODS
    // ============================================

    public async exportPolicies(agentId?: string, format: 'json' | 'csv' = 'json'): Promise<any> {
        const policies = await this.getClientPolicies({ 
            agentId, 
            isActive: true 
        });

        if (format === 'csv') {
            // Convert to CSV format - you might want to use a CSV library
            return this.convertPoliciesToCSV(policies);
        }

        return policies;
    }

    private convertPoliciesToCSV(policies: ClientPolicy[]): string {
        if (policies.length === 0) return '';

        const headers = [
            'Policy ID', 'Client ID', 'Policy Name', 'Status', 
            'Start Date', 'End Date', 'Company Name', 'Type Name',
            'Days Until Expiry', 'Notes'
        ];

        const rows = policies.map(policy => [
            policy.policyId,
            policy.clientId,
            policy.policyName,
            policy.status,
            policy.startDate.toISOString().split('T')[0],
            policy.endDate.toISOString().split('T')[0],
            policy.companyName || '',
            policy.typeName || '',
            policy.daysUntilExpiry?.toString() || '',
            policy.notes || ''
        ]);

        const csvContent = [headers, ...rows]
            .map(row => row.map(cell => `"${cell}"`).join(','))
            .join('\n');

        return csvContent;
    }

    // ============================================
    // ERROR HANDLING WRAPPER
    // ============================================

    private async executeWithErrorHandling<T>(
        operation: () => Promise<T>,
        operationName: string
    ): Promise<PolicyResponse<T>> {
        try {
            const data = await operation();
            return {
                success: true,
                data,
                message: `${operationName} completed successfully`
            };
        } catch (error) {
            console.error(`Error in ${operationName}:`, error);
            return {
                success: false,
                message: `Error in ${operationName}: ${error instanceof Error ? error.message : 'Unknown error'}`
            };
        }
    }
    // ============================================
// AUTOCOMPLETE FUNCTIONS
// ============================================

/**
 * Search Insurance Companies by partial name
 */
public async searchInsuranceCompanies(term: string): Promise<InsuranceCompany[]> {
    const pool = await poolPromise;
    const result = await pool.request()
        .input('SearchTerm', sql.NVarChar(100), `%${term}%`)
        .query(`
            SELECT TOP 20 CompanyId, CompanyName
            FROM InsuranceCompanies
            WHERE IsActive = 1 AND CompanyName LIKE @SearchTerm
            ORDER BY CompanyName
        `);
    return result.recordset;
}

/**
 * Search Policy Catalog entries by partial name
 */
public async searchPolicyCatalog(agentId: string, term: string): Promise<PolicyCatalog[]> {
    const pool = await poolPromise;
    const result = await pool.request()
        .input('AgentId', sql.UniqueIdentifier, agentId)
        .input('SearchTerm', sql.NVarChar(100), `%${term}%`)
        .query(`
            SELECT TOP 20 PolicyCatalogId, PolicyName, CompanyId, TypeId, CategoryId
            FROM PolicyCatalog
            WHERE IsActive = 1 
              AND AgentId = @AgentId
              AND PolicyName LIKE @SearchTerm
            ORDER BY PolicyName
        `);
    return result.recordset;
}

/**
 * Search Policy Categories by partial name
 */
public async searchPolicyCategories(term: string): Promise<PolicyCategory[]> {
    const pool = await poolPromise;
    const result = await pool.request()
        .input('SearchTerm', sql.NVarChar(50), `%${term}%`)
        .query(`
            SELECT TOP 20 CategoryId, CategoryName
            FROM PolicyCategories
            WHERE IsActive = 1 AND CategoryName LIKE @SearchTerm
            ORDER BY CategoryName
        `);
    return result.recordset;
}

/**
 * Search Policy Templates by partial name
 */
public async searchPolicyTemplates(agentId: string, term: string): Promise<PolicyTemplate[]> {
    const pool = await poolPromise;
    const result = await pool.request()
        .input('AgentId', sql.UniqueIdentifier, agentId)
        .input('SearchTerm', sql.NVarChar(100), `%${term}%`)
        .query(`
            SELECT TOP 20 TemplateId, TemplateName, PolicyCatalogId, CategoryId, TypeId
            FROM PolicyTemplates
            WHERE IsActive = 1 
              AND AgentId = @AgentId
              AND TemplateName LIKE @SearchTerm
            ORDER BY TemplateName
        `);
    return result.recordset;
}

/**
 * Search Policy Types by partial name
 */
public async searchPolicyTypes(term: string): Promise<PolicyType[]> {
    const pool = await poolPromise;
    const result = await pool.request()
        .input('SearchTerm', sql.NVarChar(50), `%${term}%`)
        .query(`
            SELECT TOP 20 TypeId, TypeName
            FROM PolicyTypes
            WHERE IsActive = 1 AND TypeName LIKE @SearchTerm
            ORDER BY TypeName
        `);
    return result.recordset;
}

/**
 * Search Client Policies by partial name
 */
public async searchClientPolicies(clientId: string, term: string): Promise<ClientPolicy[]> {
    const pool = await poolPromise;
    const result = await pool.request()
        .input('ClientId', sql.UniqueIdentifier, clientId)
        .input('SearchTerm', sql.NVarChar(100), `%${term}%`)
        .query(`
            SELECT TOP 20 PolicyId, PolicyName, Status, StartDate, EndDate
            FROM ClientPolicies
            WHERE IsActive = 1 
              AND ClientId = @ClientId
              AND PolicyName LIKE @SearchTerm
            ORDER BY PolicyName
        `);
    return result.recordset;
}


    // ============================================
    // PUBLIC WRAPPER METHODS WITH ERROR HANDLING
    // ============================================

    public async getPolicyCatalogSafe(request: PolicyCatalogFilterRequest): Promise<PolicyResponse<PolicyCatalog[]>> {
        return this.executeWithErrorHandling(
            () => this.getPolicyCatalog(request),
            'Get Policy Catalog'
        );
    }

    public async getClientPoliciesSafe(request: ClientPolicyFilterRequest): Promise<PolicyResponse<ClientPolicy[]>> {
        return this.executeWithErrorHandling(
            () => this.getClientPolicies(request),
            'Get Client Policies'
        );
    }

    public async createClientPolicySafe(request: CreateClientPolicyRequest): Promise<PolicyResponse<CreateResponse>> {
        return this.executeWithErrorHandling(
            () => this.createClientPolicy(request),
            'Create Client Policy'
        );
    }

    public async updateClientPolicySafe(request: UpdateClientPolicyRequest): Promise<PolicyResponse<UpdateResponse>> {
        return this.executeWithErrorHandling(
            () => this.updateClientPolicy(request),
            'Update Client Policy'
        );
    }
// ============================================
// INSURANCE COMPANY MANAGEMENT
// ============================================

// public async getInsuranceCompanies(): Promise<InsuranceCompany[]> {
//     const pool = await poolPromise;
//     const result = await pool.request()
//         .execute('GetInsuranceCompanies'); // Stored Procedure name
//     return result.recordset as InsuranceCompany[];
// }

// public async createInsuranceCompany(request: CreateInsuranceCompanyRequest): Promise<CreateResponse> {
//     const pool = await poolPromise;
//     const result = await pool.request()
//         .input('CompanyName', sql.NVarChar(100), request.companyName)
//         .output('CompanyId', sql.UniqueIdentifier)
//         .execute('CreateInsuranceCompany');

//     return {
//         id: result.output.CompanyId
//     };
// }

// public async updateInsuranceCompany(request: UpdateInsuranceCompanyRequest): Promise<UpdateResponse> {
//     const pool = await poolPromise;
//     const result = await pool.request()
//         .input('CompanyId', sql.UniqueIdentifier, request.companyId)
//         .input('CompanyName', sql.NVarChar(100), request.companyName || null)
//         .input('IsActive', sql.Bit, request.isActive !== undefined ? request.isActive : null)
//         .execute('UpdateInsuranceCompany');

//     return {
//         rowsAffected: result.recordset[0]?.RowsAffected || 0
//     };
// }

public async deleteInsuranceCompany(companyId: string, request?: DeleteRequest): Promise<DeleteResponse> {
    const pool = await poolPromise;
    const result = await pool.request()
        .input('CompanyId', sql.UniqueIdentifier, companyId)
        .input('HardDelete', sql.Bit, request?.hardDelete ? 1 : 0)
        .execute('DeleteInsuranceCompany');

    return {
        rowsAffected: result.recordset[0]?.RowsAffected || 0
    };
}


    public async softDeletePolicyTemplate(templateId: string): Promise<void> {
        const pool = await poolPromise;
        await pool.request()
            .input('TemplateId', sql.UniqueIdentifier, templateId)
            .execute('sp_SoftDeletePolicyTemplate');
    }

    public async softDeletePolicyCatalog(policyCatalogId: string): Promise<void> {
        const pool = await poolPromise;
        await pool.request()
            .input('PolicyCatalogId', sql.UniqueIdentifier, policyCatalogId)
            .execute('sp_SoftDeletePolicyCatalog');
    }

    public async softDeletePolicyCategory(categoryId: string): Promise<void> {
        const pool = await poolPromise;
        await pool.request()
            .input('CategoryId', sql.UniqueIdentifier, categoryId)
            .execute('sp_SoftDeletePolicyCategory');
    }

    public async softDeleteInsuranceCompany(companyId: string): Promise<void> {
        const pool = await poolPromise;
        await pool.request()
            .input('CompanyId', sql.UniqueIdentifier, companyId)
            .execute('sp_SoftDeleteInsuranceCompany');
    }

    public async softDeleteClientPolicy(policyId: string): Promise<void> {
        const pool = await poolPromise;
        await pool.request()
            .input('PolicyId', sql.UniqueIdentifier, policyId)
            .execute('sp_SoftDeleteClientPolicy');
    }
    
 async softDeletePolicyType(typeId: string) {
    const pool = await poolPromise;
    await pool.request()
        .input('TypeId', sql.UniqueIdentifier, typeId)
        .execute('PolicyTypes_SoftDelete');
    return { message: 'PolicyType soft deleted successfully' };
}

}
