"""32x32 grain ledger (粮册) icon: thread-bound book, dark blue cover, blank label. DB16."""
import sys
from PIL import Image
P={"K":"140c1c","N":"30346d","L":"597dce","W":"deeed6","s":"d2aa99","B":"854c30","y":"dad45e"}
rows=["................................"]*4+[
"......KKKKKKKKKKKKKKKKKKKK......",
".....KNNNNNNNNNNNNNNNNNNNNK.....",
".....KyNNNNNNNNNNNNNNNNNNNK.....",
".....KNNNNNNNNNNKKKKKKKKNNK.....",
".....KyNNNNNNNNNKWWWWWWKNNK.....",
".....KNNNNNNNNNNKWWWWWWKNNK.....",
".....KNNNNNNNNNNKWWWWWWKNNK.....",
".....KyNNNNNNNNNKWWWWWWKNNK.....",
".....KNNNNNNNNNNKWWWWWWKNNK.....",
".....KNNNNNNNNNNKWWWWWWKNNK.....",
".....KyNNNNNNNNNKWWWWWWKNNK.....",
".....KNNNNNNNNNNKWWWWWWKNNK.....",
".....KNNNNNNNNNNKWWWWWWKNNK.....",
".....KyNNNNNNNNNKWWWWWWKNNK.....",
".....KNNNNNNNNNNKKKKKKKKNNK.....",
".....KNNNNNNNNNNNNNNNNNNNNK.....",
".....KyNNNNNNNNNNNNNNNNNNNK.....",
".....KNNNNNNNNNNNNNNNNNNNNKK....",
".....KNNNNNNNNNNNNNNNNNNNNKsK...",
".....KKKKKKKKKKKKKKKKKKKKKsK....",
"......KssssssssssssssssssK......",
".......KKKKKKKKKKKKKKKKKK.......",
]+["................................"]*3
im=Image.new("RGBA",(32,32),(0,0,0,0))
for y,r in enumerate(rows):
    for x,c in enumerate(r):
        if c!=".": h=P[c]; im.putpixel((x,y),(int(h[:2],16),int(h[2:4],16),int(h[4:],16),255))
im.save(sys.argv[1])
