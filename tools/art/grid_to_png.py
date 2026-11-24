"""Write a 32x32 DB16 PNG from a 1024-char hex grid (palette indices). Usage: python grid_to_png.py OUT GRID"""
import sys
from PIL import Image
P=["140c1c","442434","30346d","4e4a4e","854c30","346524","d04648","757161","597dce","d27d2c","8595a1","6daa2c","d2aa99","6dc2ca","dad45e","deeed6"]
out,g=sys.argv[1],sys.argv[2]; n=int(len(g)**0.5)
im=Image.new("RGB",(n,n))
for i,ch in enumerate(g):
    h=P[int(ch,16)]; im.putpixel((i%n,i//n),tuple(int(h[k:k+2],16) for k in (0,2,4)))
im.save(out)
