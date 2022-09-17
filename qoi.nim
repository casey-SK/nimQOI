## 
## .. image:: qoi_logo.png
## 
## =============================================================
## **The Quite OK Image Format for Fast, Lossless Compression**
## =============================================================
## 
## **About**
## 
## QOI encodes and decodes images in a lossless format. Compared to stb_image and
## stb_image_write QOI offers 20x-50x faster encoding, 3x-4x faster decoding and
## 20% better compression. The `QOI specification document<https://qoiformat.org/qoi-specification.pdf>`_ 
## outlines the data format.
## 
## **Available Functions**
##  * readQOI    -- read and decode a QOI file
##  * decodeQOI  -- decode the raw bytes of a QOI image from memory
##  * writeQOI   -- encode and write a QOI file
##  * encodeQOI  -- encode an rgba buffer into a QOI image in memory
## 
## **QOI Format Specification**
## 
## A QOI file has a 14 byte `header<#Header>`_, followed by any number of data "chunks" and an
## 8-byte `end<#QOI_END>`_ marker. Images are encoded row by row, left to right, top to bottom. 
## The decoder and encoder start with ``{r:0, g:0, b:0, a:255}`` as the previous pixel value.
## An image is complete when all pixels specified by ``width * height`` have been covered.
## 
## Pixels are encoded as:
##  * a run of the previous pixel
##  * an index into an array of previously seen pixels
##  * a difference to the previous pixel value in r,g,b
##  * full r,g,b or r,g,b,a values
## 
## The color channels are assumed to not be premultiplied with the alpha channel
## ("un-premultiplied alpha").
## 
## A running ``array[64]`` (zero-initialized) of previously seen pixel values is
## maintained by the encoder and decoder. Each pixel that is seen by the encoder
## and decoder is put into this array at the position formed by a hash function of
## the color value. In the encoder, if the pixel value at the index matches the
## current pixel, this index position is written to the stream as QOI_OP_INDEX.
## The hash function for the index is:
## 
## .. code-block::
## 	 index_position = (r * 3 + g * 5 + b * 7 + a * 11) % 64
## 
## Each chunk starts with a 2-bit or 8-bit tag, followed by a number of data bits. The
## bit length of chunks is divisible by 8 - i.e. all chunks are byte aligned. All
## values encoded in these data bits have the most significant bit on the left.
## 
## The 8-bit tags have precedence over the 2-bit tags. A decoder must check for the
## presence of an 8-bit tag first.
## 
## The byte stream's end is marked with 7 0x00 bytes followed a single 0x01 byte.
## 
## The possible chunks are:
## 
## ``QOI_OP_INDEX``:
##  * ``Byte[0]``
## 
##    - ``bits[6..7]``  2-bit tag b00
##    - ``bits[0..5]``  6-bit index into the color index array: 0..63
## 
##  * A valid encoder must not issue 2 or more consecutive QOI_OP_INDEX chunks to the
##    same index. QOI_OP_RUN should be used instead.
##
## ``QOI_OP_DIFF``:
##  * ``Byte[0]``
## 
##    - ``bits[6..7]``  2-bit tag b01
##    - ``bits[4..5]``  red channel difference from the previous pixel between -2..1
##    - ``bits[2..3]``  green channel difference from the previous pixel between -2..1
##    - ``bits[0..1]``  blue channel difference from the previous pixel between -2..1
## 
##  - The difference to the current channel values are using a wraparound operation,
##    so "1 - 2" will result in 255, while "255 + 1" will result in 0.
## 
##  - Values are stored as unsigned integers with a bias of 2. E.g. -2 is stored as
##    0 (b00). 1 is stored as 3 (b11). 
## 
##  - The alpha value remains unchanged from the previous pixel.
#
## 
## ``QOI_OP_LUMA``:
##  * ``Byte[0]``
## 
##    - ``bits[6..7]``  2-bit tag b10
##    - ``bits[0..5]``  6-bit green channel difference from the previous pixel -32..31
## 
##  * ``Byte[1]``
## 
##    - ``bits[4..7]``  4-bit red channel difference minus green channel difference -8..7
##    - ``bits[0..3]``  4-bit blue channel difference minus green channel difference -8..7
## 
##  * The green channel is used to indicate the general direction of change and is
##    encoded in 6 bits. The red and blue channels (dr and db) base their diffs off
##    of the green channel difference and are encoded in 4 bits. I.e.:
##    
##    - ``dr_dg = (cur_px.r - prev_px.r) - (cur_px.g - prev_px.g)``
##    - ``db_dg = (cur_px.b - prev_px.b) - (cur_px.g - prev_px.g)``
## 
##  * The difference to the current channel values are using a wraparound operation,
##    so "10 - 13" will result in 253, while "250 + 7" will result in 1.
## 
##  * Values are stored as unsigned integers with a bias of 32 for the green channel
##    and a bias of 8 for the red and blue channel.
## 
##  * The alpha value remains unchanged from the previous pixel.
##
## ``QOI_OP_RUN``:
##  * ``Byte[0]``
## 
##    - ``bits[6..7]``  2-bit tag b11
##    - ``bits[0..5]``  6-bit run-length repeating the previous pixel: 1..62
## 
##  * The run-length is stored with a bias of -1. Note that the run-lengths 63 and 64
##    (b111110 and b111111) are illegal as they are occupied by the QOI_OP_RGB and
##    QOI_OP_RGBA tags.
##
## ``QOI_OP_RGB``:
##  * ``Byte[0]``
## 
##    - ``bits[0..7]``  8-bit tag b11111110
## 
##  * ``Byte[1]``
##    - ``bits[0..7]``  8-bit red channel value
##
##  * ``Byte[2]``
##    - ``bits[0..7]``  8-bit green channel value
##
##  * ``Byte[3]``
##    - ``bits[0..7]``  8-bit blue channel value
## 
##  * The alpha value remains unchanged from the previous pixel.
##
## 
## ``QOI_OP_RGBA``:
##  * ``Byte[0]``
## 
##    - ``bits[0..7]``  8-bit tag b11111110
## 
##  * ``Byte[1]``
##    - ``bits[0..7]``  8-bit red channel value
##
##  * ``Byte[2]``
##    - ``bits[0..7]``  8-bit green channel value
##
##  * ``Byte[3]``
##    - ``bits[0..7]``  8-bit blue channel value
##
##  * ``Byte[4]``
##    - ``bits[0..7]``  8-bit alpha channel value 
## 
## 
## 


import std/[bitops] # Standard Libary import
import binstreams # Nimble Library import
export binstreams # export binstream/results so API is available library users

type
  Channels* = enum
    ## The channel byte in the QOI file header is an enum where:
    ##  * 3 = RGB
    ##  * 4 = RGBA
    RGB = 3, RGBA = 4

  Colorspace* = enum
    ## The colorspace byte in the QOI file header is an enum where:
    ##	* 0 = sRGB, i.e. gamma scaled RGB channels and a linear alpha channel
    ##	* 1 = all channels are linear
    ## The colorspace is purely
    ## informative. It will be saved to the file header, but does not affect
    ## how chunks are encoded/decoded.
    sRGB = 0, linear = 1

  Header* = object
    ## A QOI file has a 14 byte header, whose fields are defined as follows:
    ##  * magic       [char, 4] - magic bytes "qoif" (not stored in the data object but checked 
    ##    when decoding a data stream) 
    ##  * width       [uint32]  - image width in pixels (BE)
    ##  * height      [uint32]  - image height in pixels (BE)
    ##  * channels    [byte]    - 3 = RGB, 4 = RGBA
    ##  * colorspace  [byte]    - 0 = sRGB with linear alpha, 1 = all channels linear
    width*: uint32
    height*: uint32
    channels*: Channels
    colorspace*: Colorspace

  Pixel = object
    ## The QOI encoder/decoder tends to work with RGBA data, where the A channel is ignored for RGB images.
    r: byte
    g: byte
    b: byte
    a: byte
    
  QOIF* = object
    ## The object that stores QOI image data for use in programs.
    header*: Header
    data*: seq[byte]


const
  QOI_MAGIC = ['q', 'o', 'i', 'f']

  QOI_2BIT_MASK       = 0b11000000.byte
  QOI_RUN_TAG_MASK    = 0b11000000.byte
  QOI_INDEX_TAG_MASK  = 0b00000000.byte
  QOI_DIFF_TAG_MASK   = 0b01000000.byte
  QOI_LUMA_TAG_MASK   = 0b10000000.byte
  
  QOI_RGB_TAG         = 0b11111110.byte
  QOI_RGBA_TAG        = 0b11111111.byte

  QOI_RUN_VAL_MASK    = 0b00111111.byte
  QOI_INDEX_VAL_MASK  = 0b00111111.byte
  
  QOI_2BIT_LOWER_MASK = 0b00000011.byte
  QOI_LUMA_DG_MASK    = 0b00111111.byte
  QOI_4BIT_LOWER_MASK = 0b00001111.byte


  QOI_END = [0.byte, 0.byte, 0.byte, 0.byte, 0.byte, 0.byte, 0.byte, 1.byte]


func init(w, h: uint32; channels: Channels, colorspace: Colorspace): Header =
  ## Creates a new Header object using the provided variables
  
  result.width = w
  result.height = h
  result.channels = channels
  result.colorspace = colorspace


func hash(pixel: Pixel): byte =
  ## Purpose:
  ##    The hash function as defined by the QOI specification for the QOI_OP_INDEX
  ##    encoding/decoding. Each pixel that is seen by the encoder and decoder is 
  ##    put into an array[64] of seen Pixels at the position formed by a hash function 
  ##    of the color value. The purpose of the hash function is to reduce overlap 
  ##    between different pixel values.
  ## Inputs:
  ##    pixel: Pixel - an RGBA pixel
  ## Side-Effects:
  ##   None
  ## Returns:
  ##    byte - an index position from which to the pixel representation belongs.
  return (pixel.r * 3 + pixel.g * 5 + pixel.b * 7 + pixel.a * 11) mod 64


func isEqual(p1, p2: Pixel): bool =
  ## Purpose:
  ##    Checks if each channel of two pixels are equal to each other,
  ##    returning a true/false value
  ## Inputs:
  ##    p1: Pixel - An RGBA pixel
  ##    p2: Pixel - An RGBA pixel 
  ## Side-Effects:
  ##   None
  ## Returns:
  ##    true if the pixels are the same, otherwise false
  
  if p1.r == p2.r and
    p1.g == p2.g and
    p1.b == p2.b and
    p1.a == p2.a:
    return true
  else:
    return false


func getDiff(p1, p2: Pixel): Pixel =
  ## Purpose:
  ##    Returns a pixel which is the differnce between each channel
  ##    of P1 and P2. Note that wrapping must occur if subtraction results
  ##    in a negative value. This is inherit in the byte data type.
  ## Inputs:
  ##    p1: Pixel - An RGBA pixel
  ##    p2: Pixel - An RGBA pixel to be subtracted from p1
  ## Side-Effects:
  ##   None
  ## Returns:
  ##    a Pixel containing the RGBA values (if RGB, A = B)
  
  result.r = p1.r - p2.r
  result.g = p1.g - p2.g
  result.b = p1.b - p2.b
  result.a = p1.a - p2.a


func getPixel(stream: MemStream, channels: Channels): Pixel =
  ## Purpose:
  ##    Reads either 3 or 4 bytes from the raw RGB or RGBA input memory stream
  ## Inputs:
  ##    stream: MemStream - a Memstream object to read data from
  ##    channels: Channels - RGB (3) or RGBA (4)
  ## Side-Effects:
  ##   Changes the read position of the 'stream' MemStream
  ## Returns:
  ##    a Pixel containing the RGBA values (if RGB, A = B)
  
  result.r = stream.read(byte)
  result.g = stream.read(byte)
  result.b = stream.read(byte)

  if channels == RGBA:
    result.a = stream.read(byte)
  else:
    result.a = result.b


proc opRun(output: MemStream, runs: var byte, index, lastPixel: int) =
  ## Purpose:
  ##    Writes a single byte representing a count of the number of times a run of the previous 
  ##    pixel has been seen. e.g. Six green RGB pixels in a row in the datastream will be output
  ##    one 4 byte opRGB value, followed by a 1-byte opRun byte whose value is 5. Also includes
  ##    a 2-bit tag at the top  of the byte. 
  ## Inputs:
  ##    output: MemStream - a Memstream object to write compressed data to
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


proc opDiff(output: MemStream, diff: Pixel, flag: var bool) =
  ## Purpose:
  ##    Writes either 1 byte representing either the difference to the previous pixel 
  ##    value in RGB, or the luminosity difference using two bytes. Includes a 2-bit 
  ##    tag value at the front, upper bits.
  ## Inputs:
  ##    output: MemStream - a Memstream object to write compressed data to
  ##    diff: Pixel - an object containing the RBGA byte values
  ##    flag: bool - informs the calling function if any data was written to the output memory
  ##                 stream, otherwise the calling function will jump to the next scenario.
  ## Side-Effects:
  ##    writes 1 or 2 bytes to the output memory stream
  ## Returns:
  ##    None

  # try opDIFF
  # note that since we are using the `byte` data type to represent each Pixel value,
  # the diff value gets wrapped. So 254..1 == -2..1
  if ((diff.r >= 254) or (diff.r <= 1)) and   # -2 <= diff.r <= 1
     ((diff.g >= 254) or (diff.g <= 1)) and   # -2 <= diff.g <= 1
     ((diff.b >= 254) or (diff.b <= 1)):      # -2 <= diff.b <= 1

    # create the OP_DIFF byte, remembering to shift the channels and bias the signed integers
    output.write(bitor(QOI_DIFF_TAG_MASK, (diff.r + 2) shl 4, (diff.g + 2) shl 2, (diff.b + 2)))
    
    flag = true
  
  # try opLUMA
  # once again we are dealing with wrapping on negative values
  elif (((diff.g >= 224) or (diff.g <= 31))) and  # -32 <= diff.g <= 31
        (((diff.r >= 248) or (diff.r <= 7))) and  # -8  <= diff.r <= 7
        (((diff.b >= 248) or (diff.b <= 7))):     # -8  <= diff.b <= 7
      
    let
      dr_dg = diff.r - diff.g
      db_dg = diff.b - diff.g

    output.write(bitor(QOI_LUMA_TAG_MASK, (diff.g + 32))) # OP_LUMA is 2 bytes, so we write two bytes
    output.write(bitor((dr_dg + 8) shl 4, (db_dg + 8)))

    flag = true

  else:
    flag = false


proc opRGB(output: MemStream, pixel: Pixel) =
  ## Purpose:
  ##    Writes 4 bytes representing an RGB image + 1 byte tag value to the output memory stream
  ## Inputs:
  ##    output: MemStream - a Memstream object to write compressed data to
  ##    pixel: Pixel - an object containing the RGB byte values
  ## Side-Effects:
  ##    writes 4 bytes to the output memory stream
  ## Returns:
  ##    None
  
  output.write(QOI_RGB_TAG)
  output.write(pixel.r)
  output.write(pixel.g)
  output.write(pixel.b)


proc opRGBA(output: MemStream, pixel: Pixel) =
  ## Purpose:
  ##    Writes 5 bytes representing an RGBA image + 1 byte tag value to the output memory stream.
  ##    Data is uncompressed.
  ## Inputs:
  ##    output: MemStream - a Memstream object to write compressed data to
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


func writeHeader(output: Memstream; header: Header) =
  ## Purpose:
  ##    Writes the standardized QOI file header information to the output memory stream
  ## Inputs:
  ##    output: MemStream - a mutable Memstream object to write header data to
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


proc writeData(output: MemStream, input: MemStream, hdr: Header) =
  ## Purpose:
  ##    Writes the compressed image data to the QOI image memory stream
  ## Inputs:
  ##    output: MemStream - a Memstream object to write compressed data to
  ##    input: MemStream - The input data stream of raw RGB/RGBA values
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
  # add the initial previous pixel to seenWindow
  seenWindow[prevPixel.hash()] = prevPixel
  
  # read each pixel in input data stream
  for i in countup(0, lastPixel, 4): # countup(start, last, increment)
    # read current pixel from data stream, accounting for 3 vs 4 channels
    let currPixel = input.getPixel(hdr.channels)
    
    if currPixel.isEqual(prevPixel): # we have a repeat pixel (a.k.a. a run)
      output.opRun(runs, i, lastPixel)
    else: # we do not have a repeat pixel
      if runs > 0: # we have been on a run that has now stopped
        output.write(bitor(QOI_RUN_TAG_MASK, (runs - 1))) # remember to bias the run value
        runs = 0
      
      # next we look for the currPixel in the seenWindow array, at hash position
      let hash = currPixel.hash()
      if currPixel.isEqual(seenWindow[hash]): # is current pixel in seenWindow?
        # Instead of writing an RGBA value in 4 bytes, we just store the index in to a previously 
        # seen value in a single byte
        output.write(bitor(QOI_INDEX_TAG_MASK, hash))
      
      else: # pixel wasn't in seenWindow
        seenWindow[hash] = currPixel # since we have seen the pixel, we now add it to the window
        
        # for each channel, get the difference (currPixel - prevPixel)
        let diffPixel = getDiff(currPixel, prevPixel)

        # We can only use opDIFF and opLUMA on a 3 channel image (or an image the is functionally 3 channels)
        if diffPixel.a == 0:
          # We use a flag value to determine if the opDiff() function has written to the output stream,
          # otherwise the RGB pixel is represented using the opRGB tag
          var diffFlag: bool
          output.opDiff(diffPixel, diffFlag)
          if not diffFlag:
            output.opRGB(currPixel) # write an opRGB chunk to output stream
        
        else: 
          output.opRGBA(currPixel) # write an opRGBA chunk to output stream

    # don't forget this  
    prevPixel = currPixel      


proc readSignature(stream: MemStream): bool =
  ## Purpose:
  ##     Reads each byte from the memory stream (up to 4 bytes) and compares
  ##     it against the constant "qoif". Returns false if the two values are
  ##     not equal. 
  ## Inputs:
  ##    stream: MemStream - 
  var val: char
  for i in QOI_MAGIC:
    val = stream.read(char)
    if i != val:
      return false
  return true


proc readData(stream: MemStream, hdr: Header): seq[byte] =
  ## Description

  let pixelCount = hdr.width.int * hdr.height.int

  var 
    pixel = Pixel(r: 0, g: 0, b: 0, a: 255)
    run = 0.byte # 0 .. 61, keeps track of the run-length of the repetitions of the previous pixel
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
      
      elif bits == QOI_RGBA_TAG:
        pixel.r = stream.read(byte)
        pixel.g = stream.read(byte)
        pixel.b = stream.read(byte)
        pixel.a = stream.read(byte)
      
      elif bitand(bits, QOI_2BIT_MASK) == QOI_INDEX_TAG_MASK:
        let index = bitand(bits, QOI_INDEX_VAL_MASK)
        pixel = seenWindow[index]
      
      elif bitand(bits, QOI_2BIT_MASK) == QOI_DIFF_TAG_MASK:  
        pixel.r += bitand((bits shr 4), QOI_2BIT_LOWER_MASK) - 2
        pixel.g += bitand((bits shr 2), QOI_2BIT_LOWER_MASK) - 2
        pixel.b += bitand((bits), QOI_2BIT_LOWER_MASK) - 2
      
      elif bitand(bits, QOI_2BIT_MASK) == QOI_LUMA_TAG_MASK:
        let 
          dg = bitand(bits, QOI_LUMA_DG_MASK) - 32
          bits2 = stream.read(byte)
          
        pixel.r += dg - 8 + bitand((bits2 shr 4), QOI_4BIT_LOWER_MASK)
        pixel.g += dg
        pixel.b += dg - 8 + bitand(bits2, QOI_4BIT_LOWER_MASK)

      elif bitand(bits, QOI_2BIT_MASK) == QOI_RUN_TAG_MASK:
        run = bitand(bits, QOI_RUN_VAL_MASK) + 1 # Remember to unbias the run value!
      
      seenWindow[pixel.hash()] = pixel
      
    result.add(pixel.r)
    result.add(pixel.g)
    result.add(pixel.b)

    if hdr.channels == RGBA:
      result.add(pixel.a)


#
# -----------------------------------------------------------------
#                   MAIN FUNCTIONS
# -----------------------------------------------------------------
#


proc decodeQOI*(stream: MemStream): QOIF =
  ## Decode the raw bytes of a QOI image from memory
  ## 
  ## The decode procedure returns a Result object, which can either return a QOI 
  ## image if no errors occured, otherwise a error enum is returned.  

  stream.setPosition(0)
  # read the file signature
  if not stream.readSignature():
    raise newException(ValueError, "Invalid File Header")

  # read header information
  let
    width = stream.read(uint32)
    height = stream.read(uint32)
    channels = cast[Channels](stream.read(byte))
    colorspace = cast[Colorspace](stream.read(byte))

    header = init(width, height, channels, colorspace)

  result.header = header

  # read data information
  result.data = stream.readData(header)

  var endMarker: seq[byte]
  for i in 0 .. 7:
    endMarker.add(stream.read(byte))
  
  if not (endMarker == QOI_END):
    raise newException(ValueError, "did not read proper end marker!")

  return result


proc encodeQOI*(header: Header, stream: MemStream): MemStream =
  ## Purpose:
  ##    Encode raw RGB or RGBA pixels into a QOI image in memory
  ## Inputs:
  ##    header: Header - The image description object (width, length, channels, colorspace)
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
  
  # reset the cursor position
  output.setPosition(0)

  return output


proc readQOI*(file: string): QOIF =
  ## Read and decode a QOI image from the file system. 
  ## 
  ## If channels is 0, the number of channels from the file header is used. If 
  ## channels is 3 or 4 the output format will be forced into this number of 
  ## channels.
  ## 

  let stream = newFileStream(file, bigEndian, fmRead)

  # covert filestream to memstream
  stream.setPosition(0)
  let memStream = newMemStream(bigEndian)
  while not stream.atEnd():
    memStream.write(stream.read(byte))
  stream.close()

  return decodeQOI(memStream)


proc writeQOI*(file: string, header: Header, stream: MemStream) =
  ## Desciption
  let outputData = encodeQOI(header, stream)
  let outputFile = newFileStream(file, bigEndian, fmWrite)
    
  for i in outputData.data:
    outputFile.write(i)
    
  outputData.close()
  outputFile.close()