// controllers/clients.ts
import { Request, Response } from 'express';
import { ClientService } from '../services/client.service';

export class ClientController {
    private service: ClientService;

    constructor() {
        this.service = new ClientService();
    }

    async upsert(req: Request, res: Response) {
        try {
            const {
                clientId,
                agentId,
                firstName,
                surname,
                lastName,
                phoneNumber,
                email,
                address,
                nationalId,
                dateOfBirth,
                isClient,
                insuranceType,
                notes
            } = req.body;

            const id = await this.service.upsertClient(
                clientId || null,
                agentId,
                firstName,
                surname,
                lastName,
                phoneNumber,
                email,
                address,
                nationalId,
                dateOfBirth,
                isClient,
                insuranceType,
                notes
            );

            res.json({ success: true, clientId: id });
        } catch (err: any) {
            console.error('Upsert client error:', err);
            res.status(500).json({ success: false, error: err.message });
        }
    }

    async getAll(req: Request, res: Response) {
        try {
            const { agentId } = req.params;
            const { searchTerm, filterType, insuranceType } = req.query;

            const clients = await this.service.getClients(
                agentId,
                searchTerm as string,
                (filterType as any) || 'all',
                insuranceType as string
            );

            res.json(clients || []); // ✅ Always return array
        } catch (err: any) {
            console.error('Get all clients error:', err);
            res.status(500).json({ error: err.message });
        }
    }

    async getById(req: Request, res: Response) {
        try {
            const { clientId, agentId } = req.params;
            const data = await this.service.getClient(clientId, agentId);
            res.json(data);
        } catch (err: any) {
            console.error('Get client by ID error:', err);
            res.status(500).json({ error: err.message });
        }
    }

   async convert(req: Request, res: Response) {
    try {
        const { clientId, agentId } = req.params;
        const result = await this.service.convertToClient(clientId, agentId);

        res.json(result); // { success: boolean, message: string }
    } catch (err: any) {
        console.error('Convert client error:', err);
        res.status(500).json({ success: false, message: 'Server error during conversion' });
    }
}


    async delete(req: Request, res: Response) {
        try {
            const { clientId, agentId } = req.params;
            const rows = await this.service.deleteClient(clientId, agentId);
            res.json({ success: rows > 0 });
        } catch (err: any) {
            console.error('Delete client error:', err);
            res.status(500).json({ error: err.message });
        }
    }

    async statistics(req: Request, res: Response) {
        try {
            const { agentId } = req.params;
            const stats = await this.service.getClientStatistics(agentId);
            res.json(stats || {}); // ✅ Always return object
        } catch (err: any) {
            console.error('Get client statistics error:', err);
            res.status(500).json({ error: err.message });
        }
    }

    async birthdays(req: Request, res: Response) {
        try {
            const { agentId } = req.params;
            const data = await this.service.getTodaysBirthdays(agentId);
            res.json(data || []); // ✅ Always return array
        } catch (err: any) {
            console.error('Get birthdays error:', err);
            res.status(500).json({ error: err.message });
        }
    }

    async allClientsPaginated(req: Request, res: Response) {
        try {
            const { agentId } = req.params;
            const { searchTerm, insuranceType, isClient, pageNumber, pageSize } = req.query;
            const clients = await this.service.getAllClients(
                agentId,
                searchTerm as string,
                insuranceType as string,
                isClient === 'true',
                Number(pageNumber) || 1,
                Number(pageSize) || 50
            );
            res.json(clients || []);
        } catch (err: any) {
            console.error('Get all clients paginated error:', err);
            res.status(500).json({ error: err.message });
        }
    }

    async search(req: Request, res: Response) {
        try {
            const { agentId } = req.params;
            const { searchTerm } = req.query;
            const results = await this.service.searchClients(agentId, searchTerm as string);
            res.json(results || []);
        } catch (err: any) {
            console.error('Search clients error:', err);
            res.status(500).json({ error: err.message });
        }
    }

    async byInsuranceType(req: Request, res: Response) {
        try {
            const { agentId, insuranceType } = req.params;
            const clients = await this.service.getClientsByInsuranceType(agentId, insuranceType);
            res.json(clients || []);
        } catch (err: any) {
            console.error('Get clients by insurance type error:', err);
            res.status(500).json({ error: err.message });
        }
    }

    async withPolicies(req: Request, res: Response) {
        try {
            const { clientId, agentId } = req.params;
            const data = await this.service.getClientWithPolicies(clientId, agentId);
            res.json(data);
        } catch (err: any) {
            console.error('Get client with policies error:', err);
            res.status(500).json({ error: err.message });
        }
    }

    async create(req: Request, res: Response) {
        try {
            const client = await this.service.createClient(req.body);
            res.json(client);
        } catch (err: any) {
            console.error('Create client error:', err);
            res.status(500).json({ error: err.message });
        }
    }

    async update(req: Request, res: Response) {
        try {
            const client = await this.service.updateClient(req.body);
            res.json(client);
        } catch (err: any) {
            console.error('Update client error:', err);
            res.status(500).json({ error: err.message });
        }
    }

    async enhancedStatistics(req: Request, res: Response) {
        try {
            const { agentId } = req.params;
            const stats = await this.service.getEnhancedClientStatistics(agentId);
            res.json(stats || {});
        } catch (err: any) {
            console.error('Get enhanced statistics error:', err);
            res.status(500).json({ error: err.message });
        }
    }
}