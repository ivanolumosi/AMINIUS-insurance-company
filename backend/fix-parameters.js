const fs = require('fs');
const path = require('path');

/**
 * Script to fix PostgreSQL function parameter ordering
 * Moves all parameters with DEFAULT values to the end
 */

function fixParameterOrdering(sqlContent) {
    // Regex to match CREATE OR REPLACE FUNCTION declarations with parameters
    const functionRegex = /CREATE\s+OR\s+REPLACE\s+FUNCTION\s+[\w_]+\s*\(([\s\S]*?)\)\s*RETURNS/gi;
    
    return sqlContent.replace(functionRegex, (match, parametersBlock) => {
        // Split parameters by comma, but be careful of nested parentheses
        const parameters = [];
        let currentParam = '';
        let parenLevel = 0;
        let inQuotes = false;
        
        for (let i = 0; i < parametersBlock.length; i++) {
            const char = parametersBlock[i];
            
            if (char === "'" && parametersBlock[i-1] !== '\\') {
                inQuotes = !inQuotes;
            } else if (!inQuotes) {
                if (char === '(') parenLevel++;
                else if (char === ')') parenLevel--;
                else if (char === ',' && parenLevel === 0) {
                    parameters.push(currentParam.trim());
                    currentParam = '';
                    continue;
                }
            }
            
            currentParam += char;
        }
        
        if (currentParam.trim()) {
            parameters.push(currentParam.trim());
        }
        
        // Separate parameters with and without defaults
        const requiredParams = [];
        const defaultParams = [];
        
        parameters.forEach(param => {
            if (param.toUpperCase().includes('DEFAULT')) {
                defaultParams.push(param);
            } else {
                requiredParams.push(param);
            }
        });
        
        // Reconstruct the function declaration
        const allParams = [...requiredParams, ...defaultParams];
        const newParametersBlock = allParams.join(',\n    ');
        
        return match.replace(parametersBlock, newParametersBlock);
    });
}

function fixStoredProceduresFile(filePath) {
    try {
        console.log('📖 Reading file:', filePath);
        const content = fs.readFileSync(filePath, 'utf8');
        
        console.log('🔧 Fixing parameter ordering...');
        const fixedContent = fixParameterOrdering(content);
        
        // Create backup
        const backupPath = filePath + '.backup';
        fs.writeFileSync(backupPath, content);
        console.log('💾 Backup created:', backupPath);
        
        // Write fixed content
        fs.writeFileSync(filePath, fixedContent);
        console.log('✅ File fixed successfully!');
        
        // Show what changed
        if (content !== fixedContent) {
            console.log('🔄 Parameter ordering has been corrected');
        } else {
            console.log('ℹ️  No changes needed');
        }
        
    } catch (error) {
        console.error('❌ Error:', error.message);
        process.exit(1);
    }
}

// Usage
const filePath = process.argv[2];

if (!filePath) {
    console.log('Usage: node fix-parameters.js <path-to-sql-file>');
    console.log('Example: node fix-parameters.js ./migrations/999_create_stored_procedure.sql');
    process.exit(1);
}

if (!fs.existsSync(filePath)) {
    console.error('❌ File not found:', filePath);
    process.exit(1);
}

fixStoredProceduresFile(filePath);