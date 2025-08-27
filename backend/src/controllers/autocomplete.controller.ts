import { Request, Response } from 'express';
import { poolPromise } from '../../db';

export class PolicyAutocompleteController {
  // ===== STATIC AUTOCOMPLETES =====

  public async companies(req: Request, res: Response) {
    try {
      const pool = await poolPromise;
      const result = await pool.query(`
        SELECT company_id as "companyId", company_name as "companyName" 
        FROM insurance_companies 
        WHERE is_active = true
        ORDER BY company_name
      `);
      res.json({ success: true, data: result.rows });
    } catch (error) {
      console.error('Autocomplete companies error:', error);
      res.status(500).json({ success: false, error: 'Failed to fetch companies' });
    }
  }

  public async types(req: Request, res: Response) {
    try {
      const pool = await poolPromise;
      const result = await pool.query(`
        SELECT type_id as "typeId", type_name as "typeName" 
        FROM policy_types 
        WHERE is_active = true
        ORDER BY type_name
      `);
      res.json({ success: true, data: result.rows });
    } catch (error) {
      console.error('Autocomplete types error:', error);
      res.status(500).json({ success: false, error: 'Failed to fetch types' });
    }
  }

  public async categories(req: Request, res: Response) {
    try {
      const pool = await poolPromise;
      const result = await pool.query(`
        SELECT category_id as "categoryId", category_name as "categoryName" 
        FROM policy_categories 
        WHERE is_active = true
        ORDER BY category_name
      `);
      res.json({ success: true, data: result.rows });
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
      
      let query = `
        SELECT policy_catalog_id as "policyCatalogId", policy_name as "policyName"
        FROM policy_catalog
        WHERE is_active = true
      `;
      
      const params: any[] = [];
      let paramCount = 0;

      if (agentId) {
        paramCount++;
        query += ` AND agent_id = $${paramCount}`;
        params.push(agentId);
      }

      if (companyId) {
        paramCount++;
        query += ` AND company_id = $${paramCount}`;
        params.push(companyId);
      }

      if (typeId) {
        paramCount++;
        query += ` AND type_id = $${paramCount}`;
        params.push(typeId);
      }

      if (searchTerm && typeof searchTerm === 'string') {
        paramCount++;
        query += ` AND policy_name ILIKE $${paramCount}`;
        params.push(`%${searchTerm.trim()}%`);
      }

      query += ' ORDER BY policy_name';

      const result = await pool.query(query, params);
      res.json({ success: true, data: result.rows });
    } catch (error) {
      console.error('Autocomplete catalog error:', error);
      res.status(500).json({ success: false, error: 'Failed to fetch catalog' });
    }
  }

  public async templates(req: Request, res: Response) {
    const { agentId, typeId, categoryId, searchTerm } = req.query;
    try {
      const pool = await poolPromise;
      
      let query = `
        SELECT template_id as "templateId", template_name as "templateName"
        FROM policy_templates
        WHERE is_active = true
      `;
      
      const params: any[] = [];
      let paramCount = 0;

      if (agentId) {
        paramCount++;
        query += ` AND agent_id = $${paramCount}`;
        params.push(agentId);
      }

      if (typeId) {
        paramCount++;
        query += ` AND type_id = $${paramCount}`;
        params.push(typeId);
      }

      if (categoryId) {
        paramCount++;
        query += ` AND category_id = $${paramCount}`;
        params.push(categoryId);
      }

      if (searchTerm && typeof searchTerm === 'string') {
        paramCount++;
        query += ` AND template_name ILIKE $${paramCount}`;
        params.push(`%${searchTerm.trim()}%`);
      }

      query += ' ORDER BY template_name';

      const result = await pool.query(query, params);
      res.json({ success: true, data: result.rows });
    } catch (error) {
      console.error('Autocomplete templates error:', error);
      res.status(500).json({ success: false, error: 'Failed to fetch templates' });
    }
  }

  public async clientPolicies(req: Request, res: Response) {
    const { clientId, agentId, searchTerm } = req.query;
    try {
      const pool = await poolPromise;
      
      let query = `
        SELECT policy_id as "policyId", policy_name as "policyName"
        FROM client_policies
        WHERE is_active = true
      `;
      
      const params: any[] = [];
      let paramCount = 0;

      if (clientId) {
        paramCount++;
        query += ` AND client_id = $${paramCount}`;
        params.push(clientId);
      }

      if (agentId) {
        paramCount++;
        query += ` AND agent_id = $${paramCount}`;
        params.push(agentId);
      }

      if (searchTerm && typeof searchTerm === 'string') {
        paramCount++;
        query += ` AND policy_name ILIKE $${paramCount}`;
        params.push(`%${searchTerm.trim()}%`);
      }

      query += ' ORDER BY policy_name';

      const result = await pool.query(query, params);
      res.json({ success: true, data: result.rows });
    } catch (error) {
      console.error('Autocomplete client policies error:', error);
      res.status(500).json({ success: false, error: 'Failed to fetch client policies' });
    }
  }
}