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
    PolicyValidationResponse,
    ClientPolicyLite
} from '../interfaces/policy';

// Updated interface to match frontend expectations
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
    policies: ClientPolicyLite[];
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
     * Get policy catalog - Fixed to return PolicyResponse format expected by frontend
     */
    public async getPolicyCatalog(request: PolicyCatalogFilterRequest): Promise<PolicyResponse<PolicyCatalog[]>> {
        try {
            const pool = await poolPromise;
            const result = await pool.query(
                `SELECT * FROM sp_get_policy_catalog($1,$2,$3,$4,$5,$6)`,
                [
                    request.agentId || null,
                    request.typeId || null,
                    request.companyId || null,
                    request.companyName || null,
                    request.searchTerm || null,
                    request.isActive !== undefined ? request.isActive : true
                ]
            );
            
            const data = result.rows.map(this.mapPolicyCatalogFromDb);
            return {
                success: true,
                data,
                message: 'Policy catalog retrieved successfully'
            };
        } catch (error) {
            console.error('Error in getPolicyCatalog:', error);
            return {
                success: false,
                message: error instanceof Error ? error.message : 'Failed to get policy catalog'
            };
        }
    }
/**
 * Get clients with policies - Fixed to return array directly to match frontend expectations
 */
public async getClientsWithPolicies(
  request: ClientWithPoliciesFilterRequest
): Promise<any[]> {
  try {
    const pool = await poolPromise;
    const result = await pool.query(
      `SELECT * FROM sp_get_clients_with_policies($1,$2,$3)`,
      [request.agentId || null, request.clientId || null, request.includeInactive || false]
    );

    // Map to the nested structure first
    const nestedData = this.mapClientsWithPolicies(result.rows);
    
    // Flatten the data to match frontend expectations
    const flattenedData: any[] = [];
    
    nestedData.forEach(client => {
      if (client.policies && client.policies.length > 0) {
        // For each policy, create a flattened row with both client and policy data
        client.policies.forEach(policy => {
          flattenedData.push({
            // Client data
            clientId: client.clientId,
            agentId: client.agentId,
            firstName: client.firstName,
            surname: client.surname,
            lastName: client.lastName,
            fullName: client.fullName,
            phoneNumber: client.phoneNumber,
            email: client.email,
            address: client.address,
            nationalId: client.nationalId,
            dateOfBirth: client.dateOfBirth,
            isClient: client.isClient,
            insuranceType: client.insuranceType,
            clientNotes: client.clientNotes,
            clientCreatedDate: client.clientCreatedDate,
            clientModifiedDate: client.clientModifiedDate,
            clientIsActive: client.clientIsActive,
            
            // Policy data (flattened to root level to match frontend processing)
            policyId: policy.policyId,
            policyName: policy.policyName,
            status: policy.status,
            startDate: policy.startDate,
            endDate: policy.endDate,
            notes: policy.notes, // Policy notes
            policyCreatedDate: policy.createdDate,
            policyModifiedDate: policy.modifiedDate,
            policyIsActive: policy.isActive,
            policyCatalogId: policy.policyCatalogId,
            catalogPolicyName: policy.catalogPolicyName,
            typeId: policy.typeId,
            typeName: policy.typeName,
            companyId: policy.companyId,
            companyName: policy.companyName,
            daysUntilExpiry: policy.daysUntilExpiry
          });
        });
      } else {
        // Client with no policies - still include the client data
        flattenedData.push({
          // Client data
          clientId: client.clientId,
          agentId: client.agentId,
          firstName: client.firstName,
          surname: client.surname,
          lastName: client.lastName,
          fullName: client.fullName,
          phoneNumber: client.phoneNumber,
          email: client.email,
          address: client.address,
          nationalId: client.nationalId,
          dateOfBirth: client.dateOfBirth,
          isClient: client.isClient,
          insuranceType: client.insuranceType,
          clientNotes: client.clientNotes,
          clientCreatedDate: client.clientCreatedDate,
          clientModifiedDate: client.clientModifiedDate,
          clientIsActive: client.clientIsActive,
          
          // No policy data for clients without policies
          policyId: null,
          policyName: null,
          status: null,
          startDate: null,
          endDate: null,
          notes: null,
          policyCreatedDate: null,
          policyModifiedDate: null,
          policyIsActive: null,
          policyCatalogId: null,
          catalogPolicyName: null,
          typeId: null,
          typeName: null,
          companyId: null,
          companyName: null,
          daysUntilExpiry: null
        });
      }
    });

    console.log("Flattened data being returned:", flattenedData);
    return flattenedData;
  } catch (error) {
    console.error("Error in getClientsWithPolicies:", error);
    throw new Error(error instanceof Error ? error.message : "Failed to get clients with policies");
  }
}

private mapClientsWithPolicies(rows: any[]): ClientWithPolicies[] {
  const clientMap: Map<string, ClientWithPolicies> = new Map();

  rows.forEach(row => {
    if (!clientMap.has(row.client_id)) {
      clientMap.set(row.client_id, {
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
        dateOfBirth: row.date_of_birth,
        isClient: row.is_client,
        insuranceType: row.insurance_type,
        clientNotes: row.client_notes,
        clientCreatedDate: row.client_created_date,
        clientModifiedDate: row.client_modified_date,
        clientIsActive: row.client_is_active,
        policies: []
      });
    }

    if (row.policy_id) {
      clientMap.get(row.client_id)!.policies.push({
        policyId: row.policy_id,
        policyName: row.policy_name,
        status: row.status,
        startDate: row.start_date,
        endDate: row.end_date,
        notes: row.policy_notes,
        createdDate: row.policy_created_date,
        modifiedDate: row.policy_modified_date,
        isActive: row.policy_is_active,
        policyCatalogId: row.policy_catalog_id,
        catalogPolicyName: row.catalog_policy_name,
        typeId: row.type_id,
        typeName: row.type_name,
        companyId: row.company_id,
        companyName: row.company_name,
        daysUntilExpiry: row.days_until_expiry
      });
    }
  });

  return Array.from(clientMap.values());
}


    /**
     * Create policy catalog item - Fixed to return PolicyResponse format
     */
    public async createPolicyCatalogItem(request: CreatePolicyCatalogRequest): Promise<PolicyResponse<CreateResponse>> {
        try {
            const pool = await poolPromise;
            const result = await pool.query(
                `SELECT * FROM sp_create_policy_catalog_item($1,$2,$3,$4,$5,$6,$7)`,
                [
                    request.agentId,
                    request.policyName,
                    request.typeId || null,
                    request.companyId,
                    request.categoryId || null,
                    request.notes || null,
                    request.isActive !== undefined ? request.isActive : true
                ]
            );

            const row = result.rows[0];
            if (row.error_message) {
                throw new Error(row.error_message);
            }

            return {
                success: true,
                data: { id: row.policy_catalog_id },
                message: 'Policy catalog item created successfully'
            };
        } catch (error) {
            console.error('Error in createPolicyCatalogItem:', error);
            return {
                success: false,
                message: error instanceof Error ? error.message : 'Failed to create policy catalog item'
            };
        }
    }

    /**
     * Update policy catalog item - Fixed to return PolicyResponse format
     */
    public async updatePolicyCatalogItem(request: UpdatePolicyCatalogRequest): Promise<PolicyResponse<UpdateResponse>> {
        try {
            const pool = await poolPromise;
            const result = await pool.query(
                `SELECT * FROM sp_update_policy_catalog_item($1,$2,$3,$4,$5,$6,$7,$8)`,
                [
                    request.policyCatalogId,
                    request.policyName || null,
                    request.typeId || null,
                    request.companyId || null,
                    request.categoryId || null,
                    request.notes || null,
                    request.isActive !== undefined ? request.isActive : null,
                    request.agentId || null
                ]
            );

            const row = result.rows[0];
            if (row.error_message) {
                throw new Error(row.error_message);
            }

            return {
                success: true,
                data: { rowsAffected: row.rows_affected },
                message: 'Policy catalog item updated successfully'
            };
        } catch (error) {
            console.error('Error in updatePolicyCatalogItem:', error);
            return {
                success: false,
                message: error instanceof Error ? error.message : 'Failed to update policy catalog item'
            };
        }
    }

    /**
     * Upsert policy catalog - Fixed to return PolicyResponse format
     */
    public async upsertPolicyCatalog(request: UpsertPolicyCatalogRequest): Promise<PolicyResponse<CreateResponse>> {
        try {
            const pool = await poolPromise;
            const result = await pool.query(
                `SELECT * FROM sp_upsert_policy_catalog($1,$2,$3,$4,$5,$6,$7)`,
                [
                    request.policyCatalogId || null,
                    request.agentId,
                    request.policyName,
                    request.companyId,
                    request.typeId || null,
                    request.categoryId || null,
                    request.notes || null
                ]
            );

            const row = result.rows[0];
            if (row.error_message) {
                throw new Error(row.error_message);
            }

            return {
                success: true,
                data: { id: row.policy_catalog_id },
                message: 'Policy catalog upserted successfully'
            };
        } catch (error) {
            console.error('Error in upsertPolicyCatalog:', error);
            return {
                success: false,
                message: error instanceof Error ? error.message : 'Failed to upsert policy catalog'
            };
        }
    }

    /**
     * Delete policy catalog item - Fixed to return PolicyResponse format
     */
    public async deletePolicyCatalogItem(policyCatalogId: string, agentId: string): Promise<PolicyResponse<DeleteResponse>> {
        try {
            const pool = await poolPromise;
            const result = await pool.query(
                `SELECT * FROM sp_delete_policy_catalog_item($1,$2)`,
                [policyCatalogId, agentId]
            );
            
            return {
                success: true,
                data: { rowsAffected: result.rows[0].rows_affected },
                message: 'Policy catalog item deleted successfully'
            };
        } catch (error) {
            console.error('Error in deletePolicyCatalogItem:', error);
            return {
                success: false,
                message: error instanceof Error ? error.message : 'Failed to delete policy catalog item'
            };
        }
    }

    // ============================================
    // CLIENT POLICIES MANAGEMENT
    // ============================================

    /**
     * Get client policies - Fixed to return PolicyResponse format
     */
    public async getClientPolicies(request: ClientPolicyFilterRequest): Promise<PolicyResponse<ClientPolicy[]>> {
        try {
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
            
            const data = result.rows.map(this.mapClientPolicyFromDb);
            return {
                success: true,
                data,
                message: 'Client policies retrieved successfully'
            };
        } catch (error) {
            console.error('Error in getClientPolicies:', error);
            return {
                success: false,
                data: [],
                message: error instanceof Error ? error.message : 'Failed to get client policies'
            };
        }
    }

    /**
     * Get policy by ID - Fixed to return PolicyResponse format
     */
    public async getPolicyById(policyId: string): Promise<PolicyResponse<ClientPolicy | null>> {
        try {
            const pool = await poolPromise;
            const result = await pool.query(
                'SELECT * FROM sp_get_policy_by_id($1)',
                [policyId]
            );
            
            if (result.rows.length === 0) {
                return {
                    success: false,
                    data: null,
                    message: 'Policy not found'
                };
            }
            
            return {
                success: true,
                data: this.mapClientPolicyFromDb(result.rows[0]),
                message: 'Policy retrieved successfully'
            };
        } catch (error) {
            console.error('Error in getPolicyById:', error);
            return {
                success: false,
                data: null,
                message: error instanceof Error ? error.message : 'Failed to get policy'
            };
        }
    }

    /**
     * Create client policy - Fixed to return PolicyResponse format
     */
    public async createClientPolicy(request: CreateClientPolicyRequest): Promise<PolicyResponse<CreateResponse>> {
        try {
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
                    request.clientId,
                    request.policyName,
                    request.startDate,
                    request.endDate,
                    request.status || 'Active',
                    request.notes || null,
                    request.policyCatalogId || null
                ]
            );

            const row = result.rows[0];
            if (row.error_message) {
                throw new Error(row.error_message);
            }

            return {
                success: true,
                data: { id: row.policy_id },
                message: 'Client policy created successfully'
            };
        } catch (error) {
            console.error('Error in createClientPolicy:', error);
            return {
                success: false,
                message: error instanceof Error ? error.message : 'Failed to create client policy'
            };
        }
    }

    /**
     * Update client policy - Fixed to return PolicyResponse format
     */
    public async updateClientPolicy(request: UpdateClientPolicyRequest): Promise<PolicyResponse<UpdateResponse>> {
        try {
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
                success: true,
                data: { rowsAffected: result.rows[0].rows_affected },
                message: 'Client policy updated successfully'
            };
        } catch (error) {
            console.error('Error in updateClientPolicy:', error);
            return {
                success: false,
                message: error instanceof Error ? error.message : 'Failed to update client policy'
            };
        }
    }

    /**
     * Upsert client policy - Fixed to return PolicyResponse format
     */
    public async upsertClientPolicy(request: UpsertClientPolicyRequest): Promise<PolicyResponse<CreateResponse>> {
        try {
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
                success: true,
                data: { id: result.rows[0].policy_id },
                message: 'Client policy upserted successfully'
            };
        } catch (error) {
            console.error('Error in upsertClientPolicy:', error);
            return {
                success: false,
                message: error instanceof Error ? error.message : 'Failed to upsert client policy'
            };
        }
    }

    /**
     * Delete client policy - Fixed to return PolicyResponse format
     */
    public async deleteClientPolicy(policyId: string, hardDelete: boolean = false): Promise<PolicyResponse<DeleteResponse>> {
        try {
            const pool = await poolPromise;
            const result = await pool.query(
                'SELECT rows_affected FROM sp_delete_client_policy($1,$2)',
                [policyId, hardDelete]
            );
            
            return {
                success: true,
                data: { rowsAffected: result.rows[0].rows_affected },
                message: 'Client policy deleted successfully'
            };
        } catch (error) {
            console.error('Error in deleteClientPolicy:', error);
            return {
                success: false,
                message: error instanceof Error ? error.message : 'Failed to delete client policy'
            };
        }
    }

    // ============================================
    // REFERENCE DATA MANAGEMENT
    // ============================================

    /**
     * Get insurance companies - Fixed to return PolicyResponse format expected by frontend
     */
    public async getInsuranceCompanies(isActive?: boolean): Promise<PolicyResponse<InsuranceCompany[]>> {
        try {
            const pool = await poolPromise;
            const result = await pool.query(
                'SELECT * FROM sp_get_insurance_companies($1)',
                [isActive === undefined ? null : isActive]
            );
            
            const data = result.rows.map(this.mapInsuranceCompanyFromDb);
            return {
                success: true,
                data,
                message: 'Insurance companies retrieved successfully'
            };
        } catch (error) {
            console.error('Error in getInsuranceCompanies:', error);
            return {
                success: false,
                data: [],
                message: error instanceof Error ? error.message : 'Failed to get insurance companies'
            };
        }
    }

    /**
     * Create insurance company - Fixed to return PolicyResponse format
     */
    public async createInsuranceCompany(request: CreateInsuranceCompanyRequest): Promise<PolicyResponse<CreateResponse>> {
        try {
            const pool = await poolPromise;
            const result = await pool.query(
                'SELECT sp_create_insurance_company($1) AS company_id',
                [request.companyName]
            );
            
            return {
                success: true,
                data: { id: result.rows[0].company_id },
                message: 'Insurance company created successfully'
            };
        } catch (error) {
            console.error('Error in createInsuranceCompany:', error);
            return {
                success: false,
                message: error instanceof Error ? error.message : 'Failed to create insurance company'
            };
        }
    }

    /**
     * Update insurance company - Fixed to return PolicyResponse format
     */
    public async updateInsuranceCompany(request: UpdateInsuranceCompanyRequest): Promise<PolicyResponse<UpdateResponse>> {
        try {
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
                success: true,
                data: { rowsAffected: result.rows[0].rows_affected },
                message: 'Insurance company updated successfully'
            };
        } catch (error) {
            console.error('Error in updateInsuranceCompany:', error);
            return {
                success: false,
                message: error instanceof Error ? error.message : 'Failed to update insurance company'
            };
        }
    }

    /**
     * Get policy types - Fixed function name and return format
     */
    public async getPolicyTypes(isActive: boolean = true): Promise<PolicyResponse<PolicyType[]>> {
        try {
            const pool = await poolPromise;
            const result = await pool.query(
                'SELECT * FROM sp_get_policy_types_list($1)',
                [isActive]
            );
            
            const data = result.rows.map(this.mapPolicyTypeFromDb);
            return {
                success: true,
                data,
                message: 'Policy types retrieved successfully'
            };
        } catch (error) {
            console.error('Error in getPolicyTypes:', error);
            return {
                success: false,
                data: [],
                message: error instanceof Error ? error.message : 'Failed to get policy types'
            };
        }
    }

    /**
     * Create policy type - Fixed function name and return format
     */
    public async createPolicyType(request: CreatePolicyTypeRequest): Promise<PolicyResponse<CreateResponse>> {
        try {
            const pool = await poolPromise;
            const result = await pool.query(
                'SELECT sp_create_policy_type_new($1) AS type_id',
                [request.typeName]
            );
            
            return {
                success: true,
                data: { id: result.rows[0].type_id },
                message: 'Policy type created successfully'
            };
        } catch (error) {
            console.error('Error in createPolicyType:', error);
            return {
                success: false,
                message: error instanceof Error ? error.message : 'Failed to create policy type'
            };
        }
    }

    /**
     * Update policy type - Fixed to return PolicyResponse format
     */
    public async updatePolicyType(request: UpdatePolicyTypeRequest): Promise<PolicyResponse<UpdateResponse>> {
        try {
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
                success: true,
                data: { rowsAffected: result.rows[0].rows_affected },
                message: 'Policy type updated successfully'
            };
        } catch (error) {
            console.error('Error in updatePolicyType:', error);
            return {
                success: false,
                message: error instanceof Error ? error.message : 'Failed to update policy type'
            };
        }
    }

    /**
     * Get policy categories - Fixed function name and return format
     */
    public async getPolicyCategories(isActive: boolean = true): Promise<PolicyResponse<PolicyCategory[]>> {
        try {
            const pool = await poolPromise;
            const result = await pool.query(
                'SELECT * FROM sp_get_policy_categories_list($1)',
                [isActive]
            );
            
            const data = result.rows.map(this.mapPolicyCategoryFromDb);
            return {
                success: true,
                data,
                message: 'Policy categories retrieved successfully'
            };
        } catch (error) {
            console.error('Error in getPolicyCategories:', error);
            return {
                success: false,
                data: [],
                message: error instanceof Error ? error.message : 'Failed to get policy categories'
            };
        }
    }

    /**
     * Create policy category - Fixed to return PolicyResponse format
     */
    public async createPolicyCategory(request: CreatePolicyCategoryRequest): Promise<PolicyResponse<CreateResponse>> {
        try {
            const pool = await poolPromise;
            const result = await pool.query(
                'SELECT sp_create_policy_category($1,$2) AS category_id',
                [request.categoryName, request.description || null]
            );
            
            return {
                success: true,
                data: { id: result.rows[0].category_id },
                message: 'Policy category created successfully'
            };
        } catch (error) {
            console.error('Error in createPolicyCategory:', error);
            return {
                success: false,
                message: error instanceof Error ? error.message : 'Failed to create policy category'
            };
        }
    }

    /**
     * Update policy category - Fixed to return PolicyResponse format
     */
    public async updatePolicyCategory(request: UpdatePolicyCategoryRequest): Promise<PolicyResponse<UpdateResponse>> {
        try {
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
                success: true,
                data: { rowsAffected: result.rows[0].rows_affected },
                message: 'Policy category updated successfully'
            };
        } catch (error) {
            console.error('Error in updatePolicyCategory:', error);
            return {
                success: false,
                message: error instanceof Error ? error.message : 'Failed to update policy category'
            };
        }
    }

    // ============================================
    // ANALYTICS AND REPORTING - IMPLEMENTED WITH FALLBACKS
    // ============================================

    /**
     * Get agent dashboard summary - Fixed to return PolicyResponse format
     */
    public async getAgentDashboardSummary(agentId: string): Promise<PolicyResponse<AgentDashboardSummary>> {
        try {
            const pool = await poolPromise;
            const result = await pool.query(
                'SELECT * FROM sp_get_agent_dashboard_summary($1)',
                [agentId]
            );
            
            const data = this.mapAgentDashboardSummaryFromDb(result.rows[0]);
            return {
                success: true,
                data,
                message: 'Agent dashboard summary retrieved successfully'
            };
        } catch (error) {
            console.error('Error in getAgentDashboardSummary:', error);
            return {
                success: false,
                message: error instanceof Error ? error.message : 'Failed to get agent dashboard summary'
            };
        }
    }

    /**
     * Get policy renewal candidates - Fixed to return PolicyResponse format
     */
    public async getPolicyRenewalCandidates(request: GetRenewalCandidatesRequest): Promise<PolicyResponse<PolicyRenewalCandidate[]>> {
        try {
            const pool = await poolPromise;
            const result = await pool.query(
                'SELECT * FROM sp_get_policy_renewal_candidates($1,$2)',
                [request.agentId || null, request.daysAhead || 60]
            );
            
            const data = result.rows.map(this.mapPolicyRenewalCandidateFromDb);
            return {
                success: true,
                data,
                message: 'Policy renewal candidates retrieved successfully'
            };
        } catch (error) {
            console.error('Error in getPolicyRenewalCandidates:', error);
            return {
                success: false,
                data: [],
                message: error instanceof Error ? error.message : 'Failed to get policy renewal candidates'
            };
        }
    }

    /**
     * Get policy history - Fixed to return PolicyResponse format
     */
    public async getPolicyHistory(request: GetPolicyHistoryRequest): Promise<PolicyResponse<PolicyHistory[]>> {
        try {
            const pool = await poolPromise;
            const result = await pool.query(
                'SELECT * FROM sp_get_policy_history_for_client($1,$2)',
                [request.clientId, request.includeInactive || false]
            );
            
            const data = result.rows.map(this.mapPolicyHistoryFromDb);
            return {
                success: true,
                data,
                message: 'Policy history retrieved successfully'
            };
        } catch (error) {
            console.error('Error in getPolicyHistory:', error);
            return {
                success: false,
                data: [],
                message: error instanceof Error ? error.message : 'Failed to get policy history'
            };
        }
    }

    // ============================================
    // MISSING STORED PROCEDURES - IMPLEMENT WITH FALLBACKS
    // ============================================

    /**
     * Get expiring policies - IMPLEMENTED FALLBACK since SP is missing
     */
    public async getExpiringPolicies(request: ExpiringPoliciesRequest): Promise<PolicyResponse<ClientPolicy[]>> {
        try {
            // Since sp_get_expiring_policies doesn't exist, implement fallback logic
            const pool = await poolPromise;
            const daysAhead = request.daysAhead || 30;
            
            // Manual query for expiring policies
            const result = await pool.query(`
                SELECT p.*, 
                       pc.policy_name as catalog_policy_name,
                       pt.type_name,
                       ic.company_name,
                       (p.end_date::date - CURRENT_DATE) as days_until_expiry
                FROM client_policies p
                LEFT JOIN policy_catalog pc ON p.policy_catalog_id = pc.policy_catalog_id
                LEFT JOIN policy_types pt ON pc.type_id = pt.type_id
                LEFT JOIN insurance_companies ic ON pc.company_id = ic.company_id
                WHERE p.is_active = true 
                  AND p.end_date::date BETWEEN CURRENT_DATE AND (CURRENT_DATE + INTERVAL '${daysAhead} days')
                  ${request.agentId ? 'AND pc.agent_id = $1' : ''}
                  ${request.status ? `AND p.status = '${request.status}'` : ''}
                ORDER BY p.end_date ASC
            `, request.agentId ? [request.agentId] : []);
            
            const data = result.rows.map(this.mapClientPolicyFromDb);
            return {
                success: true,
                data,
                message: 'Expiring policies retrieved successfully'
            };
        } catch (error) {
            console.error('Error in getExpiringPolicies:', error);
            return {
                success: false,
                data: [],
                message: error instanceof Error ? error.message : 'Failed to get expiring policies'
            };
        }
    }

    /**
     * Search policies - IMPLEMENTED FALLBACK since SP is missing
     */
    public async searchPolicies(request: SearchPoliciesRequest): Promise<PolicyResponse<PaginatedResponse<ClientPolicy>>> {
        try {
            const pool = await poolPromise;
            const pageSize = request.pageSize || 10;
            const pageNumber = request.pageNumber || 1;
            const offset = (pageNumber - 1) * pageSize;

            let whereClause = 'WHERE p.is_active = true';
            const params: any[] = [];
            let paramIndex = 1;

            if (request.agentId) {
                whereClause += ` AND pc.agent_id = $${paramIndex}`;
                params.push(request.agentId);
                paramIndex++;
            }

            if (request.searchTerm) {
                whereClause += ` AND (p.policy_name ILIKE $${paramIndex} OR ic.company_name ILIKE $${paramIndex})`;
                params.push(`%${request.searchTerm}%`);
                paramIndex++;
            }

            if (request.status) {
                whereClause += ` AND p.status = ${paramIndex}`;
                params.push(request.status);
                paramIndex++;
            }

            if (request.clientId) {
                whereClause += ` AND p.client_id = ${paramIndex}`;
                params.push(request.clientId);
                paramIndex++;
            }

            const query = `
                SELECT p.*, 
                       pc.policy_name as catalog_policy_name,
                       pt.type_name,
                       ic.company_name,
                       (p.end_date::date - CURRENT_DATE) as days_until_expiry,
                       COUNT(*) OVER() as total_count
                FROM client_policies p
                LEFT JOIN policy_catalog pc ON p.policy_catalog_id = pc.policy_catalog_id
                LEFT JOIN policy_types pt ON pc.type_id = pt.type_id
                LEFT JOIN insurance_companies ic ON pc.company_id = ic.company_id
                ${whereClause}
                ORDER BY p.created_date DESC
                LIMIT ${paramIndex} OFFSET ${paramIndex + 1}
            `;

            params.push(pageSize, offset);
            const result = await pool.query(query, params);
            
            const data = result.rows.map(this.mapClientPolicyFromDb);
            const total = result.rows.length > 0 ? parseInt(result.rows[0].total_count) : 0;

            return {
                success: true,
                data: {
                    data,
                    total,
                    pageNumber,
                    pageSize,
                    hasNextPage: (pageNumber * pageSize) < total,
                    hasPreviousPage: pageNumber > 1
                },
                message: 'Policies searched successfully'
            };
        } catch (error) {
            console.error('Error in searchPolicies:', error);
            return {
                success: false,
                data: {
                    data: [],
                    total: 0,
                    pageNumber: 1,
                    pageSize: 10,
                    hasNextPage: false,
                    hasPreviousPage: false
                },
                message: error instanceof Error ? error.message : 'Failed to search policies'
            };
        }
    }

    /**
     * Get policies by status - IMPLEMENTED FALLBACK since SP is missing
     */
    public async getPoliciesByStatus(request: GetPoliciesByStatusRequest): Promise<PolicyResponse<ClientPolicy[]>> {
        try {
            const pool = await poolPromise;
            let query = `
                SELECT p.*, 
                       pc.policy_name as catalog_policy_name,
                       pt.type_name,
                       ic.company_name,
                       (p.end_date::date - CURRENT_DATE) as days_until_expiry
                FROM client_policies p
                LEFT JOIN policy_catalog pc ON p.policy_catalog_id = pc.policy_catalog_id
                LEFT JOIN policy_types pt ON pc.type_id = pt.type_id
                LEFT JOIN insurance_companies ic ON pc.company_id = ic.company_id
                WHERE p.is_active = true AND p.status = $1
            `;

            const params = [request.status];

            if (request.agentId) {
                query += ' AND pc.agent_id = $2';
                params.push(request.agentId);
            }

            query += ' ORDER BY p.created_date DESC';

            const result = await pool.query(query, params);
            const data = result.rows.map(this.mapClientPolicyFromDb);

            return {
                success: true,
                data,
                message: `Policies with status '${request.status}' retrieved successfully`
            };
        } catch (error) {
            console.error('Error in getPoliciesByStatus:', error);
            return {
                success: false,
                data: [],
                message: error instanceof Error ? error.message : 'Failed to get policies by status'
            };
        }
    }

    /**
     * Renew policy - IMPLEMENTED FALLBACK since SP is missing
     */
    public async renewPolicy(request: PolicyRenewalRequest): Promise<PolicyResponse<RenewalResponse>> {
        try {
            const pool = await poolPromise;
            
            // Get the original policy first
            const originalPolicy = await pool.query(
                'SELECT * FROM client_policies WHERE policy_id = $1',
                [request.policyId]
            );

            if (originalPolicy.rows.length === 0) {
                throw new Error('Original policy not found');
            }

            const original = originalPolicy.rows[0];

            // Create new policy with updated dates
            const newPolicyResult = await pool.query(`
                INSERT INTO client_policies 
                (client_id, policy_name, status, start_date, end_date, notes, policy_catalog_id, is_active)
                VALUES ($1, $2, 'Active', $3, $4, $5, $6, true)
                RETURNING policy_id
            `, [
                original.client_id,
                request.newPolicyName || original.policy_name,
                request.newStartDate,
                request.newEndDate,
                request.notes || original.notes,
                original.policy_catalog_id
            ]);

            // Update original policy status to 'Renewed'
            await pool.query(
                'UPDATE client_policies SET status = $1, modified_date = CURRENT_TIMESTAMP WHERE policy_id = $2',
                ['Renewed', request.policyId]
            );

            return {
                success: true,
                data: {
                    newPolicyId: newPolicyResult.rows[0].policy_id,
                    rowsAffected: 2
                },
                message: 'Policy renewed successfully'
            };
        } catch (error) {
            console.error('Error in renewPolicy:', error);
            return {
                success: false,
                message: error instanceof Error ? error.message : 'Failed to renew policy'
            };
        }
    }

    /**
     * Bulk update policy status - IMPLEMENTED FALLBACK since SP is missing
     */
    public async bulkUpdatePolicyStatus(request: BulkUpdatePolicyStatusRequest): Promise<PolicyResponse<UpdateResponse>> {
        try {
            const pool = await poolPromise;
            
            const placeholders = request.policyIds.map((_, index) => `${index + 2}`).join(',');
            const result = await pool.query(`
                UPDATE client_policies 
                SET status = $1, modified_date = CURRENT_TIMESTAMP 
                WHERE policy_id IN (${placeholders})
            `, [request.newStatus, ...request.policyIds]);

            return {
                success: true,
                data: { rowsAffected: result.rowCount || 0 },
                message: `Bulk status update completed for ${result.rowCount} policies`
            };
        } catch (error) {
            console.error('Error in bulkUpdatePolicyStatus:', error);
            return {
                success: false,
                message: error instanceof Error ? error.message : 'Failed to bulk update policy status'
            };
        }
    }

    /**
     * Get policy statistics - IMPLEMENTED FALLBACK since SP is missing
     */
    public async getPolicyStatistics(request: PolicyStatisticsRequest): Promise<PolicyResponse<PolicyStatistics>> {
        try {
            const pool = await poolPromise;
            
            let whereClause = 'WHERE p.is_active = true';
            const params: any[] = [];
            let paramIndex = 1;

            if (request.agentId) {
                whereClause += ` AND pc.agent_id = ${paramIndex}`;
                params.push(request.agentId);
                paramIndex++;
            }

            const result = await pool.query(`
                SELECT 
                    COUNT(*) as total_policies,
                    COUNT(CASE WHEN p.status = 'Active' THEN 1 END) as active_policies,
                    COUNT(CASE WHEN p.status = 'Expired' THEN 1 END) as expired_policies,
                    COUNT(CASE WHEN p.status = 'Cancelled' THEN 1 END) as cancelled_policies,
                    COUNT(CASE WHEN p.end_date::date BETWEEN CURRENT_DATE AND (CURRENT_DATE + INTERVAL '30 days') THEN 1 END) as expiring_in_30_days,
                    COUNT(CASE WHEN p.end_date::date BETWEEN CURRENT_DATE AND (CURRENT_DATE + INTERVAL '60 days') THEN 1 END) as expiring_in_60_days
                FROM client_policies p
                LEFT JOIN policy_catalog pc ON p.policy_catalog_id = pc.policy_catalog_id
                ${whereClause}
            `, params);

            const row = result.rows[0];
            const data: PolicyStatistics = {
                totalPolicies: parseInt(row.total_policies) || 0,
                activePolicies: parseInt(row.active_policies) || 0,
                expiredPolicies: parseInt(row.expired_policies) || 0,
                cancelledPolicies: parseInt(row.cancelled_policies) || 0,
                expiringIn30Days: parseInt(row.expiring_in_30_days) || 0,
                expiringIn60Days: parseInt(row.expiring_in_60_days) || 0
            };

            return {
                success: true,
                data,
                message: 'Policy statistics retrieved successfully'
            };
        } catch (error) {
            console.error('Error in getPolicyStatistics:', error);
            return {
                success: false,
                message: error instanceof Error ? error.message : 'Failed to get policy statistics'
            };
        }
    }

    /**
     * Get detailed policy statistics - IMPLEMENTED FALLBACK since SP is missing
     */
    public async getPolicyStatisticsDetailed(request: PolicyStatisticsRequest): Promise<PolicyResponse<PolicyStatisticsDetailed[]>> {
        try {
            const pool = await poolPromise;
            
            let whereClause = 'WHERE p.is_active = true';
            const params: any[] = [];
            let paramIndex = 1;

            if (request.agentId) {
                whereClause += ` AND pc.agent_id = ${paramIndex}`;
                params.push(request.agentId);
                paramIndex++;
            }

            // Get statistics by company
            const companyStats = await pool.query(`
                SELECT 
                    'Company' as group_type,
                    COALESCE(ic.company_name, 'Unknown') as group_name,
                    COUNT(*) as policy_count,
                    COUNT(CASE WHEN p.status = 'Active' THEN 1 END) as active_count
                FROM client_policies p
                LEFT JOIN policy_catalog pc ON p.policy_catalog_id = pc.policy_catalog_id
                LEFT JOIN insurance_companies ic ON pc.company_id = ic.company_id
                ${whereClause}
                GROUP BY ic.company_name
            `, params);

            // Get statistics by type
            const typeStats = await pool.query(`
                SELECT 
                    'Type' as group_type,
                    COALESCE(pt.type_name, 'Unknown') as group_name,
                    COUNT(*) as policy_count,
                    COUNT(CASE WHEN p.status = 'Active' THEN 1 END) as active_count
                FROM client_policies p
                LEFT JOIN policy_catalog pc ON p.policy_catalog_id = pc.policy_catalog_id
                LEFT JOIN policy_types pt ON pc.type_id = pt.type_id
                ${whereClause}
                GROUP BY pt.type_name
            `, params);

            const data = [
                ...companyStats.rows.map(this.mapPolicyStatisticsDetailedFromDb),
                ...typeStats.rows.map(this.mapPolicyStatisticsDetailedFromDb)
            ];

            return {
                success: true,
                data,
                message: 'Detailed policy statistics retrieved successfully'
            };
        } catch (error) {
            console.error('Error in getPolicyStatisticsDetailed:', error);
            return {
                success: false,
                data: [],
                message: error instanceof Error ? error.message : 'Failed to get detailed policy statistics'
            };
        }
    }

    // ============================================
    // POLICY TEMPLATES MANAGEMENT
    // ============================================

    /**
     * Get policy templates - Fixed to return PolicyResponse format
     */
    public async getPolicyTemplates(request: PolicyTemplateFilterRequest): Promise<PolicyResponse<PolicyTemplate[]>> {
        try {
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
            
            const data = result.rows.map(this.mapPolicyTemplateFromDb);
            return {
                success: true,
                data,
                message: 'Policy templates retrieved successfully'
            };
        } catch (error) {
            console.error('Error in getPolicyTemplates:', error);
            return {
                success: false,
                data: [],
                message: error instanceof Error ? error.message : 'Failed to get policy templates'
            };
        }
    }

    /**
     * Create policy template - Fixed to return PolicyResponse format
     */
    public async createPolicyTemplate(request: CreatePolicyTemplateRequest): Promise<PolicyResponse<CreateResponse>> {
        try {
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
                success: true,
                data: { id: result.rows[0].template_id },
                message: 'Policy template created successfully'
            };
        } catch (error) {
            console.error('Error in createPolicyTemplate:', error);
            return {
                success: false,
                message: error instanceof Error ? error.message : 'Failed to create policy template'
            };
        }
    }

    /**
     * Update policy template - Fixed to return PolicyResponse format
     */
    public async updatePolicyTemplate(request: UpdatePolicyTemplateRequest): Promise<PolicyResponse<UpdateResponse>> {
        try {
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
                success: true,
                data: { rowsAffected: result.rows[0].rows_affected },
                message: 'Policy template updated successfully'
            };
        } catch (error) {
            console.error('Error in updatePolicyTemplate:', error);
            return {
                success: false,
                message: error instanceof Error ? error.message : 'Failed to update policy template'
            };
        }
    }

    /**
     * Delete policy template - Fixed to return PolicyResponse format
     */
    public async deletePolicyTemplate(templateId: string, hardDelete: boolean = false): Promise<PolicyResponse<DeleteResponse>> {
        try {
            const pool = await poolPromise;
            const result = await pool.query(
                'SELECT sp_delete_policy_template($1,$2) AS rows_affected',
                [templateId, hardDelete]
            );
            
            return {
                success: true,
                data: { rowsAffected: result.rows[0].rows_affected },
                message: 'Policy template deleted successfully'
            };
        } catch (error) {
            console.error('Error in deletePolicyTemplate:', error);
            return {
                success: false,
                message: error instanceof Error ? error.message : 'Failed to delete policy template'
            };
        }
    }

    /**
     * Batch expire policies - Fixed to return PolicyResponse format
     */
    public async batchExpirePolicies(request: BatchExpirePoliciesRequest): Promise<PolicyResponse<UpdateResponse>> {
        try {
            const pool = await poolPromise;
            const result = await pool.query(
                'SELECT sp_batch_expire_policies($1) AS policies_expired',
                [request.asOfDate || null]
            );
            
            return {
                success: true,
                data: { rowsAffected: result.rows[0].policies_expired },
                message: 'Policies expired successfully'
            };
        } catch (error) {
            console.error('Error in batchExpirePolicies:', error);
            return {
                success: false,
                message: error instanceof Error ? error.message : 'Failed to batch expire policies'
            };
        }
    }

    /**
     * Cleanup soft deleted records - Fixed to return PolicyResponse format
     */
    public async cleanupSoftDeletedRecords(request: CleanupSoftDeletedRequest): Promise<PolicyResponse<CleanupResponse[]>> {
        try {
            const pool = await poolPromise;
            const result = await pool.query(
                'SELECT * FROM sp_cleanup_soft_deleted_records($1,$2)',
                [request.daysOld || 365, request.dryRun !== undefined ? request.dryRun : true]
            );
            
            const data = result.rows.map(row => ({
                tableName: row.table_name,
                recordsToDelete: row.records_to_delete,
                totalRecordsDeleted: row.total_records_deleted
            }));

            return {
                success: true,
                data,
                message: 'Cleanup operation completed successfully'
            };
        } catch (error) {
            console.error('Error in cleanupSoftDeletedRecords:', error);
            return {
                success: false,
                data: [],
                message: error instanceof Error ? error.message : 'Failed to cleanup soft deleted records'
            };
        }
    }

    // ============================================
    // SOFT DELETE METHODS - Fixed to return PolicyResponse format
    // ============================================

    public async softDeleteClientPolicy(policyId: string): Promise<PolicyResponse<{success: number, message: string}>> {
        try {
            const pool = await poolPromise;
            const result = await pool.query(
                'SELECT * FROM sp_soft_delete_client_policy($1)',
                [policyId]
            );
            
            return {
                success: true,
                data: {
                    success: result.rows[0].success,
                    message: result.rows[0].message
                },
                message: 'Client policy soft deleted successfully'
            };
        } catch (error) {
            console.error('Error in softDeleteClientPolicy:', error);
            return {
                success: false,
                message: error instanceof Error ? error.message : 'Failed to soft delete client policy'
            };
        }
    }

    public async softDeleteInsuranceCompany(companyId: string): Promise<PolicyResponse<{success: number, message: string}>> {
        try {
            const pool = await poolPromise;
            const result = await pool.query(
                'SELECT * FROM sp_soft_delete_insurance_company($1)',
                [companyId]
            );
            
            return {
                success: true,
                data: {
                    success: result.rows[0].success,
                    message: result.rows[0].message
                },
                message: 'Insurance company soft deleted successfully'
            };
        } catch (error) {
            console.error('Error in softDeleteInsuranceCompany:', error);
            return {
                success: false,
                message: error instanceof Error ? error.message : 'Failed to soft delete insurance company'
            };
        }
    }

    public async softDeletePolicyCatalog(policyCatalogId: string): Promise<PolicyResponse<{success: number, message: string}>> {
        try {
            const pool = await poolPromise;
            const result = await pool.query(
                'SELECT * FROM sp_soft_delete_policy_catalog($1)',
                [policyCatalogId]
            );
            
            return {
                success: true,
                data: {
                    success: result.rows[0].success,
                    message: result.rows[0].message
                },
                message: 'Policy catalog soft deleted successfully'
            };
        } catch (error) {
            console.error('Error in softDeletePolicyCatalog:', error);
            return {
                success: false,
                message: error instanceof Error ? error.message : 'Failed to soft delete policy catalog'
            };
        }
    }

    public async softDeletePolicyCategory(categoryId: string): Promise<PolicyResponse<{success: number, message: string}>> {
        try {
            const pool = await poolPromise;
            const result = await pool.query(
                'SELECT * FROM sp_soft_delete_policy_category($1)',
                [categoryId]
            );
            
            return {
                success: true,
                data: {
                    success: result.rows[0].success,
                    message: result.rows[0].message
                },
                message: 'Policy category soft deleted successfully'
            };
        } catch (error) {
            console.error('Error in softDeletePolicyCategory:', error);
            return {
                success: false,
                message: error instanceof Error ? error.message : 'Failed to soft delete policy category'
            };
        }
    }

    public async softDeletePolicyTemplate(templateId: string): Promise<PolicyResponse<{success: number, message: string}>> {
        try {
            const pool = await poolPromise;
            const result = await pool.query(
                'SELECT * FROM sp_soft_delete_policy_template($1)',
                [templateId]
            );
            
            return {
                success: true,
                data: {
                    success: result.rows[0].success,
                    message: result.rows[0].message
                },
                message: 'Policy template soft deleted successfully'
            };
        } catch (error) {
            console.error('Error in softDeletePolicyTemplate:', error);
            return {
                success: false,
                message: error instanceof Error ? error.message : 'Failed to soft delete policy template'
            };
        }
    }

    public async softDeletePolicyType(typeId: string): Promise<PolicyResponse<{success: number, message: string}>> {
        try {
            const pool = await poolPromise;
            const result = await pool.query(
                'SELECT * FROM sp_soft_delete_policy_type($1)',
                [typeId]
            );
            
            return {
                success: true,
                data: {
                    success: result.rows[0].success,
                    message: result.rows[0].message
                },
                message: 'Policy type soft deleted successfully'
            };
        } catch (error) {
            console.error('Error in softDeletePolicyType:', error);
            return {
                success: false,
                message: error instanceof Error ? error.message : 'Failed to soft delete policy type'
            };
        }
    }

    // ============================================
    // VALIDATION METHODS - Fixed to return PolicyResponse format
    // ============================================

    public async validatePolicy(request: PolicyValidationRequest): Promise<PolicyResponse<PolicyValidationResponse>> {
        try {
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
                success: true,
                data: {
                    isValid: errors.length === 0,
                    errors,
                    warnings
                },
                message: 'Policy validation completed'
            };
        } catch (error) {
            console.error('Error in validatePolicy:', error);
            return {
                success: false,
                message: error instanceof Error ? error.message : 'Failed to validate policy'
            };
        }
    }

    /**
     * Validate policy data using database SP - Fixed to return PolicyResponse format
     */
    public async validatePolicyData(
        policyName: string,
        policyType: string,
        companyId?: string,
        startDate?: Date,
        endDate?: Date
    ): Promise<PolicyResponse<{isValid: boolean, validationErrors: string}>> {
        try {
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
                success: true,
                data: {
                    isValid: result.rows[0].is_valid,
                    validationErrors: result.rows[0].validation_errors
                },
                message: 'Policy data validation completed'
            };
        } catch (error) {
            console.error('Error in validatePolicyData:', error);
            return {
                success: false,
                message: error instanceof Error ? error.message : 'Failed to validate policy data'
            };
        }
    }

    // ============================================
    // MAPPING METHODS
    // ============================================

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

    // private mapClientWithPoliciesFromDb(row: any): ClientWithPolicies {
    //     return {
    //         clientId: row.client_id,
    //         agentId: row.agent_id,
    //         firstName: row.first_name,
    //         surname: row.surname,
    //         lastName: row.last_name,
    //         fullName: row.full_name,
    //         phoneNumber: row.phone_number,
    //         email: row.email,
    //         address: row.address,
    //         nationalId: row.national_id,
    //         dateOfBirth: new Date(row.date_of_birth),
    //         isClient: row.is_client,
    //         insuranceType: row.insurance_type,
    //         clientNotes: row.client_notes,
    //         clientCreatedDate: new Date(row.client_created_date),
    //         clientModifiedDate: new Date(row.client_modified_date),
    //         clientIsActive: row.client_is_active,
            
    //         // Policy fields (may be null if no policies)
    //         policyId: row.policy_id,
    //         policyName: row.policy_name,
    //         status: row.status,
    //         startDate: row.start_date ? new Date(row.start_date) : undefined,
    //         endDate: row.end_date ? new Date(row.end_date) : undefined,
    //         policyNotes: row.policy_notes,
    //         policyCreatedDate: row.policy_created_date ? new Date(row.policy_created_date) : undefined,
    //         policyModifiedDate: row.policy_modified_date ? new Date(row.policy_modified_date) : undefined,
    //         policyIsActive: row.policy_is_active,
    //         policyCatalogId: row.policy_catalog_id,
    //         catalogPolicyName: row.catalog_policy_name,
    //         typeId: row.type_id,
    //         typeName: row.type_name,
    //         companyId: row.company_id,
    //         companyName: row.company_name,
    //         daysUntilExpiry: row.days_until_expiry
    //     };
    // }

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

    private mapPolicyStatisticsDetailedFromDb(row: any): PolicyStatisticsDetailed {
        return {
            groupType: row.group_type,
            groupName: row.group_name,
            policyCount: parseInt(row.policy_count) || 0,
            activeCount: parseInt(row.active_count) || 0
        };
    }

    private mapAgentDashboardSummaryFromDb(row: any): AgentDashboardSummary {
        return {
            totalPolicies: parseInt(row.total_policies) || 0,
            activePolicies: parseInt(row.active_policies) || 0,
            expiringIn30Days: parseInt(row.expiring_in_30_days) || 0,
            expiringIn60Days: parseInt(row.expiring_in_60_days) || 0,
            totalCompanies: parseInt(row.total_companies) || 0,
            totalClients: parseInt(row.total_clients) || 0,
            inactivePolicies: parseInt(row.inactive_policies) || 0
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
            daysUntilExpiry: parseInt(row.days_until_expiry) || 0,
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
            policyDurationDays: parseInt(row.policy_duration_days) || 0,
            policyState: row.policy_state
        };
    }

    // ============================================
    // WRAPPER METHODS WITH CONSISTENT ERROR HANDLING
    // ============================================

    public async getPolicyCatalogSafe(request: PolicyCatalogFilterRequest): Promise<PolicyResponse<PolicyCatalog[]>> {
        return this.getPolicyCatalog(request);
    }

    public async getClientPoliciesSafe(request: ClientPolicyFilterRequest): Promise<PolicyResponse<ClientPolicy[]>> {
        return this.getClientPolicies(request);
    }

    public async createClientPolicySafe(request: CreateClientPolicyRequest): Promise<PolicyResponse<CreateResponse>> {
        return this.createClientPolicy(request);
    }

    public async updateClientPolicySafe(request: UpdateClientPolicyRequest): Promise<PolicyResponse<UpdateResponse>> {
        return this.updateClientPolicy(request);
    }

    // ============================================
    // AUTOCOMPLETE METHODS - IMPLEMENTED TO FIX 501 ERRORS
    // ============================================

    /**
     * Search insurance companies for autocomplete
     */
    public async searchInsuranceCompanies(searchTerm?: string): Promise<PolicyResponse<{ value: string; label: string }[]>> {
        try {
            const pool = await poolPromise;
            let query = 'SELECT company_id, company_name FROM insurance_companies WHERE is_active = true';
            const params: any[] = [];

            if (searchTerm) {
                query += ' AND company_name ILIKE $1';
                params.push(`%${searchTerm}%`);
            }

            query += ' ORDER BY company_name LIMIT 20';

            const result = await pool.query(query, params);
            const data = result.rows.map(row => ({
                value: row.company_id,
                label: row.company_name
            }));

            return {
                success: true,
                data,
                message: 'Insurance companies autocomplete retrieved successfully'
            };
        } catch (error) {
            console.error('Error in searchInsuranceCompanies:', error);
            return {
                success: false,
                data: [],
                message: error instanceof Error ? error.message : 'Failed to search insurance companies'
            };
        }
    }

    /**
     * Search policy catalog for autocomplete
     */
    public async searchPolicyCatalog(searchTerm?: string, agentId?: string): Promise<PolicyResponse<{ value: string; label: string }[]>> {
        try {
            const pool = await poolPromise;
            let query = 'SELECT policy_catalog_id, policy_name FROM policy_catalog WHERE is_active = true';
            const params: any[] = [];
            let paramIndex = 1;

            if (agentId) {
                query += ` AND agent_id = ${paramIndex}`;
                params.push(agentId);
                paramIndex++;
            }

            if (searchTerm) {
                query += ` AND policy_name ILIKE ${paramIndex}`;
                params.push(`%${searchTerm}%`);
            }

            query += ' ORDER BY policy_name LIMIT 20';

            const result = await pool.query(query, params);
            const data = result.rows.map(row => ({
                value: row.policy_catalog_id,
                label: row.policy_name
            }));

            return {
                success: true,
                data,
                message: 'Policy catalog autocomplete retrieved successfully'
            };
        } catch (error) {
            console.error('Error in searchPolicyCatalog:', error);
            return {
                success: false,
                data: [],
                message: error instanceof Error ? error.message : 'Failed to search policy catalog'
            };
        }
    }

    /**
     * Search policy categories for autocomplete
     */
    public async searchPolicyCategories(searchTerm?: string): Promise<PolicyResponse<{ value: string; label: string }[]>> {
        try {
            const pool = await poolPromise;
            let query = 'SELECT category_id, category_name FROM policy_categories WHERE is_active = true';
            const params: any[] = [];

            if (searchTerm) {
                query += ' AND category_name ILIKE $1';
                params.push(`%${searchTerm}%`);
            }

            query += ' ORDER BY category_name LIMIT 20';

            const result = await pool.query(query, params);
            const data = result.rows.map(row => ({
                value: row.category_id,
                label: row.category_name
            }));

            return {
                success: true,
                data,
                message: 'Policy categories autocomplete retrieved successfully'
            };
        } catch (error) {
            console.error('Error in searchPolicyCategories:', error);
            return {
                success: false,
                data: [],
                message: error instanceof Error ? error.message : 'Failed to search policy categories'
            };
        }
    }

    /**
     * Search policy types for autocomplete
     */
    public async searchPolicyTypes(searchTerm?: string): Promise<PolicyResponse<{ value: string; label: string }[]>> {
        try {
            const pool = await poolPromise;
            let query = 'SELECT type_id, type_name FROM policy_types WHERE is_active = true';
            const params: any[] = [];

            if (searchTerm) {
                query += ' AND type_name ILIKE $1';
                params.push(`%${searchTerm}%`);
            }

            query += ' ORDER BY type_name LIMIT 20';

            const result = await pool.query(query, params);
            const data = result.rows.map(row => ({
                value: row.type_id,
                label: row.type_name
            }));

            return {
                success: true,
                data,
                message: 'Policy types autocomplete retrieved successfully'
            };
        } catch (error) {
            console.error('Error in searchPolicyTypes:', error);
            return {
                success: false,
                data: [],
                message: error instanceof Error ? error.message : 'Failed to search policy types'
            };
        }
    }

    /**
     * Search policy templates for autocomplete
     */
    public async searchPolicyTemplates(searchTerm?: string, agentId?: string): Promise<PolicyResponse<{ value: string; label: string }[]>> {
        try {
            const pool = await poolPromise;
            let query = 'SELECT template_id, template_name FROM policy_templates WHERE is_active = true';
            const params: any[] = [];
            let paramIndex = 1;

            if (agentId) {
                query += ` AND agent_id = ${paramIndex}`;
                params.push(agentId);
                paramIndex++;
            }

            if (searchTerm) {
                query += ` AND template_name ILIKE ${paramIndex}`;
                params.push(`%${searchTerm}%`);
            }

            query += ' ORDER BY template_name LIMIT 20';

            const result = await pool.query(query, params);
            const data = result.rows.map(row => ({
                value: row.template_id,
                label: row.template_name
            }));

            return {
                success: true,
                data,
                message: 'Policy templates autocomplete retrieved successfully'
            };
        } catch (error) {
            console.error('Error in searchPolicyTemplates:', error);
            return {
                success: false,
                data: [],
                message: error instanceof Error ? error.message : 'Failed to search policy templates'
            };
        }
    }

    /**
     * Search client policies for autocomplete
     */
    public async searchClientPolicies(searchTerm?: string, agentId?: string, clientId?: string): Promise<PolicyResponse<{ value: string; label: string }[]>> {
        try {
            const pool = await poolPromise;
            let query = `
                SELECT p.policy_id, p.policy_name 
                FROM client_policies p
                LEFT JOIN policy_catalog pc ON p.policy_catalog_id = pc.policy_catalog_id
                WHERE p.is_active = true
            `;
            const params: any[] = [];
            let paramIndex = 1;

            if (agentId) {
                query += ` AND pc.agent_id = ${paramIndex}`;
                params.push(agentId);
                paramIndex++;
            }

            if (clientId) {
                query += ` AND p.client_id = ${paramIndex}`;
                params.push(clientId);
                paramIndex++;
            }

            if (searchTerm) {
                query += ` AND p.policy_name ILIKE ${paramIndex}`;
                params.push(`%${searchTerm}%`);
            }

            query += ' ORDER BY p.policy_name LIMIT 20';

            const result = await pool.query(query, params);
            const data = result.rows.map(row => ({
                value: row.policy_id,
                label: row.policy_name
            }));

            return {
                success: true,
                data,
                message: 'Client policies autocomplete retrieved successfully'
            };
        } catch (error) {
            console.error('Error in searchClientPolicies:', error);
            return {
                success: false,
                data: [],
                message: error instanceof Error ? error.message : 'Failed to search client policies'
            };
        }
    }
}