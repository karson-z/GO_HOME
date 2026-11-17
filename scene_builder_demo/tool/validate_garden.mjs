// Usage: node tool/validate_garden.mjs /absolute/path/to/gltf-validator
// Install the official Khronos validator from npm into a temporary directory.
import fs from 'node:fs/promises';
import path from 'node:path';
import {createRequire} from 'node:module';
const require = createRequire(import.meta.url);
const validator = require(process.argv[2] || 'gltf-validator');
const dir = path.resolve('assets/models');
const reports = [];
for (const name of (await fs.readdir(dir)).filter(n => /^garden3d_.*\.glb$/.test(n))) {
  const bytes = new Uint8Array(await fs.readFile(path.join(dir,name)));
  const result = await validator.validateBytes(bytes, {uri:name, maxIssues:200});
  reports.push({file:name,bytes:bytes.length,issues:result.issues,info:result.info});
  console.log(`${name}: ${result.issues.numErrors} errors, ${result.issues.numWarnings} warnings`);
}
await fs.writeFile('docs/garden3d/gltf-validation.json',JSON.stringify(reports,null,2));
if (reports.some(r => r.issues.numErrors)) process.exitCode=1;
