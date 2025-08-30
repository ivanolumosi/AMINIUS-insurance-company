import { Router } from 'express';
import {
    // Health check
    healthCheck,

    // Policy catalog
    getPolicyCatalog,
    createPolicyCatalogItem,
    updatePolicyCatalogItem,
    upsertPolicyCatalog,
    softDeletePolicyCatalog,
    deletePolicyCatalogItem,

    // Client policies
    getClientPolicies,
    getPolicyById,
    createClientPolicy,
    updateClientPolicy,
    upsertClientPolicy,
    deleteClientPolicy,
    softDeleteClientPolicy,
    getClientsWithPolicies,

    // Search & filter
    searchPolicies,
    getPoliciesByStatus,

    // Expiration & renewal
    getExpiringPolicies,
    renewPolicy,
    getPolicyRenewalCandidates,

    // Bulk operations
    bulkUpdatePolicyStatus,
    bulkCreatePolicies,
    bulkUpdatePolicies,
    batchExpirePolicies,

    // Policy templates
    getPolicyTemplates,
    createPolicyTemplate,
    updatePolicyTemplate,
    deletePolicyTemplate,
    softDeletePolicyTemplate,

    // Reference data - insurance companies
    getInsuranceCompanies,
    createInsuranceCompany,
    updateInsuranceCompany,
    deleteInsuranceCompany,
    softDeleteInsuranceCompany,

    // Reference data - policy types
    getPolicyTypes,
    createPolicyType,
    updatePolicyType,
    softDeletePolicyType,

    // Reference data - policy categories
    getPolicyCategories,
    createPolicyCategory,
    updatePolicyCategory,
    softDeletePolicyCategory,

    // Autocomplete (not implemented in service - will return 501)
    autocompleteInsuranceCompanies,
    autocompletePolicyCatalog,
    autocompletePolicyCategories,
    autocompletePolicyTemplates,
    autocompletePolicyTypes,
    autocompleteClientPolicies,

    // Analytics & reporting
    getPolicyStatistics,
    getPolicyStatisticsDetailed,
    getAgentDashboardSummary,
    getPolicyHistory,

    // Validation
    validatePolicy,
    validatePolicyData,

    // Export
    exportPolicies,

    // Utility
    cleanupSoftDeletedRecords
} from '../controllers/policy.controller';

const router = Router();

// ============================================
// HEALTH CHECK
// ============================================
router.get('/health', healthCheck);

// ============================================
// POLICY CATALOG
// ============================================
router.get('/catalog', getPolicyCatalog);
router.post('/catalog', createPolicyCatalogItem);
router.put('/catalog/:id', updatePolicyCatalogItem);
router.post('/catalog/upsert', upsertPolicyCatalog);
router.delete('/catalog/:policyCatalogId', deletePolicyCatalogItem);
router.delete('/catalog/:policyCatalogId/soft', softDeletePolicyCatalog);

// ============================================
// CLIENT POLICIES
// ============================================
// Base
router.get('/policies', getClientPolicies);
router.post('/policies', createClientPolicy);
router.post('/policies/upsert', upsertClientPolicy);

// Special named routes BEFORE :id (order matters!)
router.get('/policies/search', searchPolicies);
router.get('/policies/status', getPoliciesByStatus);
router.get('/policies/expiring', getExpiringPolicies);
router.get('/policies/renewal-candidates', getPolicyRenewalCandidates);

// ID-based routes (must come last)
router.get('/policies/:id', getPolicyById);
router.put('/policies/:id', updateClientPolicy);
router.post('/policies/:id/renew', renewPolicy);
router.delete('/policies/:policyId', deleteClientPolicy);
router.delete('/policies/:policyId/soft', softDeleteClientPolicy);

// Client relationships
router.get('/clients-with-policies', getClientsWithPolicies);

// ============================================
// BULK OPERATIONS
// ============================================
router.put('/policies/bulk/status', bulkUpdatePolicyStatus);
router.post('/policies/bulk/create', bulkCreatePolicies);
router.put('/policies/bulk/update', bulkUpdatePolicies);
router.post('/policies/bulk/expire', batchExpirePolicies);

// ============================================
// POLICY TEMPLATES
// ============================================
router.get('/templates', getPolicyTemplates);
router.post('/templates', createPolicyTemplate);
router.put('/templates/:id', updatePolicyTemplate);
router.delete('/templates/:templateId', deletePolicyTemplate);
router.delete('/templates/:templateId/soft', softDeletePolicyTemplate);

// ============================================
// REFERENCE DATA - INSURANCE COMPANIES
// ============================================
router.get('/companies', getInsuranceCompanies);
router.post('/companies', createInsuranceCompany);
router.put('/companies/:id', updateInsuranceCompany);
router.delete('/companies/:companyId', deleteInsuranceCompany);
router.delete('/companies/:companyId/soft', softDeleteInsuranceCompany);

// ============================================
// REFERENCE DATA - POLICY TYPES
// ============================================
router.get('/types', getPolicyTypes);
router.post('/types', createPolicyType);
router.put('/types/:id', updatePolicyType);
router.delete('/types/:typeId/soft', softDeletePolicyType);

// ============================================
// REFERENCE DATA - POLICY CATEGORIES
// ============================================
router.get('/categories', getPolicyCategories);
router.post('/categories', createPolicyCategory);
router.put('/categories/:id', updatePolicyCategory);
router.delete('/categories/:categoryId/soft', softDeletePolicyCategory);

// ============================================
// AUTOCOMPLETE ENDPOINTS (NOT IMPLEMENTED)
// ============================================
// Note: These will return 501 Not Implemented status
router.get('/autocomplete/companies', autocompleteInsuranceCompanies);
router.get('/autocomplete/catalog', autocompletePolicyCatalog);
router.get('/autocomplete/categories', autocompletePolicyCategories);
router.get('/autocomplete/templates', autocompletePolicyTemplates);
router.get('/autocomplete/types', autocompletePolicyTypes);
router.get('/autocomplete/client-policies', autocompleteClientPolicies);

// ============================================
// ANALYTICS & REPORTING
// ============================================
router.get('/statistics', getPolicyStatistics);
router.get('/statistics/detailed', getPolicyStatisticsDetailed);
router.get('/dashboard/:agentId', getAgentDashboardSummary);
router.get('/history/:clientId', getPolicyHistory);

// ============================================
// VALIDATION
// ============================================
router.post('/validate', validatePolicy);
router.post('/validate/data', validatePolicyData);

// ============================================
// EXPORT
// ============================================
router.get('/export', exportPolicies);

// ============================================
// UTILITY
// ============================================
router.post('/cleanup/soft-deleted', cleanupSoftDeletedRecords);

export default router;