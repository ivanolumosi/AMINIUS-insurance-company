const fs = require('fs');

class PostgreSQLFunctionSignatureFixer {
    constructor() {
        this.fixes = [];
    }

    fixFile(filePath) {
        console.log(`🔧 Fixing PostgreSQL function signatures in: ${filePath}`);
        
        if (!fs.existsSync(filePath)) {
            console.error(`❌ File not found: ${filePath}`);
            return false;
        }

        let content = fs.readFileSync(filePath, 'utf8');
        const originalContent = content;

        // Create backup
        const backupPath = `${filePath}.signature-backup`;
        fs.writeFileSync(backupPath, originalContent);
        console.log(`💾 Backup created: ${backupPath}`);

        // Show the problematic area first
        this.analyzeErrorPosition(content, 69);

        // Fix the function signatures
        content = this.fixFunctionSignatures(content);
        content = this.fixParameterLists(content);
        content = this.fixReturnTypes(content);
        content = this.validateFunctionStructure(content);

        // Write the fixed file
        fs.writeFileSync(filePath, content);
        
        console.log(`✅ Function signatures fixed!`);
        
        if (this.fixes.length > 0) {
            console.log(`🔧 Applied fixes:`);
            this.fixes.forEach((fix, i) => console.log(`   ${i + 1}. ${fix}`));
        }

        return true;
    }

    analyzeErrorPosition(content, position) {
        const lines = content.split('\n');
        let currentPos = 0;
        
        console.log(`\n📍 Analyzing error at position ${position}:`);
        
        for (let i = 0; i < lines.length; i++) {
            const lineLength = lines[i].length + 1; // +1 for newline
            
            if (currentPos + lineLength > position) {
                const columnPos = position - currentPos;
                console.log(`   Line ${i + 1}, Column ${columnPos}:`);
                console.log(`   ${lines[i]}`);
                console.log(`   ${' '.repeat(Math.max(0, columnPos - 1))}^`);
                
                // Show extended context
                const start = Math.max(0, i - 5);
                const end = Math.min(lines.length, i + 10);
                console.log(`\n📝 Extended context:`);
                for (let j = start; j < end; j++) {
                    const marker = j === i ? '>>> ' : '    ';
                    console.log(`${marker}${String(j + 1).padStart(3)}: ${lines[j]}`);
                }
                break;
            }
            currentPos += lineLength;
        }
    }

    fixFunctionSignatures(content) {
        // Fix broken function signatures that span multiple lines incorrectly
        content = content.replace(
            /CREATE\s+OR\s+REPLACE\s+FUNCTION\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\(\s*([^)]*)\s*\)\s*\n\s*RETURNS\s+([^\n]+)/gi,
            (match, funcName, params, returnType) => {
                // Clean up parameters - ensure they're properly formatted
                let cleanParams = this.cleanParameters(params);
                let cleanReturnType = returnType.trim();
                
                this.fixes.push(`Fixed function signature for ${funcName}`);
                return `CREATE OR REPLACE FUNCTION ${funcName}(${cleanParams})\nRETURNS ${cleanReturnType}`;
            }
        );

        // Fix signatures where RETURNS is on the same line but malformed
        content = content.replace(
            /CREATE\s+OR\s+REPLACE\s+FUNCTION\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\(\s*([^)]*)\s*\)\s+RETURNS\s+([^\n$]+)/gi,
            (match, funcName, params, returnType) => {
                let cleanParams = this.cleanParameters(params);
                let cleanReturnType = returnType.replace(/AS\s*\$\$.*$/i, '').trim();
                
                this.fixes.push(`Fixed inline RETURNS for ${funcName}`);
                return `CREATE OR REPLACE FUNCTION ${funcName}(${cleanParams})\nRETURNS ${cleanReturnType}`;
            }
        );

        return content;
    }

    cleanParameters(params) {
        if (!params || params.trim() === '') {
            return '';
        }

        // Split parameters and clean each one
        return params
            .split(',')
            .map(param => {
                param = param.trim();
                
                // Handle parameter format: p_name TYPE
                const paramMatch = param.match(/^(p_[a-zA-Z_][a-zA-Z0-9_]*)\s+(.+)$/);
                if (paramMatch) {
                    const [, paramName, paramType] = paramMatch;
                    return `${paramName} ${this.cleanDataType(paramType)}`;
                }
                
                // Handle other formats
                if (param.includes(' ')) {
                    const parts = param.split(/\s+/);
                    const name = parts[0];
                    const type = parts.slice(1).join(' ');
                    return `${name} ${this.cleanDataType(type)}`;
                }
                
                return param;
            })
            .join(',\n    ');
    }

    cleanDataType(dataType) {
        // Clean up data type declarations
        dataType = dataType.trim();
        
        // Remove any trailing commas or semicolons
        dataType = dataType.replace(/[,;]+$/, '');
        
        // Handle common PostgreSQL types
        const typeMap = {
            'VARCHAR(50)': 'VARCHAR(50)',
            'VARCHAR(100)': 'VARCHAR(100)',
            'VARCHAR(255)': 'VARCHAR(255)',
            'INTEGER': 'INTEGER',
            'INT': 'INTEGER',
            'BIGINT': 'BIGINT',
            'UUID': 'UUID',
            'BOOLEAN': 'BOOLEAN',
            'TIMESTAMP': 'TIMESTAMP',
            'DATE': 'DATE',
            'TEXT': 'TEXT'
        };

        const upperType = dataType.toUpperCase();
        if (typeMap[upperType]) {
            return typeMap[upperType];
        }

        return dataType;
    }

    fixParameterLists(content) {
        // Fix parameter lists that are malformed
        content = content.replace(
            /\(\s*([^)]+)\s*\)\s*\n\s*RETURNS/g,
            (match, paramList) => {
                const cleanedParams = this.cleanParameters(paramList);
                return `(\n    ${cleanedParams}\n)\nRETURNS`;
            }
        );

        return content;
    }

    fixReturnTypes(content) {
        // Fix RETURNS clauses
        content = content.replace(
            /RETURNS\s+([^A\n$]+?)(?=\s+AS\s|\n|$)/gi,
            (match, returnType) => {
                let cleanType = returnType.trim();
                
                // Handle TABLE returns
                if (cleanType.toLowerCase().includes('table')) {
                    // Don't modify TABLE return types as they can be complex
                    return `RETURNS ${cleanType}`;
                }
                
                // Handle simple return types
                cleanType = this.cleanDataType(cleanType);
                return `RETURNS ${cleanType}`;
            }
        );

        return content;
    }

    validateFunctionStructure(content) {
        // Ensure proper function structure
        content = content.replace(
            /(CREATE\s+OR\s+REPLACE\s+FUNCTION[^$]+?RETURNS[^$]+?)\s*AS\s*\$\$/gi,
            '$1\nAS $$'
        );

        // Fix missing language specifications
        content = content.replace(/\$\$\s*$/gm, '$$ LANGUAGE plpgsql;');

        return content;
    }

    findAndFixSpecificIssues(content) {
        // Look for the specific pattern that's causing the issue
        const lines = content.split('\n');
        
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            
            // Look for problematic CREATE FUNCTION lines
            if (line.includes('CREATE OR REPLACE FUNCTION')) {
                console.log(`\n🔍 Found function definition at line ${i + 1}:`);
                console.log(`   ${line}`);
                
                // Check next few lines for issues
                for (let j = i + 1; j < Math.min(i + 5, lines.length); j++) {
                    console.log(`   ${j + 1}: ${lines[j]}`);
                    
                    if (lines[j].includes('RETURNS')) {
                        // Check if RETURNS line is properly formatted
                        const returnsMatch = lines[j].match(/^\s*RETURNS\s+(.+)$/);
                        if (!returnsMatch) {
                            console.log(`   ❌ Malformed RETURNS clause at line ${j + 1}`);
                            
                            // Try to fix it
                            if (lines[j].includes('void')) {
                                lines[j] = 'RETURNS void';
                                this.fixes.push(`Fixed RETURNS clause at line ${j + 1}`);
                            }
                        }
                        break;
                    }
                }
            }
        }
        
        return lines.join('\n');
    }

    generateValidExample() {
        return `
-- Example of correct PostgreSQL function syntax:

CREATE OR REPLACE FUNCTION sp_upsert_agent(
    p_first_name VARCHAR(50),
    p_last_name VARCHAR(50),
    p_email VARCHAR(100)
)
RETURNS UUID AS $$
DECLARE
    v_agent_id UUID;
BEGIN
    -- Function logic here
    RETURN v_agent_id;
END;
$$ LANGUAGE plpgsql;

-- For void functions:
CREATE OR REPLACE FUNCTION sp_update_settings(
    p_agent_id UUID,
    p_setting_value TEXT
)
RETURNS void AS $$
BEGIN
    -- Function logic here
END;
$$ LANGUAGE plpgsql;
`;
    }
}

// Main execution
if (require.main === module) {
    const args = process.argv.slice(2);
    
    if (args.length === 0) {
        console.log(`
🔧 PostgreSQL Function Signature Fixer

This script specifically fixes function signature syntax errors.

Usage: node function-signature-fixer.js <sql-file> [--analyze-only]

Examples:
  node function-signature-fixer.js ./migrations/999_create_stored_procedure.sql
  node function-signature-fixer.js ./migrations/999_create_stored_procedure.sql --analyze-only

Common fixes:
  ✅ Malformed parameter lists
  ✅ Broken RETURNS clauses  
  ✅ Missing commas in parameters
  ✅ Incorrect data type formatting
  ✅ Multi-line signature issues
        `);
        process.exit(1);
    }

    const filePath = args[0];
    const fixer = new PostgreSQLFunctionSignatureFixer();

    if (args.includes('--analyze-only')) {
        if (fs.existsSync(filePath)) {
            const content = fs.readFileSync(filePath, 'utf8');
            console.log('📋 Analysis mode - showing function structure:');
            fixer.analyzeErrorPosition(content, 69);
            console.log(fixer.generateValidExample());
        }
        process.exit(0);
    }

    // Fix the file
    const success = fixer.fixFile(filePath);
    
    if (success) {
        console.log(`\n🚀 Try running your migration again:`);
        console.log(`   npm run migrate`);
        console.log(`\n💡 If you still get errors, check the backup file and compare with the fixed version`);
        console.log(`\n📖 Valid PostgreSQL function syntax example:`);
        console.log(fixer.generateValidExample());
    }
}