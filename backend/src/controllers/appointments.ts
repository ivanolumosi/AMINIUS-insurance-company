import { Request, Response } from 'express';
import { AppointmentService } from '../services/appointment.service';
import { 
    AppointmentFilters, 
    CreateAppointmentRequest, 
    UpdateAppointmentRequest 
} from '../interfaces/appointment';

export class AppointmentController {
    private appointmentService: AppointmentService;

    constructor() {
        this.appointmentService = new AppointmentService();
        console.log('🚀 AppointmentController initialized with PostgreSQL support');
    }

    /** Utility: validate a UUID format */
    private isValidUuid(uuid: string): boolean {
        const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
        return uuidRegex.test(uuid);
    }

    /** DRY helper to validate agentId in all endpoints */
    private validateAgentId(req: Request, res: Response): string | null {
        const { agentId } = req.params;
        if (!agentId) {
            res.status(400).json({ 
                success: false,
                message: 'AgentId is required' 
            });
            return null;
        }
        if (!this.isValidUuid(agentId)) {
            res.status(400).json({ 
                success: false,
                message: 'Invalid AgentId UUID format' 
            });
            return null;
        }
        return agentId;
    }

    /** Handle PostgreSQL specific errors */
    private handlePostgreSQLError(error: any, defaultMessage: string) {
        let statusCode = 500;
        let errorMessage = defaultMessage;
        
        if (error.code) {
            console.error('PostgreSQL error code:', error.code);
            console.error('PostgreSQL error detail:', error.detail);
            
            switch (error.code) {
                case '23505': // unique_violation
                    statusCode = 409;
                    errorMessage = "Appointment with this data already exists";
                    break;
                case '23503': // foreign_key_violation
                    statusCode = 400;
                    errorMessage = "Invalid reference to client or agent";
                    break;
                case '23514': // check_violation
                    statusCode = 400;
                    errorMessage = "Data validation failed";
                    break;
                case '23502': // not_null_violation
                    statusCode = 400;
                    errorMessage = "Required field is missing";
                    break;
                case '42P01': // undefined_table
                    statusCode = 500;
                    errorMessage = "Database configuration error";
                    break;
                default:
                    errorMessage = "Database error occurred";
            }
        }

        return {
            statusCode,
            response: {
                success: false,
                message: errorMessage,
                error: error.message,
                errorCode: error.code || null,
                ...(process.env.NODE_ENV === 'development' && { 
                    stack: error.stack,
                    detail: error.detail 
                })
            }
        };
    }

    /** Search clients for autocomplete */
    public async searchClients(req: Request, res: Response) {
        console.log('🔍 SEARCH CLIENTS - Controller method started');
        
        const agentId = this.validateAgentId(req, res);
        if (!agentId) return;

        const { q } = req.query;
        if (!q || typeof q !== 'string' || q.trim().length < 1) {
            return res.status(400).json({ 
                success: false,
                message: 'Search term (q) is required and must be at least 1 character' 
            });
        }

        try {
            console.log('🔍 Searching for clients with term:', q.trim());
            const clients = await this.appointmentService.searchClientsForAutocomplete(q.trim(), agentId);
            
            console.log('✅ SEARCH CLIENTS - Found clients:', clients.length);
            res.status(200).json({
                success: true,
                data: clients,
                message: "Clients retrieved successfully",
                count: clients.length
            });
        } catch (error: any) {
            console.error('❌ SEARCH CLIENTS - Error:', error);
            const errorResponse = this.handlePostgreSQLError(error, 'Error searching clients');
            res.status(errorResponse.statusCode).json(errorResponse.response);
        }
    }

    /** Create appointment */
    public async create(req: Request, res: Response) {
        console.log('📅 CREATE APPOINTMENT - Controller method started');
        console.log('📅 Request body:', JSON.stringify(req.body, null, 2));
        
        const agentId = this.validateAgentId(req, res);
        if (!agentId) return;

        try {
            // Validate required fields
            const requiredFields = ['clientId', 'title', 'appointmentDate', 'startTime', 'endTime', 'type'];
            const missingFields = requiredFields.filter(field => !req.body[field]);
            
            if (missingFields.length > 0) {
                console.error('❌ CREATE APPOINTMENT - Missing required fields:', missingFields);
                return res.status(400).json({
                    success: false,
                    message: "Missing required fields",
                    error: `Missing fields: ${missingFields.join(', ')}`,
                    requiredFields,
                    receivedFields: Object.keys(req.body)
                });
            }

            // Validate clientId UUID format
            if (!this.isValidUuid(req.body.clientId)) {
                return res.status(400).json({
                    success: false,
                    message: "Invalid ClientId UUID format"
                });
            }

            // Validate date format
            const appointmentDate = new Date(req.body.appointmentDate);
            if (isNaN(appointmentDate.getTime())) {
                return res.status(400).json({
                    success: false,
                    message: "Invalid appointment date format"
                });
            }

            // Validate time formats (basic HH:MM or HH:MM:SS)
            const timeRegex = /^([0-1]?[0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$/;
            if (!timeRegex.test(req.body.startTime) || !timeRegex.test(req.body.endTime)) {
                return res.status(400).json({
                    success: false,
                    message: "Invalid time format. Use HH:MM or HH:MM:SS format"
                });
            }

            console.log('📅 Creating appointment for agent:', agentId);
            const result = await this.appointmentService.createAppointment(agentId, req.body as CreateAppointmentRequest);
            
            console.log('✅ CREATE APPOINTMENT - Service returned:', result);
            res.status(result.success ? 201 : 400).json({
                success: result.success,
                data: result,
                message: result.success ? "Appointment created successfully" : "Failed to create appointment"
            });
        } catch (error: any) {
            console.error('❌ CREATE APPOINTMENT - Error:', error);
            const errorResponse = this.handlePostgreSQLError(error, 'Error creating appointment');
            res.status(errorResponse.statusCode).json(errorResponse.response);
        }
    }

    /** Update appointment */
    public async update(req: Request, res: Response) {
        console.log('✏️ UPDATE APPOINTMENT - Controller method started');
        console.log('✏️ Request body:', JSON.stringify(req.body, null, 2));
        
        const agentId = this.validateAgentId(req, res);
        if (!agentId) return;

        const { appointmentId } = req.params;
        if (!this.isValidUuid(appointmentId)) {
            return res.status(400).json({ 
                success: false,
                message: 'Invalid AppointmentId UUID format' 
            });
        }

        try {
            // Validate date if provided
            if (req.body.appointmentDate) {
                const appointmentDate = new Date(req.body.appointmentDate);
                if (isNaN(appointmentDate.getTime())) {
                    return res.status(400).json({
                        success: false,
                        message: "Invalid appointment date format"
                    });
                }
            }

            // Validate time formats if provided
            const timeRegex = /^([0-1]?[0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$/;
            if (req.body.startTime && !timeRegex.test(req.body.startTime)) {
                return res.status(400).json({
                    success: false,
                    message: "Invalid start time format. Use HH:MM or HH:MM:SS format"
                });
            }
            if (req.body.endTime && !timeRegex.test(req.body.endTime)) {
                return res.status(400).json({
                    success: false,
                    message: "Invalid end time format. Use HH:MM or HH:MM:SS format"
                });
            }

            console.log('✏️ Updating appointment:', appointmentId);
            const result = await this.appointmentService.updateAppointment(appointmentId, agentId, req.body as UpdateAppointmentRequest);
            
            console.log('✅ UPDATE APPOINTMENT - Service returned:', result);
            res.status(result.success ? 200 : 404).json({
                success: result.success,
                data: result,
                message: result.success ? "Appointment updated successfully" : "Appointment not found or update failed"
            });
        } catch (error: any) {
            console.error('❌ UPDATE APPOINTMENT - Error:', error);
            const errorResponse = this.handlePostgreSQLError(error, 'Error updating appointment');
            res.status(errorResponse.statusCode).json(errorResponse.response);
        }
    }

    /** Get appointment by ID */
    public async getById(req: Request, res: Response) {
        console.log('🔍 GET APPOINTMENT BY ID - Controller method started');
        
        const agentId = this.validateAgentId(req, res);
        if (!agentId) return;

        const { appointmentId } = req.params;
        if (!this.isValidUuid(appointmentId)) {
            return res.status(400).json({ 
                success: false,
                message: 'Invalid AppointmentId UUID format' 
            });
        }

        try {
            console.log('🔍 Fetching appointment:', appointmentId);
            const appointment = await this.appointmentService.getAppointmentById(appointmentId, agentId);
            
            if (!appointment) {
                console.log('🔍 Appointment not found');
                return res.status(404).json({ 
                    success: false,
                    message: 'Appointment not found' 
                });
            }

            console.log('✅ GET APPOINTMENT BY ID - Found appointment');
            res.json({
                success: true,
                data: appointment,
                message: "Appointment retrieved successfully"
            });
        } catch (error: any) {
            console.error('❌ GET APPOINTMENT BY ID - Error:', error);
            const errorResponse = this.handlePostgreSQLError(error, 'Error fetching appointment');
            res.status(errorResponse.statusCode).json(errorResponse.response);
        }
    }

    /** Get all appointments with filters */
    public async getAll(req: Request, res: Response) {
        console.log('📋 GET ALL APPOINTMENTS - Controller method started');
        console.log('📋 Query params:', JSON.stringify(req.query, null, 2));
        
        const agentId = this.validateAgentId(req, res);
        if (!agentId) return;

        try {
            const filters: AppointmentFilters = {
                startDate: req.query.startDate ? new Date(req.query.startDate as string) : undefined,
                endDate: req.query.endDate ? new Date(req.query.endDate as string) : undefined,
                statusFilter: req.query.status as string || 'all',
                typeFilter: req.query.type as string || 'all',
                priority: req.query.priority as 'High' | 'Medium' | 'Low',
                clientId: req.query.clientId as string,
                searchTerm: req.query.searchTerm as string,
                pageSize: parseInt(req.query.pageSize as string) || 50,
                pageNumber: parseInt(req.query.pageNumber as string) || 1
            };

            // Validate date filters if provided
            if (filters.startDate && isNaN(filters.startDate.getTime())) {
                return res.status(400).json({
                    success: false,
                    message: "Invalid startDate format"
                });
            }
            if (filters.endDate && isNaN(filters.endDate.getTime())) {
                return res.status(400).json({
                    success: false,
                    message: "Invalid endDate format"
                });
            }

            // Validate clientId if provided
            if (filters.clientId && !this.isValidUuid(filters.clientId)) {
                return res.status(400).json({
                    success: false,
                    message: "Invalid ClientId UUID format"
                });
            }

            console.log('📋 Fetching appointments with filters:', filters);
            const result = await this.appointmentService.getAllAppointments(agentId, filters);
            
            console.log('✅ GET ALL APPOINTMENTS - Found appointments:', result.appointments?.length || 0);
            res.json({
                success: true,
                data: result,
                message: "Appointments retrieved successfully",
                pagination: {
                    total: result.total || 0,
                    pageSize: filters.pageSize,
                    pageNumber: filters.pageNumber,
                    totalPages: Math.ceil((result.total || 0) / filters.pageSize!)
                }
            });
        } catch (error: any) {
            console.error('❌ GET ALL APPOINTMENTS - Error:', error);
            const errorResponse = this.handlePostgreSQLError(error, 'Error fetching appointments');
            res.status(errorResponse.statusCode).json(errorResponse.response);
        }
    }

    /** Get week view appointments */
    public async getWeekView(req: Request, res: Response) {
        console.log('📅 GET WEEK VIEW - Controller method started');
        
        const agentId = this.validateAgentId(req, res);
        if (!agentId) return;

        try {
            console.log('📅 Fetching week view appointments');
            const appointments = await this.appointmentService.getWeekViewAppointments(agentId);
            
            console.log('✅ GET WEEK VIEW - Found appointments:', appointments.length);
            res.json({
                success: true,
                data: appointments,
                message: "Week view appointments retrieved successfully",
                count: appointments.length
            });
        } catch (error: any) {
            console.error('❌ GET WEEK VIEW - Error:', error);
            const errorResponse = this.handlePostgreSQLError(error, 'Error fetching week view appointments');
            res.status(errorResponse.statusCode).json(errorResponse.response);
        }
    }

    /** Get calendar appointments */
    public async getCalendar(req: Request, res: Response) {
        console.log('🗓️ GET CALENDAR - Controller method started');
        
        const agentId = this.validateAgentId(req, res);
        if (!agentId) return;

        const { month, year } = req.query;
        if (!month || !year || isNaN(Number(month)) || isNaN(Number(year))) {
            return res.status(400).json({ 
                success: false,
                message: 'Invalid or missing month/year parameters' 
            });
        }

        const monthNum = Number(month);
        const yearNum = Number(year);

        if (monthNum < 1 || monthNum > 12) {
            return res.status(400).json({
                success: false,
                message: 'Month must be between 1 and 12'
            });
        }

        if (yearNum < 1900 || yearNum > 2100) {
            return res.status(400).json({
                success: false,
                message: 'Year must be between 1900 and 2100'
            });
        }

        try {
            console.log('🗓️ Fetching calendar appointments for:', `${yearNum}-${monthNum}`);
            const appointments = await this.appointmentService.getCalendarAppointments(agentId, monthNum, yearNum);
            
            console.log('✅ GET CALENDAR - Found appointments:', appointments.length);
            res.json({
                success: true,
                data: appointments,
                message: "Calendar appointments retrieved successfully",
                count: appointments.length,
                period: { month: monthNum, year: yearNum }
            });
        } catch (error: any) {
            console.error('❌ GET CALENDAR - Error:', error);
            const errorResponse = this.handlePostgreSQLError(error, 'Error fetching calendar appointments');
            res.status(errorResponse.statusCode).json(errorResponse.response);
        }
    }

    /** Check time conflicts */
    public async checkConflicts(req: Request, res: Response) {
        console.log('⏰ CHECK CONFLICTS - Controller method started');
        
        const agentId = this.validateAgentId(req, res);
        if (!agentId) return;

        const { appointmentDate, startTime, endTime } = req.body;

        // Validate required fields
        if (!appointmentDate || !startTime || !endTime) {
            return res.status(400).json({
                success: false,
                message: 'appointmentDate, startTime, and endTime are required'
            });
        }

        // Validate date format
        if (isNaN(Date.parse(appointmentDate))) {
            return res.status(400).json({
                success: false,
                message: 'Invalid appointmentDate format'
            });
        }

        // Validate time formats
        const timeRegex = /^([0-1]?[0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$/;
        if (!timeRegex.test(startTime) || !timeRegex.test(endTime)) {
            return res.status(400).json({
                success: false,
                message: 'Invalid time format. Use HH:MM or HH:MM:SS format'
            });
        }

        try {
            console.log('⏰ Checking conflicts for:', { appointmentDate, startTime, endTime });
            const conflicts = await this.appointmentService.checkTimeConflicts(agentId, appointmentDate, startTime, endTime);
            
            console.log('✅ CHECK CONFLICTS - Found conflicts:', conflicts.length);
            res.json({
                success: true,
                data: {
                    hasConflict: conflicts.length > 0,
                    conflictCount: conflicts.length,
                    conflicts: conflicts
                },
                message: conflicts.length > 0 ? "Time conflicts found" : "No time conflicts"
            });
        } catch (error: any) {
            console.error('❌ CHECK CONFLICTS - Error:', error);
            const errorResponse = this.handlePostgreSQLError(error, 'Error checking time conflicts');
            res.status(errorResponse.statusCode).json(errorResponse.response);
        }
    }

    /** Delete appointment */
    public async delete(req: Request, res: Response) {
        console.log('🗑️ DELETE APPOINTMENT - Controller method started');
        
        const agentId = this.validateAgentId(req, res);
        if (!agentId) return;

        const { appointmentId } = req.params;
        if (!this.isValidUuid(appointmentId)) {
            return res.status(400).json({ 
                success: false,
                message: 'Invalid AppointmentId UUID format' 
            });
        }

        try {
            console.log('🗑️ Deleting appointment:', appointmentId);
            const result = await this.appointmentService.deleteAppointment(agentId, appointmentId);
            
            console.log('✅ DELETE APPOINTMENT - Service returned:', result);
            res.json({
                success: result.success,
                data: result,
                message: result.success ? "Appointment deleted successfully" : "Appointment not found or delete failed"
            });
        } catch (error: any) {
            console.error('❌ DELETE APPOINTMENT - Error:', error);
            const errorResponse = this.handlePostgreSQLError(error, 'Error deleting appointment');
            res.status(errorResponse.statusCode).json(errorResponse.response);
        }
    }

    /** Get appointment statistics */
    public async getStatistics(req: Request, res: Response) {
        console.log('📊 GET STATISTICS - Controller method started');
        
        const agentId = this.validateAgentId(req, res);
        if (!agentId) return;

        try {
            console.log('📊 Fetching appointment statistics');
            const stats = await this.appointmentService.getAppointmentStatistics(agentId);
            
            console.log('✅ GET STATISTICS - Statistics retrieved:', stats);
            res.json({
                success: true,
                data: stats,
                message: "Statistics retrieved successfully"
            });
        } catch (error: any) {
            console.error('❌ GET STATISTICS - Error:', error);
            const errorResponse = this.handlePostgreSQLError(error, 'Error fetching appointment statistics');
            res.status(errorResponse.statusCode).json(errorResponse.response);
        }
    }
}