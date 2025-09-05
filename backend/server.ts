import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import agentRoutes from './src/routes/agent.routes';
import analyticsRoutes from './src/routes/analytics.routes';
import appointmentRoutes from './src/routes/appointment';
import clientRoutes from './src/routes/clients.routes';
import policyRoutes from './src/routes/policy.routes';
import reminderRoutes from './src/routes/reminder.routes';
import notesRoutes from './src/routes/notes.routes';
import searchRoutes from './src/routes/search.routes';
import utilityRoutes from './src/routes/utility.routes';
import autocompleteRoutes from './src/routes/autocomplete.routes';
import "./src/cronjobs/cronjobs"; 
dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

/* ------------------  Middleware ------------------ */
// Allow requests from Angular dev server

app.use(cors({
  origin: 'https://aminius.netlify.app',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));


// ✅ Parse JSON and URL-encoded data (with size limit)
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

/* ------------------  Routes ------------------ */
app.use('/api', agentRoutes);
app.use('/api/analytics', analyticsRoutes);
app.use('/api/appointments', appointmentRoutes);
app.use('/api/clients', clientRoutes);
app.use('/api/policies',policyRoutes);
app.use('/api/reminders', reminderRoutes);
app.use('/api/notes', notesRoutes);
app.use('/api/search', searchRoutes);
app.use('/api/utility', utilityRoutes);
app.use('/api/autocomplete', autocompleteRoutes);

// // ✅ Root Route
app.get('/', (_req: Request, res: Response) => {
  res.send('🚀 Welcome to the API!');
});

// Catch all unhandled routes
app.use((_req: Request, res: Response) => {
  res.status(404).json({ message: 'Route not found' });
});

// Global error handler
app.use((err: any, _req: Request, res: Response, _next: NextFunction) => {
  console.error('Unhandled server error:', err);
  res.status(err.status || 500).json({
    message: err.message || 'Internal Server Error',
    stack: process.env.NODE_ENV === 'production' ? undefined : err.stack
  });
});

/* ------------------  Start Server ------------------ */
app.listen(PORT, () => {
  console.log(`🚀 Server running at port`);
});
