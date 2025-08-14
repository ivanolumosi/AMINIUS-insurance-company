import { Request, Response } from 'express';
import { AppointmentService } from '../services/appointment.service';

const appointmentService = new AppointmentService();
const service = new AppointmentService();

export class AppointmentController {


    /** Utility: validate a GUID format */
    private isValidGuid(guid: string): boolean {
        const guidRegex = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;
        return guidRegex.test(guid);
    }

    /** DRY helper to validate agentId in all endpoints */
    private validateAgentId(req: Request, res: Response): string | null {
        const { agentId } = req.params;
        if (!this.isValidGuid(agentId)) {
            res.status(400).json({ message: 'Invalid AgentId GUID format' });
            return null;
        }
        return agentId;
    }
    
  public async searchClients(req: Request, res: Response) {
    const agentId = this.validateAgentId(req, res);
    if (!agentId) return;

    const { q } = req.query;
    if (!q || typeof q !== 'string' || q.trim().length < 1) {
        res.status(400).json({ message: 'Search term (q) is required' });
        return;
    }

    try {
        const result = await appointmentService.searchClientsForAutocomplete(q.trim(), agentId);
        res.status(200).json(result);
    } catch (error) {
        console.error('Error searching clients:', error);
        res.status(500).json({ message: 'Error searching clients', error: (error as Error).message });
    }
}
   

    public async create(req: Request, res: Response) {
  const agentId = this.validateAgentId(req, res);
  if (!agentId) return;

  console.log('Incoming appointment payload:', req.body); 
  console.log('Agent ID:', agentId);

  try {
    const result = await appointmentService.createAppointment(agentId, req.body);
    res.status(result.success ? 201 : 400).json(result);
  } catch (error) {
    console.error('Error in createAppointment:', error); // 
    res.status(500).json({ message: 'Error creating appointment', error: (error as Error).message });
  }
}


    public async update(req: Request, res: Response) {
        const agentId = this.validateAgentId(req, res);
        if (!agentId) return;

        const { appointmentId } = req.params;
        if (!this.isValidGuid(appointmentId)) {
            return res.status(400).json({ message: 'Invalid AppointmentId GUID format' });
        }

        try {
            const result = await appointmentService.updateAppointment(appointmentId, agentId, req.body);
            res.status(result.success ? 200 : 400).json(result);
        } catch (error) {
            res.status(500).json({ message: 'Error updating appointment', error: (error as Error).message });
        }
    }

    public async getById(req: Request, res: Response) {
        const agentId = this.validateAgentId(req, res);
        if (!agentId) return;

        const { appointmentId } = req.params;
        if (!this.isValidGuid(appointmentId)) {
            return res.status(400).json({ message: 'Invalid AppointmentId GUID format' });
        }

        try {
            const appointment = await appointmentService.getAppointmentById(appointmentId, agentId);
            if (!appointment) return res.status(404).json({ message: 'Appointment not found' });
            res.json(appointment);
        } catch (error) {
            res.status(500).json({ message: 'Error fetching appointment', error: (error as Error).message });
        }
    }

    public async getAll(req: Request, res: Response) {
        const agentId = this.validateAgentId(req, res);
        if (!agentId) return;

        try {
            const result = await appointmentService.getAllAppointments(agentId, req.query as any);
            res.json(result);
        } catch (error) {
            res.status(500).json({ message: 'Error fetching appointments', error: (error as Error).message });
        }
    }

   public async getToday(req: Request, res: Response) {
    const agentId = this.validateAgentId(req, res);
    if (!agentId) return;

    try {
        const appointments = await appointmentService.getTodayAppointments(agentId);
        console.log('Appointments for today:', appointments); // Log data
        res.json(appointments);
    } catch (error) {
        res.status(500).json({ message: 'Error fetching today appointments', error: (error as Error).message });
    }
}



    public async getAllAppointments(req: any, res: any) {
        try {
            const agentId = req.params.agentId;
            const filters = {
                startDate: req.query.startDate || null,
                endDate: req.query.endDate || null,
                statusFilter: req.query.status || 'all',
                typeFilter: req.query.type || 'all',
                priority: req.query.priority || null,
                clientId: req.query.clientId || null,
                searchTerm: req.query.searchTerm || null,
                pageSize: parseInt(req.query.pageSize) || 50,
                pageNumber: parseInt(req.query.pageNumber) || 1
            };
            
            const result = await service.getAllAppointments(agentId, filters);
            res.json(result);
        } catch (err) {
            console.error('Error getting all appointments:', err);
            res.status(500).json({ message: 'Failed to get appointments' });
        }
    }



    public async getForDate(req: Request, res: Response) {
        const agentId = this.validateAgentId(req, res);
        if (!agentId) return;

        const { appointmentDate } = req.query;
        if (!appointmentDate || isNaN(Date.parse(appointmentDate as string))) {
            return res.status(400).json({ message: 'Invalid or missing appointmentDate' });
        }

        try {
            const appointments = await appointmentService.getAppointmentsForDate(agentId, new Date(appointmentDate as string));
            res.json(appointments);
        } catch (error) {
            res.status(500).json({ message: 'Error fetching appointments for date', error: (error as Error).message });
        }
    }

    public async getWeekView(req: Request, res: Response) {
        const agentId = this.validateAgentId(req, res);
        if (!agentId) return;

        try {
            const { weekStartDate } = req.query;
            const date = weekStartDate ? new Date(weekStartDate as string) : undefined;
            if (weekStartDate && isNaN(date!.getTime())) {
                return res.status(400).json({ message: 'Invalid weekStartDate' });
            }

            const appointments = await appointmentService.getWeekViewAppointments(agentId, date);
            res.json(appointments);
        } catch (error) {
            res.status(500).json({ message: 'Error fetching week view appointments', error: (error as Error).message });
        }
    }

    public async getCalendar(req: Request, res: Response) {
        const agentId = this.validateAgentId(req, res);
        if (!agentId) return;

        const { month, year } = req.query;
        if (!month || !year || isNaN(Number(month)) || isNaN(Number(year))) {
            return res.status(400).json({ message: 'Invalid or missing month/year' });
        }

        try {
            const appointments = await appointmentService.getCalendarAppointments(agentId, Number(month), Number(year));
            res.json(appointments);
        } catch (error) {
            res.status(500).json({ message: 'Error fetching calendar appointments', error: (error as Error).message });
        }
    }

    public async updateStatus(req: Request, res: Response) {
        const agentId = this.validateAgentId(req, res);
        if (!agentId) return;

        const { appointmentId } = req.params;
        if (!this.isValidGuid(appointmentId)) {
            return res.status(400).json({ message: 'Invalid AppointmentId GUID format' });
        }

        const { status } = req.body;
        if (!status) {
            return res.status(400).json({ message: 'Missing status' });
        }

        try {
            const rowsAffected = await appointmentService.updateAppointmentStatus(appointmentId, agentId, status);
            res.json({ rowsAffected });
        } catch (error) {
            res.status(500).json({ message: 'Error updating appointment status', error: (error as Error).message });
        }
    }

    public async delete(req: Request, res: Response) {
        const agentId = this.validateAgentId(req, res);
        if (!agentId) return;

        const { appointmentId } = req.params;
        if (!this.isValidGuid(appointmentId)) {
            return res.status(400).json({ message: 'Invalid AppointmentId GUID format' });
        }

        try {
            const rowsAffected = await appointmentService.deleteAppointment(appointmentId, agentId);
            res.json({ rowsAffected });
        } catch (error) {
            res.status(500).json({ message: 'Error deleting appointment', error: (error as Error).message });
        }
    }

    public async search(req: Request, res: Response) {
        const agentId = this.validateAgentId(req, res);
        if (!agentId) return;

        const { searchTerm } = req.query;
        if (!searchTerm) {
            return res.status(400).json({ message: 'Missing searchTerm' });
        }

        try {
            const results = await appointmentService.searchAppointments(agentId, searchTerm as string);
            res.json(results);
        } catch (error) {
            res.status(500).json({ message: 'Error searching appointments', error: (error as Error).message });
        }
    }

    public async checkConflicts(req: Request, res: Response) {
        const agentId = this.validateAgentId(req, res);
        if (!agentId) return;

        const { appointmentDate, startTime, endTime, excludeAppointmentId } = req.body;
        if (!appointmentDate || isNaN(Date.parse(appointmentDate))) {
            return res.status(400).json({ message: 'Invalid or missing appointmentDate' });
        }
        if (!startTime || !endTime) {
            return res.status(400).json({ message: 'Missing startTime or endTime' });
        }

        try {
            const result = await appointmentService.checkTimeConflicts(
                agentId,
                new Date(appointmentDate),
                startTime,
                endTime,
                excludeAppointmentId
            );
            res.json(result);
        } catch (error) {
            res.status(500).json({ message: 'Error checking time conflicts', error: (error as Error).message });
        }
    }

    public async getStatistics(req: Request, res: Response) {
        const agentId = this.validateAgentId(req, res);
        if (!agentId) return;

        try {
            const stats = await appointmentService.getAppointmentStatistics(agentId);
            res.json(stats);
        } catch (error) {
            res.status(500).json({ message: 'Error fetching appointment statistics', error: (error as Error).message });
        }
    }
}
