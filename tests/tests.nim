# nimQOI - Tests

import std/[unittest] # Standard Libary import
import ../nimQOI # Adjacent Module import


func fillRGBArray(x:int): seq[byte] =
  ## fill an array with unique RGBA values that will not encounter opDIFF or opLUMA
  if x > 5:
    raise newException(ValueError, "Test Dimensions encounter a one byte limit")
  
  let baseVal = 0
  for i in countup(1, (x * x)):
    # why the limit is 5 because max(i) = x * x, which must be < (255 / 8)
    result.add(0)                         # R
    result.add(0.byte)                    # G
    result.add((baseVal + (i * 8)).byte)  # B 
    result.add(255.byte)                  # A



func fillRunArray(x:int): seq[byte] =
  ## fill an array of identical values
  for i in countup(1, (x * x)):
        result.add(220.byte)    # R
        result.add(0.byte)  # G
        result.add(0.byte)    # B
        result.add(255.byte)  # A
  

func fillIndexArray(x:int): seq[byte] =
  ## Half the values will be unique RGBA values, the other half will be duplicates 
  ## hopefully stored in the index array
  
  if x > 6:
    raise newException(ValueError, "Test Dimensions encounter a one byte limit")
  
  let half = x div 2
  let baseVal = 0
  for i in countup(1, (x * half)):
    # why the limit is 5 because max(i) = x * x, which must be < (255 / 8)
    result.add((baseVal + (i * 8)).byte)  # R
    result.add(0.byte)                    # G
    result.add((baseVal - (i * 3)).byte)                   # B 
    result.add(255.byte)                  # A

  # Add the same values twice
  for i in countup(1, (x * half)):
    result.add((baseVal + (i * 8)).byte)  # R
    result.add(0.byte)                    # G
    result.add((baseVal - (i * 3)).byte)                    # B 
    result.add(255.byte)                  # A


func fillDiffArray(x:int): seq[byte] =
  ## For each pixel, ensure that it is only slightly different than the previous pixel
  
  if x > 11:
    raise newException(ValueError, "Test Dimensions encounter a one byte limit")

  let baseVal = 255
  for i in countup(1, (x * x)):
    #  why the limit is 11 because max(i) = x * x, which must be < (255 / 2)
    result.add(0.byte)              # R
    result.add((baseVal - (i * 2)).byte)  # G (increment i by two)
    result.add(0.byte)              # B
    result.add(255.byte)            # A


func fillLumaArray(x:int): seq[byte] =
  ## For each pixel, ensure it is slightly more different than the previous pixel
  
  if x > 7:
    raise newException(ValueError, "Test Dimensions encounter a one byte limit")

  let baseVal = 255
  for i in countup(1, (x * x)):
    #  why the limit is 11 because max(i) = x * x, which must be < (255 / 2)
    result.add(0.byte)                      # R
    result.add(0.byte)                      # G
    result.add(((baseVal - (i * 3)).byte))  # B
    result.add(255.byte)                    # A



suite "Black Box Basic Tests":

  test "Encoder, header":
    # read the first 14 bytes and the last 8 bytes of the file 
    let 
      t1c0_input_header = Header(width: 5, height: 5, channels: RGBA, colorspace: sRGB)
      t1c0_input_data = newMemStream(fillRGBArray(5), bigEndian)
      t1c0_output_qoi = encodeQOI(t1c0_input_header, t1c0_input_data)

    # check the magic bytes
    const QOI_MAGIC = ['q', 'o', 'i', 'f']
    check cast[seq[char]](t1c0_output_qoi.data[0..3]) == QOI_MAGIC

    # check the width, note that all this work is to swap the endianness of the uint32 data
    var 
      rev_width: seq[byte]
      p: int

    for i in countdown(7, 4):
      rev_width.add(t1c0_output_qoi.data[i])

    check int((cast[ptr uint32](addr rev_width[p]))[]) == 5
    
    # check the height, note that all this work is to swap the endianness of the uint32 data
    var 
      rev_height: seq[byte]
      q: int

    for i in countdown(11, 8):
      rev_height.add(t1c0_output_qoi.data[i])
    check int((cast[ptr uint32](addr rev_height[q]))[]) == 5

    # check the colour channel
    check cast[Channels](t1c0_output_qoi.data[12]) == RGBA

    check cast[Colorspace](t1c0_output_qoi.data[13]) == sRGB

  test "Encoder, opRGB chunk":
    let 
      t1c1_input_header = Header(width: 5, height: 5, channels: RGBA, colorspace: sRGB)
      t1c1_input_data = newMemStream(fillRGBArray(5), bigEndian)
      t1c1_output_qoi = encodeQOI(t1c1_input_header, t1c1_input_data)
      t1c1_refernce_qoi = newFileStream("tests/images/t1c1_ref.qoi", bigEndian, fmRead)

    for i in t1c1_output_qoi.data:
      require i == t1c1_refernce_qoi.read(byte)
  
  test "Encoder, opRUN chunk":
    let 
      t1c2_input_header = Header(width: 5, height: 5, channels: RGBA, colorspace: sRGB)
      t1c2_input_data = newMemStream(fillRunArray(5), bigEndian)
      t1c2_output_qoi = encodeQOI(t1c2_input_header, t1c2_input_data)
      t1c2_refernce_qoi = newFileStream("tests/images/t1c2_ref.qoi", bigEndian, fmRead)

    for i in t1c2_output_qoi.data:
      check i == t1c2_refernce_qoi.read(byte)
  
  test "Encoder, opINDEX chunk":
    let 
      t1c3_input_header = Header(width: 6, height: 6, channels: RGBA, colorspace: sRGB)
      t1c3_input_data = newMemStream(fillIndexArray(6), bigEndian)
      t1c3_output_qoi = encodeQOI(t1c3_input_header, t1c3_input_data)
      t1c3_refernce_qoi = newFileStream("tests/images/t1c3_ref.qoi", bigEndian, fmRead)

    for i in t1c3_output_qoi.data:
      check i == t1c3_refernce_qoi.read(byte)  
  
  test "Encoder, opDIFF chunk":
    let 
      t1c4_input_header = Header(width: 6, height: 6, channels: RGBA, colorspace: sRGB)
      t1c4_input_data = newMemStream(fillDiffArray(6), bigEndian)
      t1c4_output_qoi = encodeQOI(t1c4_input_header, t1c4_input_data)
      t1c4_refernce_qoi = newFileStream("tests/images/t1c4_ref.qoi", bigEndian, fmRead)

    for i in t1c4_output_qoi.data:
      check i == t1c4_refernce_qoi.read(byte)
  
  test "Encoder, opLUMA chunk":
    let 
      t1c5_input_header = Header(width: 6, height: 6, channels: RGBA, colorspace: sRGB)
      t1c5_input_data = newMemStream(fillLumaArray(6), bigEndian)
      t1c5_output_qoi = encodeQOI(t1c5_input_header, t1c5_input_data)
      t1c5_refernce_qoi = newFileStream("tests/images/t1c5_ref.qoi", bigEndian, fmRead)

    for i in t1c5_output_qoi.data:
      check i == t1c5_refernce_qoi.read(byte) 
  
  test "Decoder, header":
    let t1c6_decoded = readQOI("tests/images/t1c1_ref.qoi")

    check t1c6_decoded.header.width == 5
    check t1c6_decoded.header.height == 5
    check t1c6_decoded.header.channels == RGBA
    check t1c6_decoded.header.colorspace == sRGB
  
  test "Decoder, opRGB chunk":
    let t1c7_decoded = readQOI("tests/images/t1c1_ref.qoi")
    check t1c7_decoded.data == fillRGBArray(5) 
  
  test "Decoder, opRUN chunk":
    let t1c8_decoded = readQOI("tests/images/t1c2_ref.qoi")
    check t1c8_decoded.data == fillRunArray(5)
  
  test "Decoder, opINDEX chunk":
    let t1c9_decoded = readQOI("tests/images/t1c3_ref.qoi")
    check t1c9_decoded.data == fillIndexArray(6)
  
  test "Decoder, opDIFF chunk":
    let t1c10_decoded = readQOI("tests/images/t1c4_ref.qoi")
    check t1c10_decoded.data == fillDiffArray(6)
  
  test "Decoder, opLUIMA chunk":
    let t1c11_decoded = readQOI("tests/images/t1c5_ref.qoi")
    check t1c11_decoded.data == fillLumaArray(6)


