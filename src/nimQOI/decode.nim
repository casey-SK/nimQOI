## nimQOI - Decoding Functions
## 

import std/[bitops] # Standard Libary import
import binstreams # Nimble Library import
import common # Adjacent Module import

proc readSignature(stream: var MemStream, idx: var int): bool =
  var val: char
  for i in QOI_MAGIC:
    val = stream.read(char); inc idx
    if i != val:
      return false
  return true

proc writePixel(output: var seq[byte]; pixel: Pixel, channel: Channels) =
  output.add(pixel.r) 
  output.add(pixel.g) 
  output.add(pixel.b)
  if channel == RGBA: 
    output.add(pixel.a)

proc readData(stream: var MemStream, hdr: Header): seq[byte] =
  ## Description
  ##

  let
    pixelCount = hdr.width.int * hdr.height.int
    imageSize = pixelCount * hdr.channels.int
    lastPixel = imageSize - hdr.channels.int

  var 
    pixel = Pixel(r: 0, g: 0, b: 0, a: 255)
    run = 0.byte # 0 .. 62, keeps track of the run-length of the repetitions of the previous pixel
    seenWindow: array[64, Pixel] # a.k.a. the OP_INDEX array 

  # fill the window with empty values
  for x in seenWindow.mitems: x = Pixel(r: 0, g: 0, b: 0, a: 0)
  # add the previous pixel to seenWindow
  seenWindow[pixel.hash()] = pixel

  var bits: byte
  for i in 0 ..< pixelCount:

    if run > 0:
      dec run
    
    else:
      bits = stream.read(byte)
      if bits == QOI_RGB_TAG:
        pixel.r = stream.read(byte)
        pixel.g = stream.read(byte)
        pixel.b = stream.read(byte)
        pixel.a = 255
      
      elif bits == QOI_RGBA_TAG:
        pixel.r = stream.read(byte)
        pixel.g = stream.read(byte)
        pixel.b = stream.read(byte)
        pixel.a = stream.read(byte)
      
      elif bitand(bits, QOI_2BIT_MASK) == QOI_INDEX_TAG_MASK:
        let index = bitand(bits, QOI_INDEX_VAL_MASK)
        pixel = seenWindow[index]
      
      elif bitand(bits, QOI_2BIT_MASK) == QOI_DIFF_TAG_MASK:
        let
          dr = bitand(bits, 0x30) + 2.byte
          dg = bitand(bits, 0x0c) + 2.byte
          db = bitand(bits, 0x03) + 2.byte
          
        pixel.r = (pixel.r + dr) mod 64
        pixel.g = (pixel.g + dg) mod 64
        pixel.b = (pixel.b + db) mod 64
      
      elif bitand(bits, QOI_2BIT_MASK) == QOI_LUMA_TAG_MASK:
        let 
          dg = bitand(bits, QOI_LUMA_DIFF_GREEN_MASK) + 32
          bits2 = stream.read(byte)

        let
          dr_dg = bitand(bits, QOI_LUMA_DR_DG_MASK) + 8
          db_dg = bitand(bits, QOI_LUMA_DB_DG_MASK) + 8
          dr = dr_dg + dg
          db = db_dg + dg
          
        pixel.r = (pixel.r + dr) mod 64
        pixel.g = (pixel.g + dg) mod 64
        pixel.b = (pixel.b + db) mod 64

      elif bitand(bits, QOI_2BIT_MASK) == QOI_RUN_TAG_MASK:
        run = bitand(bits, QOI_RUN_VAL_MASK) + 1 # Remember to unbias the run value!
      
      seenWindow[pixel.hash()] = pixel
      
    result.add(pixel.r)
    result.add(pixel.g)
    result.add(pixel.b)

    if hdr.channels == RGBA:
      result.add(pixel.a)



    
  


proc decode*(stream: var MemStream): QoiFile =
  ## Description
  ## 
  
  stream.setPosition(0)
  var readIndex = 0
  # read the file signature
  if not stream.readSignature(readIndex):
    raise newException(ValueError, "Invalid File Header")

  # read header information
  let
    width = stream.read(uint32)
    height = stream.read(uint32)
    channels = cast[Channels](stream.read(byte))
    colorspace = cast[Colorspace](stream.read(byte))

    header = init(width, height, channels, colorspace)

  result.header = header
  result.data = stream.readData(header)

  var endMarker: seq[byte]
  for i in 0 .. 7:
    endMarker.add(stream.read(byte))
  
  if not (endMarker == QOI_END):
    raise newException(ValueError, "did not read proper end marker!")

proc decode*(stream: FileStream): QoiFile =
  ## Maybe I should just copy/paste the code from MemStream version?
  stream.setPosition(0)
  var memStream = newMemStream(bigEndian)
  while not stream.atEnd():
    memStream.write(stream.read(byte))
  #memStream.write(stream.read(byte))

  result = decode(memStream)