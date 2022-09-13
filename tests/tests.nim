# nimQOI - Tests

import std/[unittest] # Standard Libary import
import binstreams # Nimble Library import
import nimQOI/[encode, decode, common] # Adjacent Module import

suite "nimQOI Encoder":

  test "Test 1: uniform green square (100px, 100px)":
    func fillTestArray(x:int): seq[byte] =
      for i in countup(1, (x * x)):
        result.add(0.byte)
        result.add(190.byte)
        result.add(0.byte)
        result.add(255.byte)
    
    let 
      inputHeader = Header(width: 10, height: 10, channels: RGBA, colorspace: sRGB)
      inputData = newMemStream(fillTestArray(10), bigEndian)
    
    let outputData = encode(inputHeader, inputData)
    var 
      rawRGB = newFileStream("raw.bin", bigEndian, fmWrite)
      outputFile = newFileStream("out.qoi", bigEndian, fmWrite)
      decoded = newFileStream("decoded.bin", littleEndian, fmWrite)
    
    for i in fillTestArray(10):
      rawRGB.write(i)

    for i in outputData.data:
      outputFile.write(i)

    outputData.close()
    outputFile.close()

    var inputFile = newFileStream("out.qoi", bigEndian, fmRead)
    let decodedQoi = decode(inputFile)

    #echo decodedQoi.header.width
    #echo decodedQoi.header.height
    #echo decodedQoi.header.colorspace
    #echo decodedQoi.header.channels
    for i in decodedQoi.data:
      decoded.write(i)
    
    
    decoded.close()
    inputFile.close()

    #var 
    #  check1 = newFileStream("raw.bin", bigEndian, fmRead)
    #  check2 = newFileStream("decoded.bin", bigEndian, fmRead)
    #
    #while not check1.atEnd():
    #  check check1.read(byte) == check2.read(byte)

