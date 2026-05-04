import hashlib
p=r'C:\Users\WALTON\Documents\hishab_pro_new\backup_inspect.db'
out=r'C:\Users\WALTON\Documents\hishab_pro_new\backup_inspect_repaired.db'
with open(p,'rb') as f:
    b=f.read()
orig=b[0]
b2=bytes([0x53]) + b[1:]
with open(out,'wb') as f:
    f.write(b2)
print('orig=0x%02x' % orig)
print('hexhead=' + b2[:16].hex())
print('len=' + str(len(b2)))
print('md5=' + hashlib.md5(b2).hexdigest())
