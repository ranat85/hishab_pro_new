const fs = require('fs');
const path = 'c:\\Users\\WALTON\\Documents\\hishab_pro_new\\lib\\main.dart';
const text = fs.readFileSync(path,'utf8');
const lines = text.split('\n');
let open=0;
for(let i=0;i<lines.length;i++){
  const line = lines[i];
  for(const ch of line){
    if(ch==='(') open++;
    else if(ch===')') open--;
  }
  if(open<0){
    console.log('Negative at line', i+1, 'line:', line);
    process.exit(0);
  }
}
console.log('Final paren balance:', open);
if(open>0) console.log('Missing', open, "')'");
if(open<0) console.log('Extra', -open, "')'");
// show context around where final close paren might be
for(let i=0;i<lines.length;i++){
  if(lines[i].includes('SingleChildScrollView')){
    console.log('Found SingleChildScrollView at line', i+1);
  }
}
