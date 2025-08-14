import { Request, Response } from 'express';
import { poolPromise } from '../../db';
import * as sql from 'mssql';

export class PolicyAutocompleteController {
  // ===== STATIC AUTOCOMPLETES =====

  public async companies(req: Request, res: Response) {
    try {
      const pool = await poolPromise;
      const result = await pool.request()
        .query(`SELECT companyId, companyName 
                FROM InsuranceCompanies 
                WHERE isActive = 1
                ORDER BY companyName`);
      res.json({ success: true, data: result.recordset });
    } catch (error) {
      console.error('Autocomplete companies error:', error);
      res.status(500).json({ success: false, error: 'Failed to fetch companies' });
    }
  }

  public async types(req: Request, res: Response) {
    try {
      const pool = await poolPromise;
      const result = await pool.request()
        .query(`SELECT typeId, typeName 
                FROM PolicyTypes 
                WHERE isActive = 1
                ORDER BY typeName`);
      res.json({ success: true, data: result.recordset });
    } catch (error) {
      console.error('Autocomplete types error:', error);
      res.status(500).json({ success: false, error: 'Failed to fetch types' });
    }
  }

  public async categories(req: Request, res: Response) {
    try {
      const pool = await poolPromise;
      const result = await pool.request()
        .query(`SELECT categoryId, categoryName 
                FROM PolicyCategories 
                WHERE isActive = 1
                ORDER BY categoryName`);
      res.json({ success: true, data: result.recordset });
    } catch (error) {
      console.error('Autocomplete categories error:', error);
      res.status(500).json({ success: false, error: 'Failed to fetch categories' });
    }
  }

  // ===== DYNAMIC AUTOCOMPLETES =====

  public async catalog(req: Request, res: Response) {
    const { agentId, companyId, typeId, searchTerm } = req.query;
    try {
      const pool = await poolPromise;
      const request = pool.request();

      if (agentId) request.input('agentId', sql.UniqueIdentifier, agentId);
      if (companyId) request.input('companyId', sql.UniqueIdentifier, companyId);
      if (typeId) request.input('typeId', sql.UniqueIdentifier, typeId);
      if (searchTerm) request.input('searchTerm', sql.NVarChar, `%${searchTerm}%`);

      let query = `
        SELECT policyCatalogId, policyName
        FROM PolicyCatalog
        WHERE isActive = 1
      `;

      if (agentId) query += ' AND agentId = @agentId';
      if (companyId) query += ' AND companyId = @companyId';
      if (typeId) query += ' AND typeId = @typeId';
      if (searchTerm) query += ' AND policyName LIKE @searchTerm';
      query += ' ORDER BY policyName';

      const result = await request.query(query);
      res.json({ success: true, data: result.recordset });
    } catch (error) {
      console.error('Autocomplete catalog error:', error);
      res.status(500).json({ success: false, error: 'Failed to fetch catalog' });
    }
  }

  public async templates(req: Request, res: Response) {
    const { agentId, typeId, categoryId, searchTerm } = req.query;
    try {
      const pool = await poolPromise;
      const request = pool.request();

      if (agentId) request.input('agentId', sql.UniqueIdentifier, agentId);
      if (typeId) request.input('typeId', sql.UniqueIdentifier, typeId);
      if (categoryId) request.input('categoryId', sql.UniqueIdentifier, categoryId);
      if (searchTerm) request.input('searchTerm', sql.NVarChar, `%${searchTerm}%`);

      let query = `
        SELECT templateId, templateName
        FROM PolicyTemplates
        WHERE isActive = 1
      `;

      if (agentId) query += ' AND agentId = @agentId';
      if (typeId) query += ' AND typeId = @typeId';
      if (categoryId) query += ' AND categoryId = @categoryId';
      if (searchTerm) query += ' AND templateName LIKE @searchTerm';
      query += ' ORDER BY templateName';

      const result = await request.query(query);
      res.json({ success: true, data: result.recordset });
    } catch (error) {
      console.error('Autocomplete templates error:', error);
      res.status(500).json({ success: false, error: 'Failed to fetch templates' });
    }
  }

  public async clientPolicies(req: Request, res: Response) {
    const { clientId, agentId, searchTerm } = req.query;
    try {
      const pool = await poolPromise;
      const request = pool.request();

      if (clientId) request.input('clientId', sql.UniqueIdentifier, clientId);
      if (agentId) request.input('agentId', sql.UniqueIdentifier, agentId);
      if (searchTerm) request.input('searchTerm', sql.NVarChar, `%${searchTerm}%`);

      let query = `
        SELECT policyId, policyName
        FROM ClientPolicies
        WHERE isActive = 1
      `;

      if (clientId) query += ' AND clientId = @clientId';
      if (agentId) query += ' AND agentId = @agentId';
      if (searchTerm) query += ' AND policyName LIKE @searchTerm';
      query += ' ORDER BY policyName';

      const result = await request.query(query);
      res.json({ success: true, data: result.recordset });
    } catch (error) {
      console.error('Autocomplete client policies error:', error);
      res.status(500).json({ success: false, error: 'Failed to fetch client policies' });
    }
  }
}
