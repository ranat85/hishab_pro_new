const fs = require('fs');
const path = 'c:\\Users\\WALTON\\Documents\\hishab_pro_new\\lib\\main.dart';
const text = fs.readFileSync(path,'utf8');
['{','}','(',')','[',']'].forEach(ch=>console.log(ch+':', (text.split(ch).length-1)));
const lines = text.split('\n');
console.log('\n---TAIL 60 LINES---');
lines.slice(-60).forEach((l, i)=>console.log((lines.length-60+i+1).toString().padStart(5)+': '+l));
