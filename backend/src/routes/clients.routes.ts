// routes/clients.routes.ts
import { Router } from 'express';
import { ClientController } from '../controllers/clients.controller';

const router = Router();
const controller = new ClientController();

// ============================================
// CREATE / UPDATE OPERATIONS
// ============================================
// Create / Update (upsert)
router.post('/upsert', controller.upsert.bind(controller));

// Create / Update separate endpoints
router.post('/', controller.create.bind(controller));
router.put('/', controller.update.bind(controller));

// ============================================
// STATISTICS & ANALYTICS
// ============================================
// Enhanced statistics (most specific first)
router.get('/:agentId/statistics/enhanced', controller.enhancedStatistics.bind(controller));

// Basic statistics
router.get('/:agentId/statistics', controller.statistics.bind(controller));

// ============================================
// SPECIAL QUERIES
// ============================================
// Today's birthdays
router.get('/:agentId/birthdays', controller.birthdays.bind(controller));

// Advanced filters & pagination
router.get('/:agentId/all/paginated', controller.allClientsPaginated.bind(controller));

// Search clients
router.get('/:agentId/search', controller.search.bind(controller));

// ============================================
// FILTERED QUERIES
// ============================================
// Clients by insurance type
router.get('/:agentId/insurance/:insuranceType', controller.byInsuranceType.bind(controller));

// ============================================
// CLIENT-SPECIFIC OPERATIONS
// ============================================
// Get client with all policies and related data
router.get('/:agentId/:clientId/policies', controller.withPolicies.bind(controller));

// Get single client by ID
router.get('/:agentId/:clientId', controller.getById.bind(controller));

// Convert prospect to client
router.put('/:agentId/:clientId/convert', controller.convert.bind(controller));

// Delete client (soft delete)
router.delete('/:agentId/:clientId', controller.delete.bind(controller));

// ============================================
// GENERAL QUERIES (LEAST SPECIFIC - LAST)
// ============================================
// Get all clients with optional filters
router.get('/:agentId', controller.getAll.bind(controller));

export default router;