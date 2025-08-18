import { Router } from 'express';
import { PolicyController } from '../controllers/policy.controller';

const router = Router();
const controller = new PolicyController();

// ============================================
// HEALTH CHECK
// ============================================
router.get('/health', controller.healthCheck.bind(controller));

// ============================================
// POLICY CATALOG
// ============================================
router.get('/catalog', controller.getPolicyCatalog.bind(controller));
router.post('/catalog', controller.createPolicyCatalogItem.bind(controller));
router.put('/catalog/:id', controller.updatePolicyCatalogItem.bind(controller));
router.post('/catalog/upsert', controller.upsertPolicyCatalog.bind(controller));
router.delete('/catalog/:policyCatalogId/soft', controller.softDeletePolicyCatalog.bind(controller));

// ============================================
// CLIENT POLICIES
// ============================================
router.get('/policies', controller.getClientPolicies.bind(controller));
router.get('/policies/:id', controller.getPolicyById.bind(controller));
router.post('/policies', controller.createClientPolicy.bind(controller));
router.put('/policies/:id', controller.updateClientPolicy.bind(controller));
router.post('/policies/upsert', controller.upsertClientPolicy.bind(controller));
router.delete('/policies/:policyId/soft', controller.softDeleteClientPolicy.bind(controller));
router.get('/clients-with-policies', controller.getClientsWithPolicies.bind(controller));


// ============================================
// SEARCH & FILTER
// ============================================
router.get('/policies/search', controller.searchPolicies.bind(controller));
router.get('/policies/status', controller.getPoliciesByStatus.bind(controller));

// ============================================
// EXPIRATION & RENEWAL
// ============================================
router.get('/policies/expiring', controller.getExpiringPolicies.bind(controller));
router.post('/policies/:id/renew', controller.renewPolicy.bind(controller));
router.get('/policies/renewal-candidates', controller.getPolicyRenewalCandidates.bind(controller));

// ============================================
// BULK OPERATIONS
// ============================================
router.put('/policies/bulk/status', controller.bulkUpdatePolicyStatus.bind(controller));
router.post('/policies/bulk/create', controller.bulkCreatePolicies.bind(controller));
router.put('/policies/bulk/update', controller.bulkUpdatePolicies.bind(controller));
router.post('/policies/bulk/expire', controller.batchExpirePolicies.bind(controller));

// ============================================
// POLICY TEMPLATES
// ============================================
router.get('/templates', controller.getPolicyTemplates.bind(controller));
router.post('/templates', controller.createPolicyTemplate.bind(controller));
router.put('/templates/:id', controller.updatePolicyTemplate.bind(controller));
router.delete('/templates/:id', controller.softDeletePolicyTemplate.bind(controller));

// ============================================
// REFERENCE DATA - INSURANCE COMPANIES
// ============================================
router.get('/companies', controller.getInsuranceCompanies.bind(controller));
router.post('/companies', controller.createInsuranceCompany.bind(controller));
router.put('/companies/:id', controller.updateInsuranceCompany.bind(controller));
router.delete('/companies/:companyId', controller.deleteInsuranceCompany.bind(controller));
router.delete('/companies/:companyId/soft', controller.softDeleteInsuranceCompany.bind(controller));

// ============================================
// REFERENCE DATA - POLICY TYPES
// ============================================
router.get('/types', controller.getPolicyTypes.bind(controller));
router.post('/types', controller.createPolicyType.bind(controller));
router.put('/types/:id', controller.updatePolicyType.bind(controller));
router.delete('/types/:typeId/soft', controller.softDeletePolicyType.bind(controller));  // ✅ Added

// ============================================
// REFERENCE DATA - POLICY CATEGORIES
// ============================================
router.get('/categories', controller.getPolicyCategories.bind(controller));
router.post('/categories', controller.createPolicyCategory.bind(controller));
router.put('/categories/:id', controller.updatePolicyCategory.bind(controller));
router.delete('/categories/:categoryId/soft', controller.softDeletePolicyCategory.bind(controller));

// ============================================
// AUTOCOMPLETE ENDPOINTS
// ============================================
router.get('/autocomplete/companies', controller.autocompleteInsuranceCompanies.bind(controller));
router.get('/autocomplete/catalog', controller.autocompletePolicyCatalog.bind(controller));
router.get('/autocomplete/categories', controller.autocompletePolicyCategories.bind(controller));
router.get('/autocomplete/templates', controller.autocompletePolicyTemplates.bind(controller));
router.get('/autocomplete/types', controller.autocompletePolicyTypes.bind(controller));
router.get('/autocomplete/client-policies', controller.autocompleteClientPolicies.bind(controller));

// ============================================
// ANALYTICS & REPORTING
// ============================================
router.get('/statistics', controller.getPolicyStatistics.bind(controller));
router.get('/statistics/detailed', controller.getPolicyStatisticsDetailed.bind(controller));
router.get('/dashboard/:agentId', controller.getAgentDashboardSummary.bind(controller));
router.get('/history/:clientId', controller.getPolicyHistory.bind(controller));

// ============================================
// VALIDATION
// ============================================
router.post('/validate', controller.validatePolicy.bind(controller));

// ============================================
// EXPORT
// ============================================
router.get('/export', controller.exportPolicies.bind(controller));

// ============================================
// UTILITY
// ============================================
router.post('/cleanup/soft-deleted', controller.cleanupSoftDeletedRecords.bind(controller));

export default router;
