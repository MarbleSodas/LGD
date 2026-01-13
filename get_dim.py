import struct
import sys

def get_png_dimensions(file_path):
    with open(file_path, 'rb') as f:
        if f.read(8) != b'\x89PNG\r\n\x1a\n':
            return None
        
        while True:
            length_bytes = f.read(4)
            if not length_bytes: break
            length = struct.unpack('>I', length_bytes)[0]
            chunk_type = f.read(4)
            
            if chunk_type == b'IHDR':
                width = struct.unpack('>I', f.read(4))[0]
                height = struct.unpack('>I', f.read(4))[0]
                return width, height
            
            f.seek(length + 4, 1)
            
    return None

dims = get_png_dimensions('assets/objects/Dandelion.png')
if dims:
    print(f"{dims[0]} {dims[1]}")
else:
    print("Error")
