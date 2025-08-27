// services/policy.service.ts
import { poolPromise } from '../../db';
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

    // ============================================
    // POLICY CATALOG MANAGEMENT
    // ============================================

    public async getPolicyCatalog(request: PolicyCatalogFilterRequest): Promise<PolicyCatalog[]> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_get_policy_catalog($1,$2,$3,$4,$5)',
            [
                request.agentId || null,
                request.companyId || null,
                request.categoryId || null,
                request.typeId || null,
                request.isActive !== undefined ? request.isActive : true
            ]
        );
        return result.rows.map(this.mapPolicyCatalogFromDb);
    }

    public async getClientsWithPolicies(
        request: ClientWithPoliciesFilterRequest
    ): Promise<ClientWithPolicies[]> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_get_clients_with_policies($1,$2,$3)',
            [
                request.agentId || null,
                request.clientId || null,
                request.includeInactive || false
            ]
        );
        return result.rows.map(this.mapClientWithPoliciesFromDb);
    }

    private mapClientWithPoliciesFromDb(record: any): ClientWithPolicies {
        return {
            clientId: record.clientid,
            agentId: record.agentid,
            firstName: record.firstname,
            surname: record.surname,
            lastName: record.lastname,
            fullName: record.fullname,
            phoneNumber: record.phonenumber,
            email: record.email,
            address: record.address,
            nationalId: record.nationalid,
            dateOfBirth: record.dateofbirth,
            isClient: record.isclient,
            insuranceType: record.insurancetype,
            clientNotes: record.clientnotes,
            clientCreatedDate: record.clientcreateddate,
            clientModifiedDate: record.clientmodifieddate,
            clientIsActive: record.clientisactive,
            policyId: record.policyid,
            policyName: record.policyname,
            status: record.status,
            startDate: record.startdate,
            endDate: record.enddate,
            policyNotes: record.policynotes,
            policyCreatedDate: record.policycreateddate,
            policyModifiedDate: record.policymodifieddate,
            policyIsActive: record.policyisactive,
            policyCatalogId: record.policycatalogid,
            catalogPolicyName: record.catalogpolicyname,
            typeId: record.typeid,
            typeName: record.typename,
            companyId: record.companyid,
            companyName: record.companyname,
            daysUntilExpiry: record.daysuntilexpiry,
        };
    }

    public async createPolicyCatalogItem(request: CreatePolicyCatalogRequest): Promise<CreateResponse> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT sp_create_policy_catalog_item($1,$2,$3,$4,$5,$6) AS policy_catalog_id',
            [
                request.agentId,
                request.policyName,
                request.companyId,
                request.notes || null,
                request.categoryId || null,
                request.typeId || null
            ]
        );
        return {
            id: result.rows[0].policy_catalog_id
        };
    }

    public async updatePolicyCatalogItem(request: UpdatePolicyCatalogRequest): Promise<UpdateResponse> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT sp_update_policy_catalog_item($1,$2,$3,$4,$5,$6,$7) AS rows_affected',
            [
                request.policyCatalogId,
                request.policyName || null,
                request.companyId || null,
                request.notes || null,
                request.categoryId || null,
                request.typeId || null,
                request.isActive !== undefined ? request.isActive : null
            ]
        );
        return {
            rowsAffected: result.rows[0].rows_affected
        };
    }

    public async deletePolicyCatalogItem(policyCatalogId: string, hardDelete: boolean = false): Promise<DeleteResponse> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT sp_delete_policy_catalog_item($1,$2) AS rows_affected',
            [policyCatalogId, hardDelete]
        );
        return {
            rowsAffected: result.rows[0].rows_affected
        };
    }

    public async upsertPolicyCatalog(request: UpsertPolicyCatalogRequest): Promise<CreateResponse> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT sp_upsert_policy_catalog($1,$2,$3,$4,$5,$6,$7) AS policy_catalog_id',
            [
                request.policyCatalogId || null,
                request.agentId,
                request.policyName,
                request.companyId,
                request.notes || null,
                request.categoryId || null,
                request.typeId || null
            ]
        );
        return {
            id: result.rows[0].policy_catalog_id
        };
    }

    // ============================================
    // CLIENT POLICIES MANAGEMENT
    // ============================================

    public async getClientPolicies(request: ClientPolicyFilterRequest): Promise<ClientPolicy[]> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_get_client_policies($1,$2,$3,$4)',
            [
                request.clientId || null,
                request.agentId || null,
                request.status || null,
                request.isActive !== undefined ? request.isActive : true
            ]
        );
        return result.rows.map(this.mapClientPolicyFromDb);
    }

    public async getPolicyById(policyId: string): Promise<ClientPolicy | null> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_get_policy_by_id($1)',
            [policyId]
        );
        return result.rows.length > 0 ? this.mapClientPolicyFromDb(result.rows[0]) : null;
    }

    public async createClientPolicy(request: CreateClientPolicyRequest): Promise<CreateResponse> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT sp_create_client_policy($1,$2,$3,$4,$5,$6,$7) AS policy_id',
            [
                request.clientId,
                request.policyName,
                request.status || 'Active',
                request.startDate,
                request.endDate,
                request.notes || null,
                request.policyCatalogId
            ]
        );
        return {
            id: result.rows[0].policy_id
        };
    }

    public async updateClientPolicy(request: UpdateClientPolicyRequest): Promise<UpdateResponse> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT sp_update_client_policy($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) AS rows_affected',
            [
                request.policyId,
                request.policyName || null,
                request.status || null,
                request.startDate || null,
                request.endDate || null,
                request.notes || null,
                request.policyCatalogId || null,
                request.typeId || null,
                request.companyId || null,
                request.isActive !== undefined ? request.isActive : null
            ]
        );
        return {
            rowsAffected: result.rows[0].rows_affected
        };
    }

    public async deleteClientPolicy(policyId: string, hardDelete: boolean = false): Promise<DeleteResponse> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT sp_delete_client_policy($1,$2) AS rows_affected',
            [policyId, hardDelete]
        );
        return {
            rowsAffected: result.rows[0].rows_affected
        };
    }

    public async upsertClientPolicy(request: UpsertClientPolicyRequest): Promise<CreateResponse> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT sp_upsert_client_policy($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) AS policy_id',
            [
                request.policyId || null,
                request.clientId,
                request.policyName,
                request.status || 'Active',
                request.startDate,
                request.endDate,
                request.notes || null,
                request.policyCatalogId || null,
                request.typeId || null,
                request.companyId || null
            ]
        );
        return {
            id: result.rows[0].policy_id
        };
    }

    public async getExpiringPolicies(request: ExpiringPoliciesRequest): Promise<ClientPolicy[]> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_get_expiring_policies($1,$2,$3)',
            [
                request.agentId || null,
                request.daysAhead || 30,
                request.status || 'Active'
            ]
        );
        return result.rows.map(this.mapClientPolicyFromDb);
    }

    public async renewPolicy(request: PolicyRenewalRequest): Promise<RenewalResponse> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_renew_policy($1,$2,$3,$4,$5)',
            [
                request.policyId,
                request.newStartDate,
                request.newEndDate,
                request.newPolicyName || null,
                request.notes || null
            ]
        );
        return {
            newPolicyId: result.rows[0].new_policy_id,
            rowsAffected: result.rows[0].rows_affected
        };
    }

    public async bulkUpdatePolicyStatus(request: BulkUpdatePolicyStatusRequest): Promise<UpdateResponse> {
        const pool = await poolPromise;
        const policyIdsArray = `{${request.policyIds.join(',')}}`;
        
        const result = await pool.query(
            'SELECT sp_bulk_update_policy_status($1,$2) AS rows_affected',
            [policyIdsArray, request.newStatus]
        );
        return {
            rowsAffected: result.rows[0].rows_affected
        };
    }

    // ============================================
    // POLICY SEARCH AND FILTERING
    // ============================================

    public async searchPolicies(request: SearchPoliciesRequest): Promise<PaginatedResponse<ClientPolicy>> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_search_policies($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)',
            [
                request.searchTerm || null,
                request.agentId || null,
                request.clientId || null,
                request.companyId || null,
                request.typeId || null,
                request.status || null,
                request.startDate || null,
                request.endDate || null,
                request.pageSize || 50,
                request.pageNumber || 1
            ]
        );

        const policies = result.rows.map(this.mapClientPolicyFromDb);
        
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
        const result = await pool.query(
            'SELECT * FROM sp_get_policies_by_status($1,$2)',
            [request.status, request.agentId || null]
        );
        return result.rows.map(this.mapClientPolicyFromDb);
    }

    // ============================================
    // POLICY TEMPLATES MANAGEMENT
    // ============================================

    public async getPolicyTemplates(request: PolicyTemplateFilterRequest): Promise<PolicyTemplate[]> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_get_policy_templates($1,$2,$3,$4)',
            [
                request.agentId || null,
                request.categoryId || null,
                request.typeId || null,
                request.isActive !== undefined ? request.isActive : true
            ]
        );
        return result.rows.map(this.mapPolicyTemplateFromDb);
    }

    public async createPolicyTemplate(request: CreatePolicyTemplateRequest): Promise<CreateResponse> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT sp_create_policy_template($1,$2,$3,$4,$5,$6,$7,$8,$9) AS template_id',
            [
                request.agentId,
                request.templateName,
                request.defaultTermMonths || null,
                request.defaultPremium || null,
                request.coverageDescription || null,
                request.terms || null,
                request.categoryId || null,
                request.policyCatalogId || null,
                request.typeId || null
            ]
        );
        return {
            id: result.rows[0].template_id
        };
    }

    public async updatePolicyTemplate(request: UpdatePolicyTemplateRequest): Promise<UpdateResponse> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT sp_update_policy_template($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) AS rows_affected',
            [
                request.templateId,
                request.templateName || null,
                request.defaultTermMonths || null,
                request.defaultPremium || null,
                request.coverageDescription || null,
                request.terms || null,
                request.categoryId || null,
                request.policyCatalogId || null,
                request.typeId || null,
                request.isActive !== undefined ? request.isActive : null
            ]
        );
        return {
            rowsAffected: result.rows[0].rows_affected
        };
    }

    public async deletePolicyTemplate(templateId: string, hardDelete: boolean = false): Promise<DeleteResponse> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT sp_delete_policy_template($1,$2) AS rows_affected',
            [templateId, hardDelete]
        );
        return {
            rowsAffected: result.rows[0].rows_affected
        };
    }

    // ============================================
    // REFERENCE DATA MANAGEMENT
    // ============================================

    public async getInsuranceCompanies(isActive: boolean = true): Promise<InsuranceCompany[]> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_get_insurance_companies($1)',
            [isActive]
        );
        return result.rows.map(this.mapInsuranceCompanyFromDb);
    }

    public async createInsuranceCompany(request: CreateInsuranceCompanyRequest): Promise<CreateResponse> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT sp_create_insurance_company($1) AS company_id',
            [request.companyName]
        );
        return {
            id: result.rows[0].company_id
        };
    }

    public async updateInsuranceCompany(request: UpdateInsuranceCompanyRequest): Promise<UpdateResponse> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT sp_update_insurance_company($1,$2,$3) AS rows_affected',
            [
                request.companyId,
                request.companyName || null,
                request.isActive !== undefined ? request.isActive : null
            ]
        );
        return {
            rowsAffected: result.rows[0].rows_affected
        };
    }

    public async getPolicyTypes(isActive: boolean = true): Promise<PolicyType[]> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_get_policy_types($1)',
            [isActive]
        );
        return result.rows.map(this.mapPolicyTypeFromDb);
    }

    public async createPolicyType(request: CreatePolicyTypeRequest): Promise<CreateResponse> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT sp_create_policy_type($1) AS type_id',
            [request.typeName]
        );
        return {
            id: result.rows[0].type_id
        };
    }

    public async updatePolicyType(request: UpdatePolicyTypeRequest): Promise<UpdateResponse> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT sp_update_policy_type($1,$2,$3) AS rows_affected',
            [
                request.typeId,
                request.typeName || null,
                request.isActive !== undefined ? request.isActive : null
            ]
        );
        return {
            rowsAffected: result.rows[0].rows_affected
        };
    }

    public async getPolicyCategories(isActive: boolean = true): Promise<PolicyCategory[]> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_get_policy_categories($1)',
            [isActive]
        );
        return result.rows.map(this.mapPolicyCategoryFromDb);
    }

    public async createPolicyCategory(request: CreatePolicyCategoryRequest): Promise<CreateResponse> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT sp_create_policy_category($1,$2) AS category_id',
            [request.categoryName, request.description || null]
        );
        return {
            id: result.rows[0].category_id
        };
    }

    public async updatePolicyCategory(request: UpdatePolicyCategoryRequest): Promise<UpdateResponse> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT sp_update_policy_category($1,$2,$3,$4) AS rows_affected',
            [
                request.categoryId,
                request.categoryName || null,
                request.description || null,
                request.isActive !== undefined ? request.isActive : null
            ]
        );
        return {
            rowsAffected: result.rows[0].rows_affected
        };
    }

    // ============================================
    // ANALYTICS AND REPORTING
    // ============================================

    public async getPolicyStatistics(request: PolicyStatisticsRequest): Promise<PolicyStatistics> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_get_policy_statistics($1,$2,$3)',
            [
                request.agentId || null,
                request.startDate || null,
                request.endDate || null
            ]
        );
        return this.mapPolicyStatisticsFromDb(result.rows[0]);
    }

    public async getPolicyStatisticsDetailed(request: PolicyStatisticsRequest): Promise<PolicyStatisticsDetailed[]> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_get_policy_statistics_detailed($1,$2,$3)',
            [
                request.agentId || null,
                request.startDate || null,
                request.endDate || null
            ]
        );
        return result.rows.map(this.mapPolicyStatisticsDetailedFromDb);
    }

    public async getAgentDashboardSummary(agentId: string): Promise<AgentDashboardSummary> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_get_agent_dashboard_summary($1)',
            [agentId]
        );
        return this.mapAgentDashboardSummaryFromDb(result.rows[0]);
    }

    public async getPolicyRenewalCandidates(request: GetRenewalCandidatesRequest): Promise<PolicyRenewalCandidate[]> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_get_policy_renewal_candidates($1,$2)',
            [request.agentId || null, request.daysAhead || 60]
        );
        return result.rows.map(this.mapPolicyRenewalCandidateFromDb);
    }

    public async getPolicyHistory(request: GetPolicyHistoryRequest): Promise<PolicyHistory[]> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_get_policy_history_for_client($1,$2)',
            [request.clientId, request.includeInactive || false]
        );
        return result.rows.map(this.mapPolicyHistoryFromDb);
    }

    // ============================================
    // UTILITY METHODS
    // ============================================

    public async batchExpirePolicies(request: BatchExpirePoliciesRequest): Promise<UpdateResponse> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT sp_batch_expire_policies($1) AS policies_expired',
            [request.asOfDate || null]
        );
        return {
            rowsAffected: result.rows[0].policies_expired
        };
    }

    public async cleanupSoftDeletedRecords(request: CleanupSoftDeletedRequest): Promise<CleanupResponse[]> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_cleanup_soft_deleted_records($1,$2)',
            [request.daysOld || 365, request.dryRun !== undefined ? request.dryRun : true]
        );
        return result.rows.map(row => ({
            tableName: row.table_name,
            recordsToDelete: row.records_to_delete,
            totalRecordsDeleted: row.total_records_deleted
        }));
    }

    // ============================================
    // PRIVATE MAPPING METHODS
    // ============================================

    private mapPolicyCatalogFromDb(row: any): PolicyCatalog {
        return {
            policyId: row.policycatalogid || row.policy_catalog_id,
            agentId: row.agentid || row.agent_id,
            policyName: row.policyname || row.policy_name,
            companyId: row.companyid || row.company_id,
            companyName: row.companyname || row.company_name,
            notes: row.notes,
            isActive: row.isactive || row.is_active,
            createdDate: new Date(row.createddate || row.created_date),
            modifiedDate: row.modifieddate || row.modified_date ? new Date(row.modifieddate || row.modified_date) : undefined,
            categoryId: row.categoryid || row.category_id,
            categoryName: row.categoryname || row.category_name,
            typeId: row.typeid || row.type_id,
            typeName: row.typename || row.type_name
        };
    }

    private mapClientPolicyFromDb(row: any): ClientPolicy {
        return {
            policyId: row.policyid || row.policy_id,
            clientId: row.clientid || row.client_id,
            policyName: row.policyname || row.policy_name,
            status: row.status,
            startDate: new Date(row.startdate || row.start_date),
            endDate: new Date(row.enddate || row.end_date),
            notes: row.notes,
            createdDate: new Date(row.createddate || row.created_date),
            modifiedDate: row.modifieddate || row.modified_date ? new Date(row.modifieddate || row.modified_date) : undefined,
            isActive: row.isactive || row.is_active,
            policyCatalogId: row.policycatalogid || row.policy_catalog_id,
            catalogPolicyName: row.catalogpolicyname || row.catalog_policy_name,
            typeId: row.typeid || row.type_id,
            typeName: row.typename || row.type_name,
            companyId: row.companyid || row.company_id,
            companyName: row.companyname || row.company_name,
            daysUntilExpiry: row.daysuntilexpiry || row.days_until_expiry
        };
    }

    private mapPolicyTemplateFromDb(row: any): PolicyTemplate {
        return {
            templateId: row.templateid || row.template_id,
            agentId: row.agentid || row.agent_id,
            templateName: row.templatename || row.template_name,
            defaultTermMonths: row.defaulttermmonths || row.default_term_months,
            defaultPremium: row.defaultpremium || row.default_premium,
            coverageDescription: row.coveragedescription || row.coverage_description,
            terms: row.terms,
            isActive: row.isactive || row.is_active,
            createdDate: new Date(row.createddate || row.created_date),
            categoryId: row.categoryid || row.category_id,
            categoryName: row.categoryname || row.category_name,
            policyCatalogId: row.policycatalogid || row.policy_catalog_id,
            catalogPolicyName: row.catalogpolicyname || row.catalog_policy_name,
            typeId: row.typeid || row.type_id,
            typeName: row.typename || row.type_name
        };
    }

    private mapInsuranceCompanyFromDb(row: any): InsuranceCompany {
        return {
            companyId: row.companyid || row.company_id,
            companyName: row.companyname || row.company_name,
            isActive: row.isactive || row.is_active,
            createdDate: new Date(row.createddate || row.created_date)
        };
    }

    private mapPolicyTypeFromDb(row: any): PolicyType {
        return {
            typeId: row.typeid || row.type_id,
            typeName: row.typename || row.type_name,
            isActive: row.isactive || row.is_active,
            createdDate: new Date(row.createddate || row.created_date)
        };
    }

    private mapPolicyCategoryFromDb(row: any): PolicyCategory {
        return {
            categoryId: row.categoryid || row.category_id,
            categoryName: row.categoryname || row.category_name,
            description: row.description,
            isActive: row.isactive || row.is_active,
            createdDate: new Date(row.createddate || row.created_date)
        };
    }

    private mapPolicyStatisticsFromDb(row: any): PolicyStatistics {
        return {
            totalPolicies: row.totalpolicies || row.total_policies,
            activePolicies: row.activepolicies || row.active_policies,
            expiredPolicies: row.expiredpolicies || row.expired_policies,
            cancelledPolicies: row.cancelledpolicies || row.cancelled_policies,
            expiringIn30Days: row.expiringin30days || row.expiring_in_30_days,
            expiringIn60Days: row.expiringin60days || row.expiring_in_60_days
        };
    }

    private mapPolicyStatisticsDetailedFromDb(row: any): PolicyStatisticsDetailed {
        return {
            groupType: row.grouptype || row.group_type,
            groupName: row.groupname || row.group_name,
            policyCount: row.policycount || row.policy_count,
            activeCount: row.activecount || row.active_count
        };
    }

    private mapAgentDashboardSummaryFromDb(row: any): AgentDashboardSummary {
        return {
            totalPolicies: row.totalpolicies || row.total_policies,
            activePolicies: row.activepolicies || row.active_policies,
            expiringIn30Days: row.expiringin30days || row.expiring_in_30_days,
            expiringIn60Days: row.expiringin60days || row.expiring_in_60_days,
            totalCompanies: row.totalcompanies || row.total_companies,
            totalClients: row.totalclients || row.total_clients,
            inactivePolicies: row.inactivepolicies || row.inactive_policies
        };
    }

    private mapPolicyRenewalCandidateFromDb(row: any): PolicyRenewalCandidate {
        return {
            policyId: row.policyid || row.policy_id,
            clientId: row.clientid || row.client_id,
            policyName: row.policyname || row.policy_name,
            status: row.status,
            startDate: new Date(row.startdate || row.start_date),
            endDate: new Date(row.enddate || row.end_date),
            companyId: row.companyid || row.company_id,
            companyName: row.companyname || row.company_name,
            typeId: row.typeid || row.type_id,
            typeName: row.typename || row.type_name,
            daysUntilExpiry: row.daysuntilexpiry || row.days_until_expiry,
            renewalPriority: row.renewalpriority || row.renewal_priority as 'Urgent' | 'Soon' | 'Upcoming'
        };
    }

    private mapPolicyHistoryFromDb(row: any): PolicyHistory {
        return {
            policyId: row.policyid || row.policy_id,
            clientId: row.clientid || row.client_id,
            policyName: row.policyname || row.policy_name,
            status: row.status,
            startDate: new Date(row.startdate || row.start_date),
            endDate: new Date(row.enddate || row.end_date),
            notes: row.notes,
            createdDate: new Date(row.createddate || row.created_date),
            modifiedDate: row.modifieddate || row.modified_date ? new Date(row.modifieddate || row.modified_date) : undefined,
            companyId: row.companyid || row.company_id,
            companyName: row.companyname || row.company_name,
            typeId: row.typeid || row.type_id,
            typeName: row.typename || row.type_name,
            policyDurationDays: row.policydurationdays || row.policy_duration_days,
            policyState: row.policystate || row.policy_state
        };
    }

    // ============================================
    // HELPER METHODS
    // ============================================

    private async getSearchCount(request: SearchPoliciesRequest): Promise<number> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT sp_get_search_policies_count($1,$2,$3,$4,$5,$6,$7,$8) AS total_count',
            [
                request.searchTerm || null,
                request.agentId || null,
                request.clientId || null,
                request.companyId || null,
                request.typeId || null,
                request.status || null,
                request.startDate || null,
                request.endDate || null
            ]
        );
        return result.rows[0].total_count;
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
        
        try {
            await pool.query('BEGIN');
            
            for (const policyRequest of policies) {
                const result = await pool.query(
                    'SELECT sp_create_client_policy($1,$2,$3,$4,$5,$6,$7) AS policy_id',
                    [
                        policyRequest.clientId,
                        policyRequest.policyName,
                        policyRequest.status || 'Active',
                        policyRequest.startDate,
                        policyRequest.endDate,
                        policyRequest.notes || null,
                        policyRequest.policyCatalogId
                    ]
                );

                results.push({
                    id: result.rows[0].policy_id
                });
            }

            await pool.query('COMMIT');
            return results;
            
        } catch (error) {
            await pool.query('ROLLBACK');
            throw error;
        }
    }

    public async bulkUpdatePolicies(updates: UpdateClientPolicyRequest[]): Promise<UpdateResponse[]> {
        const results: UpdateResponse[] = [];
        const pool = await poolPromise;
        
        try {
            await pool.query('BEGIN');
            
            for (const updateRequest of updates) {
                const result = await pool.query(
                    'SELECT sp_update_client_policy($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) AS rows_affected',
                    [
                        updateRequest.policyId,
                        updateRequest.policyName || null,
                        updateRequest.status || null,
                        updateRequest.startDate || null,
                        updateRequest.endDate || null,
                        updateRequest.notes || null,
                        updateRequest.policyCatalogId || null,
                        updateRequest.typeId || null,
                        updateRequest.companyId || null,
                        updateRequest.isActive !== undefined ? updateRequest.isActive : null
                    ]
                );

                results.push({
                    rowsAffected: result.rows[0].rows_affected
                });
            }

            await pool.query('COMMIT');
            return results;
            
        } catch (error) {
            await pool.query('ROLLBACK');
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
        const result = await pool.query(
            `SELECT "CompanyId" as companyid, "CompanyName" as companyname
             FROM "InsuranceCompanies"
             WHERE "IsActive" = true AND "CompanyName" ILIKE $1
             ORDER BY "CompanyName"
             LIMIT 20`,
            [`%${term}%`]
        );
        return result.rows.map(this.mapInsuranceCompanyFromDb);
    }

    /**
     * Search Policy Catalog entries by partial name
     */
    public async searchPolicyCatalog(agentId: string, term: string): Promise<PolicyCatalog[]> {
        const pool = await poolPromise;
        const result = await pool.query(
            `SELECT "PolicyCatalogId" as policycatalogid, "PolicyName" as policyname, 
                    "CompanyId" as companyid, "TypeId" as typeid, "CategoryId" as categoryid
             FROM "PolicyCatalog"
             WHERE "IsActive" = true 
               AND "AgentId" = $1
               AND "PolicyName" ILIKE $2
             ORDER BY "PolicyName"
             LIMIT 20`,
            [agentId, `%${term}%`]
        );
        return result.rows.map(this.mapPolicyCatalogFromDb);
    }

    /**
     * Search Policy Categories by partial name
     */
    public async searchPolicyCategories(term: string): Promise<PolicyCategory[]> {
        const pool = await poolPromise;
        const result = await pool.query(
            `SELECT "CategoryId" as categoryid, "CategoryName" as categoryname
             FROM "PolicyCategories"
             WHERE "IsActive" = true AND "CategoryName" ILIKE $1
             ORDER BY "CategoryName"
             LIMIT 20`,
            [`%${term}%`]
        );
        return result.rows.map(this.mapPolicyCategoryFromDb);
    }

    /**
     * Search Policy Templates by partial name
     */
    public async searchPolicyTemplates(agentId: string, term: string): Promise<PolicyTemplate[]> {
        const pool = await poolPromise;
        const result = await pool.query(
            `SELECT "TemplateId" as templateid, "TemplateName" as templatename, 
                    "PolicyCatalogId" as policycatalogid, "CategoryId" as categoryid, "TypeId" as typeid
             FROM "PolicyTemplates"
             WHERE "IsActive" = true 
               AND "AgentId" = $1
               AND "TemplateName" ILIKE $2
             ORDER BY "TemplateName"
             LIMIT 20`,
            [agentId, `%${term}%`]
        );
        return result.rows.map(this.mapPolicyTemplateFromDb);
    }

    /**
     * Search Policy Types by partial name
     */
    public async searchPolicyTypes(term: string): Promise<PolicyType[]> {
        const pool = await poolPromise;
        const result = await pool.query(
            `SELECT "TypeId" as typeid, "TypeName" as typename
             FROM "PolicyTypes"
             WHERE "IsActive" = true AND "TypeName" ILIKE $1
             ORDER BY "TypeName"
             LIMIT 20`,
            [`%${term}%`]
        );
        return result.rows.map(this.mapPolicyTypeFromDb);
    }

    /**
     * Search Client Policies by partial name
     */
    public async searchClientPolicies(clientId: string, term: string): Promise<ClientPolicy[]> {
        const pool = await poolPromise;
        const result = await pool.query(
            `SELECT "PolicyId" as policyid, "PolicyName" as policyname, 
                    "Status" as status, "StartDate" as startdate, "EndDate" as enddate
             FROM "ClientPolicies"
             WHERE "IsActive" = true 
               AND "ClientId" = $1
               AND "PolicyName" ILIKE $2
             ORDER BY "PolicyName"
             LIMIT 20`,
            [clientId, `%${term}%`]
        );
        return result.rows.map(this.mapClientPolicyFromDb);
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
    // SOFT DELETE METHODS
    // ============================================

    public async deleteInsuranceCompany(companyId: string, request?: DeleteRequest): Promise<DeleteResponse> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT sp_delete_insurance_company($1,$2) AS rows_affected',
            [companyId, request?.hardDelete ? true : false]
        );
        return {
            rowsAffected: result.rows[0].rows_affected
        };
    }

    public async softDeletePolicyTemplate(templateId: string): Promise<void> {
        const pool = await poolPromise;
        await pool.query('SELECT sp_soft_delete_policy_template($1)', [templateId]);
    }

    public async softDeletePolicyCatalog(policyCatalogId: string): Promise<void> {
        const pool = await poolPromise;
        await pool.query('SELECT sp_soft_delete_policy_catalog($1)', [policyCatalogId]);
    }

    public async softDeletePolicyCategory(categoryId: string): Promise<void> {
        const pool = await poolPromise;
        await pool.query('SELECT sp_soft_delete_policy_category($1)', [categoryId]);
    }

    public async softDeleteInsuranceCompany(companyId: string): Promise<void> {
        const pool = await poolPromise;
        await pool.query('SELECT sp_soft_delete_insurance_company($1)', [companyId]);
    }

    public async softDeleteClientPolicy(policyId: string): Promise<void> {
        const pool = await poolPromise;
        await pool.query('SELECT sp_soft_delete_client_policy($1)', [policyId]);
    }
    
    public async softDeletePolicyType(typeId: string): Promise<{ message: string }> {
        const pool = await poolPromise;
        await pool.query('SELECT sp_soft_delete_policy_type($1)', [typeId]);
        return { message: 'PolicyType soft deleted successfully' };
    }
}