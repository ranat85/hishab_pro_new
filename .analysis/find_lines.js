const fs = require('fs');
const path = 'c:\\Users\\WALTON\\Documents\\hishab_pro_new\\lib\\main.dart';
const text = fs.readFileSync(path,'utf8');
const lines = text.split('\n');
for(let i=0;i<lines.length;i++){
  if(lines[i].includes('SingleChildScrollView(') || lines[i].includes('Expanded(') ){
    console.log('Line', i+1, ':', lines[i]);
    console.log('---next 12 lines---');
    console.log(lines.slice(i+1,i+13).map((l,idx)=> (i+2+idx)+': '+l).join('\n'));
    console.log('--------------------');
  }
}
