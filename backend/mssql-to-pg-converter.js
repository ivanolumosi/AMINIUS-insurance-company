const fs = require('fs');
const path = require('path');

class MSSQLToPostgreSQLConverter {
    constructor() {
        this.fixes = [];
        this.warnings = [];
    }

    convertFile(filePath) {
        console.log(`🔄 Converting MSSQL procedures to PostgreSQL: ${filePath}`);
        
        if (!fs.existsSync(filePath)) {
            console.error(`❌ File not found: ${filePath}`);
            return false;
        }

        let content = fs.readFileSync(filePath, 'utf8');
        const originalContent = content;

        // Create backup
        const backupPath = `${filePath}.mssql-backup`;
        fs.writeFileSync(backupPath, originalContent);
        console.log(`💾 Backup created: ${backupPath}`);

        // Apply all conversions
        content = this.fixCreateProcedure(content);
        content = this.fixParameters(content);
        content = this.fixVariableDeclarations(content);
        content = this.fixReturnStatements(content);
        content = this.fixIfStatements(content);
        content = this.fixSelectStatements(content);
        content = this.fixInsertStatements(content);
        content = this.fixUpdateStatements(content);
        content = this.fixDeleteStatements(content);
        content = this.fixDataTypes(content);
        content = this.fixBuiltInFunctions(content);
        content = this.fixTransactions(content);
        content = this.fixErrorHandling(content);
        content = this.fixComments(content);
        content = this.addDollarQuoting(content);
        content = this.fixFinalStructure(content);

        // Write the converted file
        fs.writeFileSync(filePath, content);
        
        console.log(`✅ Conversion completed!`);
        
        if (this.fixes.length > 0) {
            console.log(`🔧 Applied fixes (${this.fixes.length}):`);
            this.fixes.forEach((fix, i) => console.log(`   ${i + 1}. ${fix}`));
        }

        if (this.warnings.length > 0) {
            console.log(`⚠️  Warnings (${this.warnings.length}):`);
            this.warnings.forEach((warning, i) => console.log(`   ${i + 1}. ${warning}`));
        }

        return true;
    }

    fixCreateProcedure(content) {
        // Convert CREATE PROCEDURE to CREATE FUNCTION
        content = content.replace(
            /CREATE\s+(?:OR\s+REPLACE\s+)?PROCEDURE\s+([^\s(]+)\s*(\([^)]*\))?/gi,
            (match, procName, params) => {
                this.fixes.push(`Converted PROCEDURE ${procName} to FUNCTION`);
                return `CREATE OR REPLACE FUNCTION ${procName}${params || '()'}`;
            }
        );

        return content;
    }

    fixParameters(content) {
        // Fix parameter declarations - remove OUTPUT keyword and add proper types
        content = content.replace(
            /@([a-zA-Z_][a-zA-Z0-9_]*)\s+([a-zA-Z0-9_()]+)(?:\s+OUTPUT)?/gi,
            (match, paramName, paramType) => {
                const pgType = this.convertDataType(paramType);
                this.fixes.push(`Fixed parameter ${paramName} type: ${paramType} -> ${pgType}`);
                return `p_${paramName} ${pgType}`;
            }
        );

        // Fix parameter references in function body
        content = content.replace(/@([a-zA-Z_][a-zA-Z0-9_]*)/g, (match, paramName) => {
            return `p_${paramName}`;
        });

        return content;
    }

    fixVariableDeclarations(content) {
        // Fix DECLARE statements for PostgreSQL
        content = content.replace(
            /DECLARE\s+@([a-zA-Z_][a-zA-Z0-9_]*)\s+([a-zA-Z0-9_()]+)(?:\s*=\s*([^;]+))?;?/gi,
            (match, varName, varType, defaultValue) => {
                const pgType = this.convertDataType(varType);
                let declaration = `    v_${varName} ${pgType}`;
                if (defaultValue) {
                    declaration += ` := ${defaultValue.trim()}`;
                }
                declaration += ';';
                this.fixes.push(`Fixed variable declaration: @${varName}`);
                return declaration;
            }
        );

        // Fix variable references
        content = content.replace(/@([a-zA-Z_][a-zA-Z0-9_]*)/g, (match, varName) => {
            return `v_${varName}`;
        });

        return content;
    }

    fixReturnStatements(content) {
        // Handle different types of RETURN statements
        
        // Simple RETURN; statements
        content = content.replace(/\bRETURN\s*;/gi, 'RETURN;');

        // RETURN with values for scalar functions
        content = content.replace(
            /\bRETURN\s+([^;]+);/gi, 
            (match, returnValue) => {
                this.fixes.push('Fixed RETURN statement');
                return `RETURN ${returnValue};`;
            }
        );

        // Handle SELECT statements that should return results
        content = content.replace(
            /SELECT\s+([^;]+);?\s*$(?!\s*FROM)/gm,
            (match, selectClause) => {
                if (match.includes('INTO')) {
                    return match; // Don't change SELECT INTO statements
                }
                this.fixes.push('Fixed SELECT return statement');
                return `RETURN QUERY SELECT ${selectClause};`;
            }
        );

        return content;
    }

    fixIfStatements(content) {
        // Fix IF statements
        content = content.replace(
            /\bIF\s+(.+?)\s+BEGIN/gi,
            (match, condition) => {
                this.fixes.push('Fixed IF statement syntax');
                return `IF ${condition} THEN`;
            }
        );

        // Fix ELSE IF
        content = content.replace(/\bELSE\s+IF\b/gi, 'ELSIF');

        // Fix END IF
        content = content.replace(/\bEND\s*(?!;|\s*\$\$)/gi, 'END IF');

        return content;
    }

    fixSelectStatements(content) {
        // Fix SELECT INTO statements
        content = content.replace(
            /SELECT\s+(.+?)\s+INTO\s+(@[a-zA-Z_][a-zA-Z0-9_]*(?:\s*,\s*@[a-zA-Z_][a-zA-Z0-9_]*)*)\s+FROM/gi,
            (match, selectClause, variables, fromClause) => {
                const pgVars = variables.replace(/@([a-zA-Z_][a-zA-Z0-9_]*)/g, 'v_$1');
                this.fixes.push('Fixed SELECT INTO statement');
                return `SELECT ${selectClause} INTO ${pgVars} FROM`;
            }
        );

        return content;
    }

    fixInsertStatements(content) {
        // Fix INSERT statements with OUTPUT clause
        content = content.replace(
            /INSERT\s+INTO\s+([^\s(]+)\s*(\([^)]*\))?\s+OUTPUT\s+([^)]+)\s+VALUES\s*(\([^)]*\))/gi,
            (match, tableName, columns, outputClause, values) => {
                this.fixes.push('Removed OUTPUT clause from INSERT');
                this.warnings.push('OUTPUT clause removed - consider using RETURNING clause');
                return `INSERT INTO ${tableName}${columns || ''} VALUES ${values}`;
            }
        );

        return content;
    }

    fixUpdateStatements(content) {
        // Fix UPDATE statements
        content = content.replace(
            /UPDATE\s+([^\s]+)\s+SET\s+([^;]+);\s*$/gm,
            (match, tableName, setClause) => {
                if (!match.includes('WHERE')) {
                    this.warnings.push(`UPDATE on ${tableName} has no WHERE clause - this will update all rows!`);
                }
                return match;
            }
        );

        return content;
    }

    fixDeleteStatements(content) {
        // Fix DELETE statements
        content = content.replace(
            /DELETE\s+FROM\s+([^\s]+)(?:\s+WHERE\s+[^;]+)?;\s*$/gm,
            (match) => {
                if (!match.includes('WHERE')) {
                    this.warnings.push('DELETE statement has no WHERE clause - this will delete all rows!');
                }
                return match;
            }
        );

        return content;
    }

    convertDataType(mssqlType) {
        const typeMap = {
            // String types
            'VARCHAR': 'VARCHAR',
            'NVARCHAR': 'VARCHAR',
            'CHAR': 'CHAR',
            'NCHAR': 'CHAR',
            'TEXT': 'TEXT',
            'NTEXT': 'TEXT',
            
            // Numeric types
            'INT': 'INTEGER',
            'INTEGER': 'INTEGER',
            'BIGINT': 'BIGINT',
            'SMALLINT': 'SMALLINT',
            'TINYINT': 'SMALLINT',
            'BIT': 'BOOLEAN',
            'DECIMAL': 'DECIMAL',
            'NUMERIC': 'NUMERIC',
            'FLOAT': 'REAL',
            'REAL': 'REAL',
            'MONEY': 'DECIMAL(19,4)',
            'SMALLMONEY': 'DECIMAL(10,4)',
            
            // Date/Time types
            'DATETIME': 'TIMESTAMP',
            'DATETIME2': 'TIMESTAMP',
            'SMALLDATETIME': 'TIMESTAMP',
            'DATE': 'DATE',
            'TIME': 'TIME',
            'DATETIMEOFFSET': 'TIMESTAMPTZ',
            
            // Other types
            'UNIQUEIDENTIFIER': 'UUID',
            'VARBINARY': 'BYTEA',
            'BINARY': 'BYTEA',
            'IMAGE': 'BYTEA',
            'XML': 'XML'
        };

        // Handle parameterized types like VARCHAR(50)
        const typeMatch = mssqlType.match(/^([A-Z]+)(\([^)]+\))?$/i);
        if (typeMatch) {
            const baseType = typeMatch[1].toUpperCase();
            const params = typeMatch[2] || '';
            
            if (typeMap[baseType]) {
                return typeMap[baseType] + params;
            }
        }

        return mssqlType; // Return as-is if no mapping found
    }

    fixDataTypes(content) {
        // Fix data type declarations in the content
        const mssqlTypes = /\b(NVARCHAR|VARCHAR|NCHAR|CHAR|NTEXT|TEXT|INT|INTEGER|BIGINT|SMALLINT|TINYINT|BIT|DECIMAL|NUMERIC|FLOAT|REAL|MONEY|SMALLMONEY|DATETIME2?|SMALLDATETIME|DATE|TIME|DATETIMEOFFSET|UNIQUEIDENTIFIER|VARBINARY|BINARY|IMAGE|XML)(\([^)]*\))?\b/gi;
        
        content = content.replace(mssqlTypes, (match, type, params) => {
            const pgType = this.convertDataType(match);
            if (pgType !== match) {
                this.fixes.push(`Data type conversion: ${match} -> ${pgType}`);
            }
            return pgType;
        });

        return content;
    }

    fixBuiltInFunctions(content) {
        const functionMap = {
            'ISNULL': 'COALESCE',
            'LEN': 'LENGTH',
            'CHARINDEX': 'POSITION',
            'SUBSTRING': 'SUBSTR',
            'GETDATE': 'NOW',
            'GETUTCDATE': 'NOW() AT TIME ZONE \'UTC\'',
            'NEWID': 'gen_random_uuid',
            'UPPER': 'UPPER',
            'LOWER': 'LOWER',
            'LTRIM': 'LTRIM',
            'RTRIM': 'RTRIM'
        };

        Object.entries(functionMap).forEach(([mssqlFunc, pgFunc]) => {
            const regex = new RegExp(`\\b${mssqlFunc}\\s*\\(`, 'gi');
            if (content.match(regex)) {
                content = content.replace(regex, `${pgFunc}(`);
                this.fixes.push(`Function conversion: ${mssqlFunc}() -> ${pgFunc}()`);
            }
        });

        return content;
    }

    fixTransactions(content) {
        // Convert transaction statements
        content = content.replace(/\bBEGIN\s+TRAN(SACTION)?\b/gi, 'BEGIN;');
        content = content.replace(/\bCOMMIT\s+TRAN(SACTION)?\b/gi, 'COMMIT;');
        content = content.replace(/\bROLLBACK\s+TRAN(SACTION)?\b/gi, 'ROLLBACK;');

        return content;
    }

    fixErrorHandling(content) {
        // Remove MSSQL-specific error handling that doesn't translate directly
        content = content.replace(/\bBEGIN\s+TRY\b[\s\S]*?\bEND\s+TRY\b[\s\S]*?\bBEGIN\s+CATCH\b[\s\S]*?\bEND\s+CATCH\b/gi, (match) => {
            this.warnings.push('TRY/CATCH block removed - implement PostgreSQL exception handling manually');
            return '-- TODO: Implement PostgreSQL exception handling\n-- Original TRY/CATCH block was here';
        });

        return content;
    }

    fixComments(content) {
        // Convert MSSQL comments to PostgreSQL format
        content = content.replace(/--\s*(.*)$/gm, '-- $1');
        
        return content;
    }

    addDollarQuoting(content) {
        // Find function definitions and ensure they have proper dollar quoting
        content = content.replace(
            /(CREATE\s+OR\s+REPLACE\s+FUNCTION\s+[^)]+\)\s*(?:RETURNS\s+[^A]+?)?)\s*(?:AS\s*)?(?:\$\$)?([\s\S]*?)(?:\$\$\s*LANGUAGE\s+plpgsql;?|$)/gi,
            (match, signature, body) => {
                // Clean up the signature
                if (!signature.includes('RETURNS')) {
                    signature += '\nRETURNS void';
                }

                // Clean up the body
                body = body.trim();
                if (body && !body.startsWith('DECLARE') && !body.startsWith('BEGIN')) {
                    body = 'BEGIN\n' + body + '\nEND;';
                }

                this.fixes.push('Added proper dollar quoting and function structure');
                return `${signature} AS $$\n${body}\n$$ LANGUAGE plpgsql;`;
            }
        );

        return content;
    }

    fixFinalStructure(content) {
        // Ensure proper PostgreSQL function structure
        content = content.replace(
            /(\$\$[\s\S]*?)END\s*;?\s*(\$\$)/g,
            '$1END;\n$2'
        );

        // Fix multiple semicolons
        content = content.replace(/;;+/g, ';');

        // Fix spacing
        content = content.replace(/\n\s*\n\s*\n/g, '\n\n');

        return content;
    }

    analyzeErrorPosition(filePath, position) {
        if (!fs.existsSync(filePath)) {
            console.error(`❌ File not found: ${filePath}`);
            return;
        }

        const content = fs.readFileSync(filePath, 'utf8');
        const lines = content.split('\n');
        let currentPos = 0;
        
        for (let i = 0; i < lines.length; i++) {
            const lineLength = lines[i].length + 1; // +1 for newline
            
            if (currentPos + lineLength > position) {
                const columnPos = position - currentPos;
                console.log(`📍 Error at line ${i + 1}, column ${columnPos}:`);
                console.log(`   ${lines[i]}`);
                console.log(`   ${' '.repeat(Math.max(0, columnPos - 1))}^`);
                
                // Show context
                const start = Math.max(0, i - 3);
                const end = Math.min(lines.length, i + 4);
                console.log(`\n📝 Context:`);
                for (let j = start; j < end; j++) {
                    const marker = j === i ? '>>> ' : '    ';
                    console.log(`${marker}${j + 1}: ${lines[j]}`);
                }
                break;
            }
            currentPos += lineLength;
        }
    }

    validateConversion(content) {
        const issues = [];
        
        // Check for remaining MSSQL syntax
        const mssqlPatterns = [
            { pattern: /@[a-zA-Z_]/, message: 'MSSQL variable syntax (@var) still present' },
            { pattern: /\bPROCEDURE\b/i, message: 'PROCEDURE keyword found (should be FUNCTION)' },
            { pattern: /\bOUTPUT\b/i, message: 'OUTPUT keyword found (not supported in PostgreSQL)' },
            { pattern: /\bBEGIN\s+TRAN/i, message: 'MSSQL transaction syntax found' },
            { pattern: /\bISNULL\s*\(/i, message: 'ISNULL function found (use COALESCE)' },
            { pattern: /\bGETDATE\s*\(/i, message: 'GETDATE function found (use NOW())' },
            { pattern: /\bNEWID\s*\(/i, message: 'NEWID function found (use gen_random_uuid())' }
        ];

        mssqlPatterns.forEach(({ pattern, message }) => {
            if (pattern.test(content)) {
                issues.push(message);
            }
        });

        // Check for proper PostgreSQL structure
        if (!content.includes('$$ LANGUAGE plpgsql;')) {
            issues.push('Functions should end with $$ LANGUAGE plpgsql;');
        }

        if (issues.length > 0) {
            console.log(`⚠️  Validation issues found:`);
            issues.forEach((issue, i) => console.log(`   ${i + 1}. ${issue}`));
        } else {
            console.log(`✅ Validation passed - no obvious MSSQL syntax remaining`);
        }

        return issues;
    }
}

// Main execution
if (require.main === module) {
    const args = process.argv.slice(2);
    
    if (args.length === 0) {
        console.log(`
🔄 MSSQL to PostgreSQL Stored Procedure Converter

Usage: node mssql-to-pg-converter.js <sql-file> [options]

Options:
  --analyze-position <pos>  Analyze error at specific character position
  --validate-only          Only validate without converting

Examples:
  node mssql-to-pg-converter.js ./migrations/999_create_stored_procedure.sql
  node mssql-to-pg-converter.js ./migrations/999_create_stored_procedure.sql --analyze-position 1558
  node mssql-to-pg-converter.js ./migrations/999_create_stored_procedure.sql --validate-only

This script converts:
  ✅ CREATE PROCEDURE → CREATE FUNCTION
  ✅ Parameter syntax (@param → p_param)
  ✅ Variable declarations (@var → v_var)
  ✅ Data types (NVARCHAR → VARCHAR, etc.)
  ✅ Built-in functions (ISNULL → COALESCE, etc.)
  ✅ RETURN statements
  ✅ IF/ELSE syntax
  ✅ Transaction syntax
  ✅ Comments and structure
        `);
        process.exit(1);
    }

    const filePath = args[0];
    const converter = new MSSQLToPostgreSQLConverter();

    // Handle options
    if (args.includes('--validate-only')) {
        if (fs.existsSync(filePath)) {
            const content = fs.readFileSync(filePath, 'utf8');
            converter.validateConversion(content);
        }
        process.exit(0);
    }

    // Analyze specific position if requested
    const posIndex = args.indexOf('--analyze-position');
    if (posIndex !== -1 && args[posIndex + 1]) {
        const position = parseInt(args[posIndex + 1]);
        console.log(`🎯 Analyzing error at position ${position}`);
        converter.analyzeErrorPosition(filePath, position);
        console.log('');
    }

    // Convert the file
    const success = converter.convertFile(filePath);
    
    if (success) {
        // Validate the converted content
        console.log('\n🔍 Validating conversion...');
        const content = fs.readFileSync(filePath, 'utf8');
        converter.validateConversion(content);
        
        console.log(`\n🚀 Try running your migration again:`);
        console.log(`   npm run migrate`);
        console.log(`\n💡 If you still get errors, run with --analyze-position <position> to debug specific issues`);
    }
}