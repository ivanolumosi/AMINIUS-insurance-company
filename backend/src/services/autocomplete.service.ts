import { poolPromise } from '../../db';
import * as sql from 'mssql';
import { Request, Response } from 'express';

/**
 * -------- STATIC AUTOCOMPLETE --------
 * These can be cached in the frontend.
 */

// Insurance Companies
export const autocompleteCompanies = async (req: Request, res: Response) => {
  try {
    const pool = await poolPromise;
    const result = await pool.request()
      .query(`SELECT companyId, companyName 
              FROM InsuranceCompanies 
              WHERE isActive = 1 
              ORDER BY companyName`);
    res.json(result.recordset);
  } catch (err) {
    console.error('Error fetching companies', err);
    res.status(500).json({ error: 'Failed to fetch companies' });
  }
};

// Policy Types
export const autocompleteTypes = async (req: Request, res: Response) => {
  try {
    const pool = await poolPromise;
    const result = await pool.request()
      .query(`SELECT typeId, typeName 
              FROM PolicyTypes 
              WHERE isActive = 1 
              ORDER BY typeName`);
    res.json(result.recordset);
  } catch (err) {
    console.error('Error fetching types', err);
    res.status(500).json({ error: 'Failed to fetch policy types' });
  }
};

// Policy Categories
export const autocompleteCategories = async (req: Request, res: Response) => {
  try {
    const pool = await poolPromise;
    const result = await pool.request()
      .query(`SELECT categoryId, categoryName 
              FROM PolicyCategories 
              WHERE isActive = 1 
              ORDER BY categoryName`);
    res.json(result.recordset);
  } catch (err) {
    console.error('Error fetching categories', err);
    res.status(500).json({ error: 'Failed to fetch categories' });
  }
};




/**
 * -------- DYNAMIC AUTOCOMPLETE --------
 * Depends on filters from query params.
 */
// Policy Catalog
export const autocompleteCatalog = async (req: Request, res: Response) => {
  const { agentId, companyId, typeId, searchTerm } = req.query;
  try {
    const pool = await poolPromise;
    const request = pool.request();

    if (agentId) request.input('agentId', sql.UniqueIdentifier, agentId);
    if (companyId) request.input('companyId', sql.UniqueIdentifier, companyId);
    if (typeId) request.input('typeId', sql.UniqueIdentifier, typeId);

    if (searchTerm && typeof searchTerm === 'string') {
      const cleanTerm = `%${searchTerm.trim()}%`;
      request.input('searchTerm', sql.NVarChar, cleanTerm);
    }

    let query = `
      SELECT policyCatalogId, policyName
      FROM PolicyCatalog
      WHERE isActive = 1
    `;

    if (agentId) query += ' AND agentId = @agentId';
    if (companyId) query += ' AND companyId = @companyId';
    if (typeId) query += ' AND typeId = @typeId';
    if (searchTerm) query += ' AND policyName COLLATE SQL_Latin1_General_CP1_CI_AS LIKE @searchTerm';

    query += ' ORDER BY policyName';

    const result = await request.query(query);
    res.json(result.recordset);
  } catch (err) {
    console.error('Error fetching catalog autocomplete', err);
    res.status(500).json({ error: 'Failed to fetch catalog' });
  }
};

// Policy Templates
export const autocompleteTemplates = async (req: Request, res: Response) => {
  const { agentId, typeId, categoryId, searchTerm } = req.query;
  try {
    const pool = await poolPromise;
    const request = pool.request();

    if (agentId) request.input('agentId', sql.UniqueIdentifier, agentId);
    if (typeId) request.input('typeId', sql.UniqueIdentifier, typeId);
    if (categoryId) request.input('categoryId', sql.UniqueIdentifier, categoryId);

    if (searchTerm && typeof searchTerm === 'string') {
      const cleanTerm = `%${searchTerm.trim()}%`;
      request.input('searchTerm', sql.NVarChar, cleanTerm);
    }

    let query = `
      SELECT templateId, templateName
      FROM PolicyTemplates
      WHERE isActive = 1
    `;

    if (agentId) query += ' AND agentId = @agentId';
    if (typeId) query += ' AND typeId = @typeId';
    if (categoryId) query += ' AND categoryId = @categoryId';
    if (searchTerm) query += ' AND templateName COLLATE SQL_Latin1_General_CP1_CI_AS LIKE @searchTerm';

    query += ' ORDER BY templateName';

    const result = await request.query(query);
    res.json(result.recordset);
  } catch (err) {
    console.error('Error fetching template autocomplete', err);
    res.status(500).json({ error: 'Failed to fetch templates' });
  }
};

// Client Policies
export const autocompleteClientPolicies = async (req: Request, res: Response) => {
  const { clientId, agentId, searchTerm } = req.query;
  try {
    const pool = await poolPromise;
    const request = pool.request();

    if (clientId) request.input('clientId', sql.UniqueIdentifier, clientId);
    if (agentId) request.input('agentId', sql.UniqueIdentifier, agentId);

    if (searchTerm && typeof searchTerm === 'string') {
      const cleanTerm = `%${searchTerm.trim()}%`;
      request.input('searchTerm', sql.NVarChar, cleanTerm);
    }

    let query = `
      SELECT policyId, policyName
      FROM ClientPolicies
      WHERE isActive = 1
    `;

    if (clientId) query += ' AND clientId = @clientId';
    if (agentId) query += ' AND agentId = @agentId';
    if (searchTerm) query += ' AND policyName COLLATE SQL_Latin1_General_CP1_CI_AS LIKE @searchTerm';

    query += ' ORDER BY policyName';

    const result = await request.query(query);
    res.json(result.recordset);
  } catch (err) {
    console.error('Error fetching client policies autocomplete', err);
    res.status(500).json({ error: 'Failed to fetch client policies' });
  }
};
