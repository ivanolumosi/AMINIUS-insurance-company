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

/**
 * Get policy catalog - maps to sp_get_policy_catalog
 */
public async getPolicyCatalog(request: PolicyCatalogFilterRequest): Promise<PolicyCatalog[]> {
    const pool = await poolPromise;
    const result = await pool.query(
        `SELECT * FROM sp_get_policy_catalog($1,$2,$3,$4,$5,$6)`,
        [
            request.agentId || null,
            request.typeId || null,
            request.companyId || null,
            request.companyName || null,     // Now properly mapped
            request.searchTerm || null,      // Now properly mapped
            request.isActive !== undefined ? request.isActive : true
        ]
    );
    return result.rows.map(this.mapPolicyCatalogFromDb);
}

/**
 * Get clients with policies - maps to sp_get_clients_with_policies
 */
public async getClientsWithPolicies(
    request: ClientWithPoliciesFilterRequest
): Promise<ClientWithPolicies[]> {
    const pool = await poolPromise;
    const result = await pool.query(
        `SELECT * FROM sp_get_clients_with_policies($1,$2,$3)`,
        [
            request.agentId || null,
            request.clientId || null,
            request.includeInactive || false
        ]
    );
    return result.rows.map(this.mapClientWithPoliciesFromDb);
}
/**
 * Create policy catalog item - maps to sp_create_policy_catalog_item
 * Fixed parameter order to match stored procedure signature
 */
public async createPolicyCatalogItem(request: CreatePolicyCatalogRequest): Promise<CreateResponse> {
    const pool = await poolPromise;
    const result = await pool.query(
        `SELECT * FROM sp_create_policy_catalog_item($1,$2,$3,$4,$5,$6,$7)`,
        [
            request.agentId,
            request.policyName,
            request.typeId || null,      // Position 3: typeId
            request.companyId,           // Position 4: companyId  
            request.categoryId || null,  // Position 5: categoryId
            request.notes || null,       // Position 6: notes
            request.isActive !== undefined ? request.isActive : true // Position 7: isActive
        ]
    );

    const row = result.rows[0];
    if (row.error_message) throw new Error(row.error_message);

    return { id: row.policy_catalog_id };
}

/**
 * Update policy catalog item - maps to sp_update_policy_catalog_item
 * Fixed parameter order to match stored procedure signature
 */
public async updatePolicyCatalogItem(request: UpdatePolicyCatalogRequest): Promise<UpdateResponse> {
    const pool = await poolPromise;
    const result = await pool.query(
        `SELECT * FROM sp_update_policy_catalog_item($1,$2,$3,$4,$5,$6,$7,$8)`,
        [
            request.policyCatalogId,     // Position 1: policyCatalogId
            request.policyName || null,  // Position 2: policyName
            request.typeId || null,      // Position 3: typeId
            request.companyId || null,   // Position 4: companyId
            request.categoryId || null,  // Position 5: categoryId
            request.notes || null,       // Position 6: notes
            request.isActive !== undefined ? request.isActive : null, // Position 7: isActive
            request.agentId || null      // Position 8: agentId
        ]
    );

    const row = result.rows[0];
    if (row.error_message) throw new Error(row.error_message);

    return { rowsAffected: row.rows_affected };
}

/**
 * Delete policy catalog item - maps to sp_delete_policy_catalog_item
 */
public async deletePolicyCatalogItem(policyCatalogId: string, agentId: string): Promise<DeleteResponse> {
    const pool = await poolPromise;
    const result = await pool.query(
        `SELECT * FROM sp_delete_policy_catalog_item($1,$2)`,
        [policyCatalogId, agentId]
    );
    return { rowsAffected: result.rows[0].rows_affected };
}

/**
 * Upsert policy catalog - maps to sp_upsert_policy_catalog
 * Fixed parameter order to match stored procedure signature
 */
public async upsertPolicyCatalog(request: UpsertPolicyCatalogRequest): Promise<CreateResponse> {
    const pool = await poolPromise;
    const result = await pool.query(
        `SELECT * FROM sp_upsert_policy_catalog($1,$2,$3,$4,$5,$6,$7)`,
        [
            request.policyCatalogId || null, // Position 1: policyCatalogId
            request.agentId,                 // Position 2: agentId
            request.policyName,              // Position 3: policyName
            request.companyId,               // Position 4: companyId
            request.typeId || null,          // Position 5: typeId
            request.categoryId || null,      // Position 6: categoryId
            request.notes || null            // Position 7: notes
        ]
    );

    const row = result.rows[0];
    if (row.error_message) throw new Error(row.error_message);

    return { id: row.policy_catalog_id };
}




    // ============================================
    // CLIENT POLICIES MANAGEMENT
    // ============================================

    /**
     * Get client policies - maps to sp_get_client_policies (available but different signature)
     */
    public async getClientPolicies(request: ClientPolicyFilterRequest): Promise<ClientPolicy[]> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_get_client_policies($1,$2,$3,$4)',
            [
                request.clientId || null,      // p_client_id
                null,                          // p_agent_id (not in request interface)
                request.status || null,        // p_status
                request.isActive !== undefined ? request.isActive : true  // p_is_active
            ]
        );
        return result.rows.map(this.mapClientPolicyFromDb);
    }
    /**
     * Get policy by ID - MISSING STORED PROCEDURE
     * sp_get_policy_by_id exists in document 1 but not in document 2
     */
     public async getPolicyById(policyId: string): Promise<ClientPolicy | null> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_get_policy_by_id($1)',
            [policyId]
        );
        
        if (result.rows.length === 0) {
            return null;
        }
        
        return this.mapClientPolicyFromDb(result.rows[0]);
    }
    /**
     * Create client policy - maps to sp_create_client_policy (available but different signature)
     */
    public async createClientPolicy(request: any): Promise<{ id: string }> {
    const pool = await poolPromise;

    const result = await pool.query(
        `SELECT * FROM sp_create_client_policy(
            $1::uuid, 
            $2::varchar, 
            $3::date, 
            $4::date, 
            $5::varchar, 
            $6::text, 
            $7::uuid
        )`,
        [
            request.clientId,                           // $1
            request.policyName,                         // $2
            request.startDate,                          // $3
            request.endDate,                            // $4
            request.status || 'Active',                 // $5
            request.notes || null,                      // $6
            request.policyCatalogId || null             // $7
        ]
    );

    const row = result.rows[0];
    if (row.error_message) {
        throw new Error(row.error_message);
    }

    return { id: row.policy_id };
}

    /**
     * Update client policy - maps to sp_update_client_policy (available)
     */
    public async updateClientPolicy(request: UpdateClientPolicyRequest): Promise<UpdateResponse> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT rows_affected FROM sp_update_client_policy($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)',
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

    /**
     * Delete client policy - MISSING STORED PROCEDURE
     * No sp_delete_client_policy found in available SPs
     */
   public async deleteClientPolicy(policyId: string, hardDelete: boolean = false): Promise<DeleteResponse> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT rows_affected FROM sp_delete_client_policy($1,$2)',
            [policyId, hardDelete]
        );
        return {
            rowsAffected: result.rows[0].rows_affected
        };
    }

    /**
     * Upsert client policy - MISSING STORED PROCEDURE
     * No sp_upsert_client_policy found in available SPs
     */
    public async upsertClientPolicy(request: UpsertClientPolicyRequest): Promise<CreateResponse> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT policy_id FROM sp_upsert_client_policy($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)',
            [
                request.clientId,
                request.policyName,
                request.startDate,
                request.endDate,
                request.policyId || null,
                request.status || 'Active',
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
     private mapClientPolicyFromDb(row: any): ClientPolicy {
        return {
            policyId: row.policy_id,
            clientId: row.client_id,
            policyName: row.policy_name,
            status: row.status,
            startDate: new Date(row.start_date),
            endDate: new Date(row.end_date),
            notes: row.notes,
            createdDate: new Date(row.created_date),
            modifiedDate: row.modified_date ? new Date(row.modified_date) : undefined,
            isActive: row.is_active,
            policyCatalogId: row.policy_catalog_id,
            catalogPolicyName: row.catalog_policy_name,
            typeId: row.type_id,
            typeName: row.type_name,
            companyId: row.company_id,
            companyName: row.company_name,
            daysUntilExpiry: row.days_until_expiry
        };
    }
     private mapClientWithPoliciesFromDb(row: any): ClientWithPolicies {
        return {
            clientId: row.client_id,
            agentId: row.agent_id,
            firstName: row.first_name,
            surname: row.surname,
            lastName: row.last_name,
            fullName: row.full_name,
            phoneNumber: row.phone_number,
            email: row.email,
            address: row.address,
            nationalId: row.national_id,
            dateOfBirth: new Date(row.date_of_birth),
            isClient: row.is_client,
            insuranceType: row.insurance_type,
            clientNotes: row.client_notes,
            clientCreatedDate: new Date(row.client_created_date),
            clientModifiedDate: new Date(row.client_modified_date),
            clientIsActive: row.client_is_active,
            
            // Policy fields (may be null if no policies)
            policyId: row.policy_id,
            policyName: row.policy_name,
            status: row.status,
            startDate: row.start_date ? new Date(row.start_date) : undefined,
            endDate: row.end_date ? new Date(row.end_date) : undefined,
            policyNotes: row.policy_notes,
            policyCreatedDate: row.policy_created_date ? new Date(row.policy_created_date) : undefined,
            policyModifiedDate: row.policy_modified_date ? new Date(row.policy_modified_date) : undefined,
            policyIsActive: row.policy_is_active,
            policyCatalogId: row.policy_catalog_id,
            catalogPolicyName: row.catalog_policy_name,
            typeId: row.type_id,
            typeName: row.type_name,
            companyId: row.company_id,
            companyName: row.company_name,
            daysUntilExpiry: row.days_until_expiry
        };
    }
    /**
     * Get expiring policies - MISSING STORED PROCEDURE
     * No sp_get_expiring_policies found in available SPs
     */
    public async getExpiringPolicies(request: ExpiringPoliciesRequest): Promise<ClientPolicy[]> {
        throw new Error('sp_get_expiring_policies stored procedure is not available in the current database schema');
    }

    /**
     * Renew policy - MISSING STORED PROCEDURE
     * sp_renew_policy exists in document 1 but not in document 2
     */
    public async renewPolicy(request: PolicyRenewalRequest): Promise<RenewalResponse> {
        throw new Error('sp_renew_policy stored procedure is not available in the current database schema');
    }

    /**
     * Bulk update policy status - MISSING STORED PROCEDURE
     * sp_bulk_update_policy_status exists in document 1 but not in document 2
     */
    public async bulkUpdatePolicyStatus(request: BulkUpdatePolicyStatusRequest): Promise<UpdateResponse> {
        throw new Error('sp_bulk_update_policy_status stored procedure is not available in the current database schema');
    }

    // ============================================
    // POLICY SEARCH AND FILTERING
    // ============================================

    /**
     * Search policies - MISSING STORED PROCEDURE
     * sp_search_policies exists in document 1 but not in document 2
     */
    public async searchPolicies(request: SearchPoliciesRequest): Promise<PaginatedResponse<ClientPolicy>> {
        throw new Error('sp_search_policies stored procedure is not available in the current database schema');
    }

    /**
     * Get policies by status - MISSING STORED PROCEDURE
     * sp_get_policies_by_status exists in document 1 but not in document 2
     */
    public async getPoliciesByStatus(request: GetPoliciesByStatusRequest): Promise<ClientPolicy[]> {
        throw new Error('sp_get_policies_by_status stored procedure is not available in the current database schema');
    }

    // ============================================
    // POLICY TEMPLATES MANAGEMENT
    // ============================================

    /**
     * Get policy templates - CONFLICTING STORED PROCEDURES
     * Two different sp_get_policy_templates exist with different signatures
     */
    public async getPolicyTemplates(request: PolicyTemplateFilterRequest): Promise<PolicyTemplate[]> {
        // Using the signature from document 3 which seems more complete
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

    /**
     * Create policy template - CONFLICTING STORED PROCEDURES
     * Two different sp_create_policy_template exist with different signatures
     */
    public async createPolicyTemplate(request: CreatePolicyTemplateRequest): Promise<CreateResponse> {
        // Using the signature from document 3 which seems more complete
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

    /**
     * Update policy template - maps to sp_update_policy_template (available in document 3)
     */
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

    /**
     * Delete policy template - maps to sp_delete_policy_template (available in document 3)
     */
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

    /**
     * Get insurance companies - maps to sp_get_insurance_companies (available)
     */
    public async getInsuranceCompanies(isActive?: boolean): Promise<InsuranceCompany[]> {
    const pool = await poolPromise;
    const result = await pool.query(
        'SELECT * FROM sp_get_insurance_companies($1)',
        [isActive === undefined ? null : isActive] // pass null to get all
    );
    return result.rows.map(this.mapInsuranceCompanyFromDb);
}


    /**
     * Create insurance company - maps to sp_create_insurance_company (available)
     */
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

    /**
     * Update insurance company - maps to sp_update_insurance_company (available)
     */
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

    /**
     * Get policy types - WRONG FUNCTION NAME
     * Available: sp_get_policy_types_list, sp_get_policy_types_all
     * Your service calls: sp_get_policy_types (doesn't exist)
     */
    public async getPolicyTypes(isActive: boolean = true): Promise<PolicyType[]> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_get_policy_types_list($1)',
            [isActive]
        );
        return result.rows.map(this.mapPolicyTypeFromDb);
    }

    /**
     * Create policy type - WRONG FUNCTION NAME
     * Available: sp_create_policy_type_new
     * Your service calls: sp_create_policy_type (doesn't exist)
     */
    public async createPolicyType(request: CreatePolicyTypeRequest): Promise<CreateResponse> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT sp_create_policy_type_new($1) AS type_id',
            [request.typeName]
        );
        return {
            id: result.rows[0].type_id
        };
    }

    /**
     * Update policy type - maps to sp_update_policy_type_details (available)
     */
    public async updatePolicyType(request: UpdatePolicyTypeRequest): Promise<UpdateResponse> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT sp_update_policy_type_details($1,$2,$3) AS rows_affected',
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

    /**
     * Get policy categories - WRONG FUNCTION NAME
     * Available: sp_get_policy_categories_list
     * Your service calls: sp_get_policy_categories (doesn't exist)
     */
    public async getPolicyCategories(isActive: boolean = true): Promise<PolicyCategory[]> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_get_policy_categories_list($1)',
            [isActive]
        );
        return result.rows.map(this.mapPolicyCategoryFromDb);
    }

    /**
     * Create policy category - maps to sp_create_policy_category (available)
     */
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

    /**
     * Update policy category - maps to sp_update_policy_category_details (available)
     */
    public async updatePolicyCategory(request: UpdatePolicyCategoryRequest): Promise<UpdateResponse> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT sp_update_policy_category_details($1,$2,$3,$4) AS rows_affected',
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
    // ANALYTICS AND REPORTING - MISSING STORED PROCEDURES
    // ============================================

    /**
     * Get policy statistics - MISSING STORED PROCEDURE
     * sp_get_policy_statistics exists in document 1 but not in current schema
     */
    public async getPolicyStatistics(request: PolicyStatisticsRequest): Promise<PolicyStatistics> {
        throw new Error('sp_get_policy_statistics stored procedure is not available in the current database schema');
    }

    /**
     * Get detailed policy statistics - MISSING STORED PROCEDURE
     * sp_get_policy_statistics_detailed exists in document 1 but not in current schema
     */
    public async getPolicyStatisticsDetailed(request: PolicyStatisticsRequest): Promise<PolicyStatisticsDetailed[]> {
        throw new Error('sp_get_policy_statistics_detailed stored procedure is not available in the current database schema');
    }

    /**
     * Get agent dashboard summary - maps to sp_get_agent_dashboard_summary (available)
     */
    public async getAgentDashboardSummary(agentId: string): Promise<AgentDashboardSummary> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_get_agent_dashboard_summary($1)',
            [agentId]
        );
        return this.mapAgentDashboardSummaryFromDb(result.rows[0]);
    }

    /**
     * Get policy renewal candidates - maps to sp_get_policy_renewal_candidates (available)
     */
    public async getPolicyRenewalCandidates(request: GetRenewalCandidatesRequest): Promise<PolicyRenewalCandidate[]> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_get_policy_renewal_candidates($1,$2)',
            [request.agentId || null, request.daysAhead || 60]
        );
        return result.rows.map(this.mapPolicyRenewalCandidateFromDb);
    }

    /**
     * Get policy history - maps to sp_get_policy_history_for_client (available)
     */
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

    /**
     * Batch expire policies - maps to sp_batch_expire_policies (available)
     */
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

    /**
     * Cleanup soft deleted records - maps to sp_cleanup_soft_deleted_records (available)
     */
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

    

    private mapPolicyCatalogFromDb(row: any): PolicyCatalog {
        return {
            policyId: row.policy_catalog_id,
            agentId: row.agent_id,
            policyName: row.policy_name,
            companyId: row.company_id,
            companyName: row.company_name,
            notes: row.notes,
            isActive: row.is_active,
            createdDate: new Date(row.created_date),
            modifiedDate: row.modified_date ? new Date(row.modified_date) : undefined,
            categoryId: row.category_id,
            categoryName: row.category_name,
            typeId: row.type_id,
            typeName: row.type_name
        };
    }

 

    private mapPolicyTemplateFromDb(row: any): PolicyTemplate {
        return {
            templateId: row.template_id,
            agentId: row.agent_id,
            templateName: row.template_name,
            defaultTermMonths: row.default_term_months,
            defaultPremium: row.default_premium,
            coverageDescription: row.coverage_description,
            terms: row.terms,
            isActive: row.is_active,
            createdDate: new Date(row.created_date),
            categoryId: row.category_id,
            categoryName: row.category_name,
            policyCatalogId: row.policy_catalog_id,
            catalogPolicyName: row.catalog_policy_name,
            typeId: row.type_id,
            typeName: row.type_name
        };
    }

    private mapInsuranceCompanyFromDb(row: any): InsuranceCompany {
        return {
            companyId: row.company_id,
            companyName: row.company_name,
            isActive: row.is_active,
            createdDate: new Date(row.created_date)
        };
    }

    private mapPolicyTypeFromDb(row: any): PolicyType {
        return {
            typeId: row.type_id,
            typeName: row.type_name,
            isActive: row.is_active,
            createdDate: new Date(row.created_date)
        };
    }

    private mapPolicyCategoryFromDb(row: any): PolicyCategory {
        return {
            categoryId: row.category_id,
            categoryName: row.category_name,
            description: row.description,
            isActive: row.is_active,
            createdDate: new Date(row.created_date)
        };
    }

    private mapPolicyStatisticsFromDb(row: any): PolicyStatistics {
        return {
            totalPolicies: row.total_policies,
            activePolicies: row.active_policies,
            expiredPolicies: row.expired_policies,
            cancelledPolicies: row.cancelled_policies,
            expiringIn30Days: row.expiring_in_30_days,
            expiringIn60Days: row.expiring_in_60_days
        };
    }

    private mapPolicyStatisticsDetailedFromDb(row: any): PolicyStatisticsDetailed {
        return {
            groupType: row.group_type,
            groupName: row.group_name,
            policyCount: row.policy_count,
            activeCount: row.active_count
        };
    }

    private mapAgentDashboardSummaryFromDb(row: any): AgentDashboardSummary {
        return {
            totalPolicies: row.total_policies,
            activePolicies: row.active_policies,
            expiringIn30Days: row.expiring_in_30_days,
            expiringIn60Days: row.expiring_in_60_days,
            totalCompanies: row.total_companies,
            totalClients: row.total_clients,
            inactivePolicies: row.inactive_policies
        };
    }

    private mapPolicyRenewalCandidateFromDb(row: any): PolicyRenewalCandidate {
        return {
            policyId: row.policy_id,
            clientId: row.client_id,
            policyName: row.policy_name,
            status: row.status,
            startDate: new Date(row.start_date),
            endDate: new Date(row.end_date),
            companyId: row.company_id,
            companyName: row.company_name,
            typeId: row.type_id,
            typeName: row.type_name,
            daysUntilExpiry: row.days_until_expiry,
            renewalPriority: row.renewal_priority as 'Urgent' | 'Soon' | 'Upcoming'
        };
    }

    private mapPolicyHistoryFromDb(row: any): PolicyHistory {
        return {
            policyId: row.policy_id,
            clientId: row.client_id,
            policyName: row.policy_name,
            status: row.status,
            startDate: new Date(row.start_date),
            endDate: new Date(row.end_date),
            notes: row.notes,
            createdDate: new Date(row.created_date),
            modifiedDate: row.modified_date ? new Date(row.modified_date) : undefined,
            companyId: row.company_id,
            companyName: row.company_name,
            typeId: row.type_id,
            typeName: row.type_name,
            policyDurationDays: row.policy_duration_days,
            policyState: row.policy_state
        };
    }

    // ============================================
    // VALIDATION METHODS
    // ============================================

    public async validatePolicy(request: PolicyValidationRequest): Promise<PolicyValidationResponse> {
        const errors: string[] = [];
        const warnings: string[] = [];

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
    // VALIDATION USING DATABASE SP
    // ============================================

    /**
     * Validate policy data using database stored procedure - maps to sp_validate_policy_data (available)
     */
    public async validatePolicyData(
        policyName: string,
        policyType: string,
        companyId?: string,
        startDate?: Date,
        endDate?: Date
    ): Promise<{isValid: boolean, validationErrors: string}> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_validate_policy_data($1,$2,$3,$4,$5)',
            [
                policyName,
                policyType,
                companyId || null,
                startDate || null,
                endDate || null
            ]
        );
        
        return {
            isValid: result.rows[0].is_valid,
            validationErrors: result.rows[0].validation_errors
        };
    }

    // ============================================
    // SOFT DELETE METHODS
    // ============================================

    public async softDeleteClientPolicy(policyId: string): Promise<{success: number, message: string}> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_soft_delete_client_policy($1)',
            [policyId]
        );
        return {
            success: result.rows[0].success,
            message: result.rows[0].message
        };
    }

    public async softDeleteInsuranceCompany(companyId: string): Promise<{success: number, message: string}> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_soft_delete_insurance_company($1)',
            [companyId]
        );
        return {
            success: result.rows[0].success,
            message: result.rows[0].message
        };
    }

    public async softDeletePolicyCatalog(policyCatalogId: string): Promise<{success: number, message: string}> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_soft_delete_policy_catalog($1)',
            [policyCatalogId]
        );
        return {
            success: result.rows[0].success,
            message: result.rows[0].message
        };
    }

    public async softDeletePolicyCategory(categoryId: string): Promise<{success: number, message: string}> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_soft_delete_policy_category($1)',
            [categoryId]
        );
        return {
            success: result.rows[0].success,
            message: result.rows[0].message
        };
    }

    public async softDeletePolicyTemplate(templateId: string): Promise<{success: number, message: string}> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_soft_delete_policy_template($1)',
            [templateId]
        );
        return {
            success: result.rows[0].success,
            message: result.rows[0].message
        };
    }

    public async softDeletePolicyType(typeId: string): Promise<{success: number, message: string}> {
        const pool = await poolPromise;
        const result = await pool.query(
            'SELECT * FROM sp_soft_delete_policy_type($1)',
            [typeId]
        );
        return {
            success: result.rows[0].success,
            message: result.rows[0].message
        };
    }

    // ============================================
    // ERROR HANDLING WRAPPER METHODS
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
}