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
    PolicyCompanyRelationship,
    CreatePolicyCatalogRequest,
    UpdatePolicyCatalogRequest,
    PolicyCatalogFilterRequest,
    CreateClientPolicyRequest,
    UpdateClientPolicyRequest,
    ClientPolicyFilterRequest,
    ExpiringPoliciesRequest,
    CreatePolicyTemplateRequest,
    PolicyTemplateFilterRequest,
    UpsertPolicyCatalogRequest,
    UpsertClientPolicyRequest,
    PolicyValidationRequest,
    PolicyValidationResponse
} from '../interfaces/policy';

export class PolicyService {
    
    // Policy Catalog Management
    public async getPolicyCatalog(request: PolicyCatalogFilterRequest): Promise<PolicyCatalog[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('agentId', sql.UniqueIdentifier, request.agentId)
            .input('policyType', sql.NVarChar(50), request.policyType)
            .input('companyId', sql.UniqueIdentifier, request.companyId)
            .input('companyName', sql.NVarChar(100), request.companyName)
            .input('searchTerm', sql.NVarChar(100), request.searchTerm)
            .input('isActive', sql.Bit, request.isActive ?? true)
            .execute('sp_GetPolicyCatalog');

        return result.recordset.map(this.mapPolicyCatalog);
    }

    public async createPolicyCatalogItem(request: CreatePolicyCatalogRequest): Promise<string> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('agentId', sql.UniqueIdentifier, request.agentId)
            .input('policyName', sql.NVarChar(100), request.policyName)
            .input('policyType', sql.NVarChar(50), request.policyType)
            .input('companyId', sql.UniqueIdentifier, request.companyId)
            .input('notes', sql.NVarChar(sql.MAX), request.notes)
            .execute('sp_CreatePolicyCatalogItem');

        return result.recordset[0].PolicyCatalogId;
    }

    public async updatePolicyCatalogItem(request: UpdatePolicyCatalogRequest): Promise<number> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('policyCatalogId', sql.UniqueIdentifier, request.policyCatalogId)
            .input('agentId', sql.UniqueIdentifier, request.agentId)
            .input('policyName', sql.NVarChar(100), request.policyName)
            .input('policyType', sql.NVarChar(50), request.policyType)
            .input('companyId', sql.UniqueIdentifier, request.companyId)
            .input('notes', sql.NVarChar(sql.MAX), request.notes)
            .input('isActive', sql.Bit, request.isActive)
            .execute('sp_UpdatePolicyCatalogItem');

        return result.recordset[0].RowsAffected;
    }

    public async deletePolicyCatalogItem(policyCatalogId: string, agentId: string): Promise<number> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('policyCatalogId', sql.UniqueIdentifier, policyCatalogId)
            .input('agentId', sql.UniqueIdentifier, agentId)
            .execute('sp_DeletePolicyCatalogItem');

        return result.recordset[0].RowsAffected;
    }

    public async upsertPolicyCatalog(request: UpsertPolicyCatalogRequest): Promise<string> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('policyCatalogId', sql.UniqueIdentifier, request.policyCatalogId)
            .input('agentId', sql.UniqueIdentifier, request.agentId)
            .input('policyName', sql.NVarChar(100), request.policyName)
            .input('policyType', sql.NVarChar(50), request.policyType)
            .input('companyId', sql.UniqueIdentifier, request.companyId)
            .input('companyName', sql.NVarChar(100), request.companyName)
            .input('notes', sql.NVarChar(sql.MAX), request.notes)
            .execute('sp_UpsertPolicyCatalog');

        return result.recordset[0].PolicyCatalogId;
    }

    // Client Policy Management
    public async getClientPolicies(request: ClientPolicyFilterRequest): Promise<ClientPolicy[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('clientId', sql.UniqueIdentifier, request.clientId)
            .input('status', sql.NVarChar(20), request.status)
            .input('policyType', sql.NVarChar(50), request.policyType)
            .execute('sp_GetClientPolicies');

        return result.recordset.map(this.mapClientPolicy);
    }

    public async createClientPolicy(request: CreateClientPolicyRequest): Promise<string> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('clientId', sql.UniqueIdentifier, request.clientId)
            .input('policyName', sql.NVarChar(100), request.policyName)
            .input('policyType', sql.NVarChar(50), request.policyType)
            .input('companyName', sql.NVarChar(100), request.companyName)
            .input('status', sql.NVarChar(20), request.status || 'Active')
            .input('startDate', sql.Date, request.startDate)
            .input('endDate', sql.Date, request.endDate)
            .input('notes', sql.NVarChar(sql.MAX), request.notes)
            .execute('sp_CreateClientPolicy');

        return result.recordset[0].PolicyId;
    }

    public async updateClientPolicy(request: UpdateClientPolicyRequest): Promise<number> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('policyId', sql.UniqueIdentifier, request.policyId)
            .input('policyName', sql.NVarChar(100), request.policyName)
            .input('policyType', sql.NVarChar(50), request.policyType)
            .input('companyName', sql.NVarChar(100), request.companyName)
            .input('status', sql.NVarChar(20), request.status)
            .input('startDate', sql.Date, request.startDate)
            .input('endDate', sql.Date, request.endDate)
            .input('notes', sql.NVarChar(sql.MAX), request.notes)
            .input('isActive', sql.Bit, request.isActive)
            .execute('sp_UpdateClientPolicy');

        return result.recordset[0].RowsAffected;
    }

    public async upsertClientPolicy(request: UpsertClientPolicyRequest): Promise<string> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('policyId', sql.UniqueIdentifier, request.policyId)
            .input('clientId', sql.UniqueIdentifier, request.clientId)
            .input('policyName', sql.NVarChar(100), request.policyName)
            .input('policyType', sql.NVarChar(50), request.policyType)
            .input('companyName', sql.NVarChar(100), request.companyName)
            .input('status', sql.NVarChar(20), request.status)
            .input('startDate', sql.Date, request.startDate)
            .input('endDate', sql.Date, request.endDate)
            .input('notes', sql.NVarChar(sql.MAX), request.notes)
            .execute('sp_UpsertClientPolicy');

        return result.recordset[0].PolicyId;
    }

    public async getExpiringPolicies(request: ExpiringPoliciesRequest): Promise<ClientPolicy[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('agentId', sql.UniqueIdentifier, request.agentId)
            .input('daysAhead', sql.Int, request.daysAhead || 30)
            .execute('sp_GetExpiringPolicies');

        return result.recordset.map(this.mapClientPolicy);
    }

    public async getPolicyStatistics(agentId: string): Promise<PolicyStatistics> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('agentId', sql.UniqueIdentifier, agentId)
            .execute('sp_GetPolicyStatistics');

        return this.mapPolicyStatistics(result.recordset[0]);
    }

    // Policy Templates Management
    public async getPolicyTemplates(request: PolicyTemplateFilterRequest): Promise<PolicyTemplate[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('agentId', sql.UniqueIdentifier, request.agentId)
            .input('policyType', sql.NVarChar(50), request.policyType)
            .input('isActive', sql.Bit, request.isActive ?? true)
            .execute('sp_GetPolicyTemplates');

        return result.recordset.map(this.mapPolicyTemplate);
    }

    public async createPolicyTemplate(request: CreatePolicyTemplateRequest): Promise<string> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('agentId', sql.UniqueIdentifier, request.agentId)
            .input('templateName', sql.NVarChar(100), request.templateName)
            .input('policyType', sql.NVarChar(50), request.policyType)
            .input('defaultTermMonths', sql.Int, request.defaultTermMonths)
            .input('defaultPremium', sql.Decimal(10, 2), request.defaultPremium)
            .input('coverageDescription', sql.NVarChar(sql.MAX), request.coverageDescription)
            .input('terms', sql.NVarChar(sql.MAX), request.terms)
            .execute('sp_CreatePolicyTemplate');

        return result.recordset[0].TemplateId;
    }

    public async deletePolicyTemplate(templateId: string, agentId: string): Promise<number> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('templateId', sql.UniqueIdentifier, templateId)
            .input('agentId', sql.UniqueIdentifier, agentId)
            .query(`
                UPDATE PolicyTemplates 
                SET IsActive = 0 
                WHERE TemplateId = @templateId AND AgentId = @agentId
            `);

        return result.rowsAffected[0];
    }

    // Reference Data Methods
    public async getInsuranceCompanies(isActive: boolean = true): Promise<InsuranceCompany[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('isActive', sql.Bit, isActive)
            .execute('sp_GetInsuranceCompanies');

        return result.recordset.map(this.mapInsuranceCompany);
    }

    public async getPolicyTypes(isActive: boolean = true): Promise<PolicyType[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('isActive', sql.Bit, isActive)
            .execute('sp_GetPolicyTypes');

        return result.recordset.map(this.mapPolicyType);
    }

    public async getPolicyCategories(): Promise<PolicyCategory[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .query(`
                SELECT CategoryId, CategoryName, Description, IsActive, CreatedDate 
                FROM PolicyCategories 
                WHERE IsActive = 1 
                ORDER BY CategoryName
            `);

        return result.recordset.map(this.mapPolicyCategory);
    }

    // Validation Methods
    public async validatePolicyData(request: PolicyValidationRequest): Promise<PolicyValidationResponse> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('policyName', sql.NVarChar(100), request.policyName)
            .input('policyType', sql.NVarChar(50), request.policyType)
            .input('companyId', sql.UniqueIdentifier, request.companyId)
            .input('startDate', sql.Date, request.startDate)
            .input('endDate', sql.Date, request.endDate)
            .execute('sp_ValidatePolicyData');

        return {
            isValid: result.recordset[0].IsValid,
            validationErrors: result.recordset[0].ValidationErrors
        };
    }

    // Utility Methods
    public async getPolicyById(policyId: string): Promise<ClientPolicy | null> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('policyId', sql.UniqueIdentifier, policyId)
            .query(`
                SELECT cp.*, c.FirstName + ' ' + c.Surname AS ClientName, c.PhoneNumber AS ClientPhone, c.Email AS ClientEmail,
                       DATEDIFF(DAY, GETDATE(), cp.EndDate) AS DaysUntilExpiry
                FROM ClientPolicies cp
                INNER JOIN Clients c ON cp.ClientId = c.ClientId
                WHERE cp.PolicyId = @policyId AND cp.IsActive = 1
            `);

        return result.recordset.length ? this.mapClientPolicy(result.recordset[0]) : null;
    }

    public async searchPolicies(agentId: string, searchTerm: string, policyType?: string): Promise<ClientPolicy[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('agentId', sql.UniqueIdentifier, agentId)
            .input('searchTerm', sql.NVarChar(100), `%${searchTerm}%`)
            .input('policyType', sql.NVarChar(50), policyType)
            .query(`
                SELECT cp.*, c.FirstName + ' ' + c.Surname AS ClientName, c.PhoneNumber AS ClientPhone, c.Email AS ClientEmail,
                       DATEDIFF(DAY, GETDATE(), cp.EndDate) AS DaysUntilExpiry
                FROM ClientPolicies cp
                INNER JOIN Clients c ON cp.ClientId = c.ClientId
                WHERE c.AgentId = @agentId 
                  AND cp.IsActive = 1 
                  AND c.IsActive = 1
                  AND (cp.PolicyName LIKE @searchTerm OR cp.CompanyName LIKE @searchTerm OR c.FirstName LIKE @searchTerm OR c.Surname LIKE @searchTerm)
                  AND (@policyType IS NULL OR cp.PolicyType = @policyType)
                ORDER BY cp.PolicyName
            `);

        return result.recordset.map(this.mapClientPolicy);
    }

    public async getPoliciesByStatus(agentId: string, status: string): Promise<ClientPolicy[]> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('agentId', sql.UniqueIdentifier, agentId)
            .input('status', sql.NVarChar(20), status)
            .query(`
                SELECT cp.*, c.FirstName + ' ' + c.Surname AS ClientName, c.PhoneNumber AS ClientPhone, c.Email AS ClientEmail,
                       DATEDIFF(DAY, GETDATE(), cp.EndDate) AS DaysUntilExpiry
                FROM ClientPolicies cp
                INNER JOIN Clients c ON cp.ClientId = c.ClientId
                WHERE c.AgentId = @agentId 
                  AND cp.Status = @status 
                  AND cp.IsActive = 1 
                  AND c.IsActive = 1
                ORDER BY cp.EndDate DESC
            `);

        return result.recordset.map(this.mapClientPolicy);
    }

    public async renewPolicy(policyId: string, newEndDate: Date, notes?: string): Promise<boolean> {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('policyId', sql.UniqueIdentifier, policyId)
            .input('newEndDate', sql.Date, newEndDate)
            .input('notes', sql.NVarChar(sql.MAX), notes)
            .query(`
                UPDATE ClientPolicies 
                SET EndDate = @newEndDate, 
                    Status = 'Active',
                    Notes = CASE WHEN @notes IS NOT NULL THEN @notes ELSE Notes END,
                    ModifiedDate = GETUTCDATE()
                WHERE PolicyId = @policyId
            `);

        return result.rowsAffected[0] > 0;
    }

    public async bulkUpdatePolicyStatus(policyIds: string[], status: string): Promise<number> {
        const pool = await poolPromise;
        
        // Create a table-valued parameter for bulk operations
        const table = new sql.Table('PolicyIdsTable');
        table.columns.add('PolicyId', sql.UniqueIdentifier);
        
        policyIds.forEach(id => {
            table.rows.add(id);
        });

        const result = await pool.request()
            .input('policyIds', table)
            .input('status', sql.NVarChar(20), status)
            .query(`
                UPDATE cp 
                SET Status = @status, ModifiedDate = GETUTCDATE()
                FROM ClientPolicies cp
                INNER JOIN @policyIds p ON cp.PolicyId = p.PolicyId
                WHERE cp.IsActive = 1
            `);

        return result.rowsAffected[0];
    }

    // Private mapping methods
    private mapPolicyCatalog(row: any): PolicyCatalog {
        return {
            policyCatalogId: row.PolicyCatalogId,
            agentId: row.AgentId,
            policyName: row.PolicyName,
            policyType: row.PolicyType,
            companyId: row.CompanyId,
            companyName: row.CompanyName,
            notes: row.Notes,
            isActive: row.IsActive,
            createdDate: row.CreatedDate,
            modifiedDate: row.ModifiedDate,
            companyActive: row.CompanyActive
        };
    }

    private mapClientPolicy(row: any): ClientPolicy {
        return {
            policyId: row.PolicyId,
            clientId: row.ClientId,
            policyName: row.PolicyName,
            policyType: row.PolicyType,
            companyName: row.CompanyName,
            status: row.Status,
            startDate: row.StartDate,
            endDate: row.EndDate,
            notes: row.Notes,
            createdDate: row.CreatedDate,
            modifiedDate: row.ModifiedDate,
            isActive: row.IsActive,
            daysUntilExpiry: row.DaysUntilExpiry,
            clientName: row.ClientName,
            clientPhone: row.ClientPhone,
            clientEmail: row.ClientEmail
        };
    }

    private mapPolicyTemplate(row: any): PolicyTemplate {
        return {
            templateId: row.TemplateId,
            agentId: row.AgentId,
            templateName: row.TemplateName,
            policyType: row.PolicyType,
            defaultTermMonths: row.DefaultTermMonths,
            defaultPremium: row.DefaultPremium,
            coverageDescription: row.CoverageDescription,
            terms: row.Terms,
            isActive: row.IsActive,
            createdDate: row.CreatedDate
        };
    }

    private mapPolicyCategory(row: any): PolicyCategory {
        return {
            categoryId: row.CategoryId,
            categoryName: row.CategoryName,
            description: row.Description,
            isActive: row.IsActive,
            createdDate: row.CreatedDate
        };
    }

    private mapInsuranceCompany(row: any): InsuranceCompany {
        return {
            companyId: row.CompanyId,
            companyName: row.CompanyName,
            isActive: row.IsActive,
            createdDate: row.CreatedDate
        };
    }

    private mapPolicyType(row: any): PolicyType {
        return {
            typeId: row.TypeId,
            typeName: row.TypeName,
            isActive: row.IsActive,
            createdDate: row.CreatedDate
        };
    }

    private mapPolicyStatistics(row: any): PolicyStatistics {
        return {
            totalPolicies: row.TotalPolicies || 0,
            activePolicies: row.ActivePolicies || 0,
            expiredPolicies: row.ExpiredPolicies || 0,
            lapsedPolicies: row.LapsedPolicies || 0,
            inactivePolicies: row.InactivePolicies || 0,
            expiringIn30Days: row.ExpiringIn30Days || 0,
            expiringIn7Days: row.ExpiringIn7Days || 0,
            newPoliciesThisMonth: row.NewPoliciesThisMonth || 0,
            motorPolicies: row.MotorPolicies || 0,
            lifePolicies: row.LifePolicies || 0,
            healthPolicies: row.HealthPolicies || 0,
            travelPolicies: row.TravelPolicies || 0,
            propertyPolicies: row.PropertyPolicies || 0,
            marinePolicies: row.MarinePolicies || 0,
            businessPolicies: row.BusinessPolicies || 0,
            catalogPolicies: row.CatalogPolicies || 0
        };
    }
}