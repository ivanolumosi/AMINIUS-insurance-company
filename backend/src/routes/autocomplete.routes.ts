import { Router } from 'express';
import { PolicyAutocompleteController } from '../controllers/autocomplete.controller';

const router = Router();
const controller = new PolicyAutocompleteController();

// ============================================
// STATIC AUTOCOMPLETE ROUTES
// ============================================
router.get('/companies', controller.companies.bind(controller));
router.get('/types', controller.types.bind(controller));
router.get('/categories', controller.categories.bind(controller));

// ============================================
// DYNAMIC AUTOCOMPLETE ROUTES
// ============================================
router.get('/catalog', controller.catalog.bind(controller));
router.get('/templates', controller.templates.bind(controller));
router.get('/client-policies', controller.clientPolicies.bind(controller));

export default router;
