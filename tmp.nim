while idx < stream.data.len():
    # is the byte representing a full 8 bit tag of RGB?
    if stream.data[idx] == QOI_RGB_TAG:
      prevPixel = getPixel(stream, RGB)
      result.writePixel(prevPixel, channel)
      seenWindow[prevPixel.hash()] = prevPixel
      idx += 4 # increment over tag byte + RGB bytes
      

    # is the byte representing a full 8 bit tag of RGBA?
    elif stream.data[idx] == QOI_RGBA_TAG:
      prevPixel = getPixel(stream, RGBA)
      result.writePixel(prevPixel, channel)
      seenWindow[prevPixel.hash()] = prevPixel
      idx += 5 # increment over tag byte + RGB bytes
    
    # now we need to read the byte so we can read the 2-bit tag
    else:
      var chunk = stream.data[idx]; inc idx
      
      if chunk.testBit(7) and chunk.testBit(6): # is this a run byte?
        # read the bottom 6 bits and cast to int so I can make sense of it
        let runLength = bitand(chunk, QOI_RUN_VAL_MASK) + 1 # remember to bias by one
        for i in 0.byte ..< runLength:
          result.writePixel(prevPixel, channel)

      elif chunk.testBit(7) and (not chunk.testBit(6)): # is this luma byte[0]?
        let dg = bitand(chunk, QOI_LUMA_DIFF_GREEN_MASK) + 32
        chunk = stream.data[idx]; inc idx
        let
          dr_dg = bitand(chunk, QOI_LUMA_DR_DG_MASK) + 8
          db_dg = bitand(chunk, QOI_LUMA_DB_DG_MASK) + 8
          dr = dr_dg + dg
          db = db_dg + dg
        
        prevPixel.r = (prevPixel.r + dr) mod 64
        prevPixel.g = (prevPixel.g + dg) mod 64
        prevPixel.b = (prevPixel.b + db) mod 64

      
      elif (not chunk.testBit(7)) and chunk.testBit(6): # is this a diff byte?
        let
          dr = bitand(chunk, 0x30) + 2.byte
          dg = bitand(chunk, 0x0c) + 2.byte
          db = bitand(chunk, 0x03) + 2.byte
        
        prevPixel.r = (prevPixel.r + dr) mod 64
        prevPixel.g = (prevPixel.g + dg) mod 64
        prevPixel.b = (prevPixel.b + db) mod 64

        seenWindow[prevPixel.hash()] = prevPixel
        result.writePixel(prevPixel, channel)

      
      else: # its GOTTA be a index byte?
        let index = bitand(chunk, QOI_INDEX_VAL_MASK)
        result.writePixel(seenWindow[index], channel)