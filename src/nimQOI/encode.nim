## nimQOI - Encoding Functions
## 

import std/[bitops]
import binstreams

type
  Channels* = enum
    RGB = 3, RGBA = 4

  Colorspace* = enum
    sRGB = 0, linear = 1

  Header* = object
    width*: uint32
    height*: uint32
    channels*: Channels
    colorspace*: Colorspace

  Pixel = object
    r: byte
    g: byte
    b: byte
    a: byte
    
  QoiFile = object
    header: Header
    data: seq[Pixel]


const
  QOI_MAGIC = ['q', 'o', 'i', 'f']
  QOI_HEADER_SIZE = 14

  QOI_RUN_TAG_MASK = 0b11000000.byte
  QOI_INDEX_TAG_MASK = 0b00000000.byte
  QOI_DIFF_TAG_MASK = 0b01000000.byte
  QOI_LUMA_TAG_MASK = 0b10000000.byte
  QOI_RGB_TAG_MASK = 0b11111110.byte
  QOI_RGBA_TAG_MASK = 0b11111111.byte

  QOI_END = [0.byte, 0.byte, 0.byte, 0.byte, 0.byte, 0.byte, 0.byte, 1.byte]
  QOI_END_SIZE = 8


func init(w, h: uint32; channels: Channels, colorspace: Colorspace): Header =
  result.width = w
  result.height = h
  result.channels = channels
  result.colorspace = colorspace


func init(r, g, b, a: byte): Pixel = 
  result.r = r
  result.g = g
  result.b = b
  result.a = a


func init(header: Header, data: seq[Pixel]): QoiFile =
  result.header = header
  result.data = data


func isEqual(p1, p2: Pixel): bool =
  if p1.r == p2.r and
    p1.g == p2.g and
    p1.b == p2.b and
    p1.a == p2.a:
    return true
  else:
    return false


func getDiff(p1, p2: Pixel): Pixel =
  result.r = p1.r - p2.r
  result.g = p1.g - p2.g
  result.b = p1.b - p2.b
  result.a = p1.a - p2.a


func writeHeader(output: var Memstream; header: Header) =
  for i in QOI_MAGIC:
       output.write(i)
  output.write(uint32(header.width))
  output.write(uint32(header.height))
  output.write(uint8(header.channels))
  output.write(uint8(header.colorspace))

proc getPixel(stream: MemStream, channels: int): Pixel =
  result.r = stream.read(byte)
  result.g = stream.read(byte)
  result.b = stream.read(byte)

  if channels == 4:
    result.a = stream.read(byte)
  else:
    result.a = result.b

proc opRun(output: var MemStream, runs: var byte, index, lastPixel: int) =
  ## Desc

  inc runs
  if (runs == 62) or (index == lastPixel):
    output.write(bitor(QOI_RUN_TAG_MASK, (runs - 1))) # OP_RUN Tag
    runs = 0


proc opDiff(output: var MemStream, diff: Pixel, flag: var bool) =
  if ((int(diff.r) >= -2) and (int(diff.r) <= 1)) and
     ((int(diff.g) >= -2) and (int(diff.g) <= 1)) and
     ((int(diff.b) >= -2) and (int(diff.b) <= 1)):
    
    # create the OP_DIFF byte, remembering to shift the channels and bias the signed integers
    output.write(bitor(QOI_DIFF_TAG_MASK, (diff.r + 2) shl 4, (diff.g + 2) shl 2, (diff.g + 2)))
    
    flag = true
  
  # try luma
  elif ((int(diff.g) >= 32) and (int(diff.g) <= 31)) and 
        ((int(diff.g) >= -8) and (int(diff.g) <= 7)) and
        ((int(diff.b) >= -8) and (int(diff.b) <= 7)):
      
    let
      dr_dg = diff.r - diff.g
      db_dg = diff.b - diff.g

    output.write(bitor(QOI_LUMA_TAG_MASK, (diff.g + 32))) # OP_DIFF is 2 bytes, so we write two bytes
    output.write(bitor((dr_dg + 8) shl 4, (db_dg + 8)))

    flag = true

  else:
    flag = false


proc opRGB(output: var MemStream, pixel: Pixel) =
  output.write(QOI_RGB_TAG_MASK)
  output.write(pixel.r)
  output.write(pixel.g)
  output.write(pixel.b)


proc opRGBA(output: var MemStream, pixel: Pixel) =
  output.write(QOI_RGBA_TAG_MASK)
  output.write(pixel.r)
  output.write(pixel.g)
  output.write(pixel.b)
  output.write(pixel.a)


proc writeData(output: var MemStream, stream: MemStream, hdr: Header) =
  ## Desc
  ##

  let 
    imageSize = hdr.width.int * hdr.height.int * hdr.channels.int
    lastPixel = imageSize - hdr.channels.int

  var 
    prevPixel = Pixel(r: 0, g: 0, b: 0, a: 255)
    runs = 0.byte # 0 .. 62, keeps track of the run-length of the repetitions of the previous pixel
    slidingWindow: array[64, Pixel] # a.k.a. the OP_INDEX array
  
  # fill the window with empty values
  for x in slidingWindow.mitems: x = Pixel(r: 0, g: 0, b: 0)
  
  # read each pixel in data stream
  for i in countup(0, lastPixel - 1, 4): # countup(start, last, increment)
    # read current pixel from data stream, accounting for 3 vs 4 channels
    let currPixel = stream.getPixel(int(hdr.channels))
    
    if currPixel.isEqual(prevPixel): # we have a repeat pixel (a.k.a a run)
      output.opRun(runs, i, lastPixel)
    else: # we do not have a repeat pixel
      if runs > 0: # we have been on a run that has now stopped
        output.write(bitor(QOI_RUN_TAG_MASK, (runs - 1))) # rememeber to bias the run value
        runs = 0
      
      # next we look for the currPixel in the slidingWindow array, at hash position
      let hash = (currPixel.r * 3 + currPixel.g * 5 + currPixel.b * 7 + currPixel.a * 11) mod 64
      if currPixel.isEqual(slidingWindow[hash]): # is pixel in slidingWindow?
        output.write(bitor(QOI_INDEX_TAG_MASK, hash))
      
      else: # pixel wasn't in sliding window
        slidingWindow[hash] = currPixel # since we have seen the pixel, we add it to the window
        
        let diffPixel = getDiff(currPixel, prevPixel)
        
        if diffPixel.a == 0:
          var diffFlag: bool
          output.opDiff(diffPixel, diffFlag)
          if not diffFlag:
            output.opRGB(currPixel)
        
        else: 
          output.opRGBA(currPixel)
          

proc encode*(header: Header, stream: MemStream): MemStream =
  ## Some Description Here...
  ##

  var output = newMemStream(bigEndian)

  output.writeHeader(header)
  output.writeData(stream, header)

  # write the end marker
  for i in QOI_END:
    output.write(i)
  
  output.setPosition(0)
  return output
