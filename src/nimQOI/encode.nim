## nimQOI - Encoding Functions
## 

import std/[bitops] # Standard Libary import
import binstreams # Nimble Library import
import common # Adjacent Module import


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
  ## Purpose:
  ##    Writes the standardized QOI file header information to the output memory stream
  ## Inputs:
  ##    output: MemStream (variable) - a mutable Memstream object to write header data to
  ##    header: Header - The image desciption object (width, length, channels, colorspace)
  ## Side-Effects:
  ##    writes 14 bytes  to the output memory stream
  ## Returns:
  ##    None
  for i in QOI_MAGIC:
       output.write(i)
  output.write(uint32(header.width))
  output.write(uint32(header.height))
  output.write(uint8(header.channels))
  output.write(uint8(header.colorspace))


proc opRun(output: var MemStream, runs: var byte, index, lastPixel: int) =
  ## Purpose:
  ##    Writes a single byte representing a count of the number of times a run of the previous 
  ##    pixel has been seen. e.g. Six green RGB pixels in a row in the datastream will be output
  ##    one 4 byte opRGB value, followed by a 1-byte opRun byte whose value is 5. Also includes
  ##    a 2-bit tag at the top  of the byte. 
  ## Inputs:
  ##    output: MemStream (variable) - a mutable Memstream object to write compressed data to
  ##    runs: byte (variable) - a count of the number of times the previous pixel repeats itself
  ##    index: the current pixel being read from the input stream
  ##    lasPixel: the last pixel in the input stream, a.k.a, the end of the input stream
  ## Side-Effects:
  ##    writes 1 byte  to the output memory stream
  ## Returns:
  ##    None

  inc runs
  if (runs == 62) or (index == lastPixel):
    output.write(bitor(QOI_RUN_TAG_MASK, (runs - 1))) # OP_RUN Tag
    runs = 0


proc opDiff(output: var MemStream, diff: Pixel, flag: var bool) =
  ## Purpose:
  ##    Writes either 1 byte or 2 bytes representing either the difference to the previous 
  ##    pixel value in RGB, or the luminosity difference using two bytes. Includes a 2-bit 
  ##    tag value at the front, upper bits.
  ## Inputs:
  ##    output: MemStream (variable) - a mutable Memstream object to write compressed data to
  ##    diff: Pixel - an object containing the RBGA byte values
  ##    flag: bool - informs the calling function if any data was written the the output memory
  ##                 stream, otherwise the calling function will jump to the next scenario.
  ## Side-Effects:
  ##    writes 1 or 2 bytes to the output memory stream
  ## Returns:
  ##    None
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
  ## Purpose:
  ##    Writes 4 bytes representing an RGB image + 1 byte tag value to the output memory stream
  ## Inputs:
  ##    output: MemStream (variable) - a mutable Memstream object to write compressed data to
  ##    pixel: Pixel - an object containing the RGB byte values
  ## Side-Effects:
  ##    writes 4 bytes to the output memory stream
  ## Returns:
  ##    None
  output.write(QOI_RGB_TAG)
  output.write(pixel.r)
  output.write(pixel.g)
  output.write(pixel.b)


proc opRGBA(output: var MemStream, pixel: Pixel) =
  ## Purpose:
  ##    Writes 5 bytes representing an RGBA image + 1 byte tag value to the output memory stream.
  ##    Data is uncompressed.
  ## Inputs:
  ##    output: MemStream (variable) - a mutable Memstream object to write compressed data to
  ##    pixel: Pixel - an object containing the RGBA byte values
  ## Side-Effects:
  ##    writes 5 bytes to the output memory stream
  ## Returns:
  ##    None
  output.write(QOI_RGBA_TAG)
  output.write(pixel.r)
  output.write(pixel.g)
  output.write(pixel.b)
  output.write(pixel.a)


proc writeData(output: var MemStream, stream: MemStream, hdr: Header) =
  ## Purpose:
  ##    Writes the compressed image data to the QOI image memory stream
  ## Inputs:
  ##    output: MemStream (variable) - a mutable Memstream object to write compressed data to
  ##    stream: MemStream - The input data stream of raw RGB/RGBA values
  ##    hdr: Header - The image desciption object (width, length, channels, colorspace)
  ## Side-Effects:
  ##    Changes the read position of the 'stream' MemStream
  ##    writes data to the output memory stream
  ## Returns:
  ##    None

  let 
    imageSize = hdr.width.int * hdr.height.int * hdr.channels.int
    lastPixel = imageSize - hdr.channels.int

  var 
    prevPixel = Pixel(r: 0, g: 0, b: 0, a: 255)
    runs = 0.byte # 0 .. 61, keeps track of the run-length of the repetitions of the previous pixel
    seenWindow: array[64, Pixel] # a.k.a. the OP_INDEX array
  
  # fill the window with empty values
  for x in seenWindow.mitems: x = Pixel(r: 0, g: 0, b: 0)
  # add the previous pixel to seenWindow
  
  # do we do this?
  #seenWindow[prevPixel.hash()] = prevPixel
  
  # read each pixel in data stream
  for i in countup(0, lastPixel, 4): # countup(start, last, increment)
    # read current pixel from data stream, accounting for 3 vs 4 channels
    let currPixel = stream.getPixel(hdr.channels)
    

    if currPixel.isEqual(prevPixel): # we have a repeat pixel (a.k.a a run)
      output.opRun(runs, i, lastPixel)
    else: # we do not have a repeat pixel
      if runs > 0: # we have been on a run that has now stopped
        output.write(bitor(QOI_RUN_TAG_MASK, (runs - 1))) # remember to bias the run value
        runs = 0
      
      # next we look for the currPixel in the seenWindow array, at hash position
      let hash = currPixel.hash()
      if currPixel.isEqual(seenWindow[hash]): # is pixel in seenWindow?
        # Instead of writing an RGBA value in 4 bytes, we just store the index in to a previously 
        # seen value in a single byte
        output.write(bitor(QOI_INDEX_TAG_MASK, hash))
      
      else: # pixel wasn't in seen window
        seenWindow[hash] = currPixel # since we have seen the pixel, we add it to the window
        
        let diffPixel = getDiff(currPixel, prevPixel)
        
        if diffPixel.a == 0:
          var diffFlag: bool
          output.opDiff(diffPixel, diffFlag)
          if not diffFlag:
            output.opRGB(currPixel)
        
        else: 
          output.opRGBA(currPixel)

    # don't forget this  
    prevPixel = currPixel      

proc encode*(header: Header, stream: MemStream): MemStream =
  ## Purpose:
  ##    Encode raw RGB or RGBA pixels into a QOI image in memory
  ## Inputs:
  ##    header: Header - The image desciption object (width, length, channels, colorspace)
  ##    stream: MemStream - The input data stream of raw RGB/RGBA values
  ## Side-Effects:
  ##    Changes the read position of the 'stream' MemStream
  ## Returns:
  ##    A MemStream object that stores the QOI image with the header data and associated
  ##    compressed image data

  var output = newMemStream(bigEndian)

  output.writeHeader(header)
  output.writeData(stream, header)

  # write the end marker
  for i in QOI_END:
    output.write(i)
  
  output.setPosition(0)
  return output
