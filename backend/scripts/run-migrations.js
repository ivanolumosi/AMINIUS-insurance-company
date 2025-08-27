// Load environment variables from .env file
require('dotenv').config();

const { Pool } = require('pg');
const fs = require('fs').promises;
const path = require('path');

// Configure database connection with proper SSL handling
const isDatabaseRemote = process.env.DATABASE_URL && (
    process.env.DATABASE_URL.includes('render.com') || 
    process.env.DATABASE_URL.includes('postgres://') && !process.env.DATABASE_URL.includes('localhost')
);

const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: isDatabaseRemote ? { rejectUnauthorized: false } : false
});

// Smart SQL parser that handles stored procedures and multiple statements
function parseSQL(sql) {
    // Remove comments and normalize whitespace
    const cleanedSQL = sql
        .replace(/--.*$/gm, '') // Remove single-line comments
        .replace(/\/\*[\s\S]*?\*\//g, '') // Remove multi-line comments
        .trim();

    if (!cleanedSQL) return [];

    // For stored procedures, we need special handling
    const statements = [];
    let currentStatement = '';
    let insideFunction = false;
    let dollarQuoteTag = null;
    let parenLevel = 0;

    const lines = cleanedSQL.split('\n');
    
    for (let line of lines) {
        line = line.trim();
        if (!line) continue;

        // Check for dollar quoting (used in stored procedures)
        const dollarQuoteMatch = line.match(/\$(\w*)\$/);
        if (dollarQuoteMatch) {
            if (!dollarQuoteTag) {
                dollarQuoteTag = dollarQuoteMatch[0];
                insideFunction = true;
            } else if (dollarQuoteMatch[0] === dollarQuoteTag) {
                dollarQuoteTag = null;
                insideFunction = false;
            }
        }

        // Track parentheses level
        if (!insideFunction) {
            parenLevel += (line.match(/\(/g) || []).length;
            parenLevel -= (line.match(/\)/g) || []).length;
        }

        currentStatement += line + '\n';

        // Check if we've reached the end of a statement
        if (!insideFunction && parenLevel === 0 && line.endsWith(';')) {
            statements.push(currentStatement.trim());
            currentStatement = '';
        }
    }

    // Add any remaining statement
    if (currentStatement.trim()) {
        statements.push(currentStatement.trim());
    }

    return statements.filter(stmt => stmt.length > 0);
}

async function runMigrations() {
    const client = await pool.connect();
    
    try {
        console.log('🚀 Starting database migrations...');
        
        // Create migrations table if it doesn't exist
        await client.query(`
            CREATE TABLE IF NOT EXISTS migrations (
                id SERIAL PRIMARY KEY,
                filename VARCHAR(255) NOT NULL UNIQUE,
                executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        `);
        console.log('✅ Migrations table ready');

        // Get list of migration files
        const migrationsDir = path.join(__dirname, '../migrations');
        
        try {
            const files = await fs.readdir(migrationsDir);
            const sqlFiles = files
                .filter(file => file.endsWith('.sql'))
                .sort();

            if (sqlFiles.length === 0) {
                console.log('⚠️  No migration files found');
                return;
            }

            console.log(`📋 Found ${sqlFiles.length} migration files:`, sqlFiles);

            for (const file of sqlFiles) {
                // Check if migration already executed
                const result = await client.query(
                    'SELECT id FROM migrations WHERE filename = $1',
                    [file]
                );

                if (result.rows.length === 0) {
                    console.log(`⏳ Running migration: ${file}`);
                    
                    // Read migration file
                    const filePath = path.join(migrationsDir, file);
                    const sql = await fs.readFile(filePath, 'utf8');
                    
                    // Execute migration in a transaction
                    await client.query('BEGIN');
                    try {
                        // For files with multiple statements, we need to split and execute them
                        // But handle stored procedures carefully
                        const statements = parseSQL(sql);
                        
                        for (const statement of statements) {
                            if (statement.trim()) {
                                console.log(`  📝 Executing: ${statement.substring(0, 80)}...`);
                                await client.query(statement);
                            }
                        }
                        
                        // Mark migration as completed
                        await client.query(
                            'INSERT INTO migrations (filename) VALUES ($1)',
                            [file]
                        );
                        
                        await client.query('COMMIT');
                        console.log(`✅ Migration ${file} completed successfully`);
                    } catch (error) {
                        await client.query('ROLLBACK');
                        console.error(`❌ Migration ${file} failed:`, error.message);
                        throw error;
                    }
                } else {
                    console.log(`⏭️  Migration ${file} already executed`);
                }
            }

            console.log('🎉 All migrations completed successfully!');
        } catch (dirError) {
            if (dirError.code === 'ENOENT') {
                console.log('⚠️  Migrations directory not found. Creating it...');
                await fs.mkdir(migrationsDir, { recursive: true });
                console.log('📁 Migrations directory created. Please add your .sql files.');
            } else {
                throw dirError;
            }
        }
    } catch (error) {
        console.error('💥 Migration process failed:', error);
        throw error;
    } finally {
        client.release();
        await pool.end();
    }
}

// Test database connection
async function testConnection() {
    if (!process.env.DATABASE_URL) {
        console.error('❌ DATABASE_URL environment variable is not set');
        console.error('💡 Please check your .env file has: DATABASE_URL=your_database_url');
        process.exit(1);
    }

    try {
        const client = await pool.connect();
        await client.query('SELECT NOW()');
        console.log('✅ Database connection successful');
        client.release();
    } catch (error) {
        console.error('❌ Database connection failed:', error.message);
        console.error('💡 Please verify your DATABASE_URL is correct');
        throw error;
    }
}

// Main execution
async function main() {
    try {
        await testConnection();
        await runMigrations();
    } catch (error) {
        console.error('Script execution failed:', error);
        process.exit(1);
    }
}

// Run migrations if this file is executed directly
if (require.main === module) {
    main();
}

module.exports = { runMigrations, testConnection };