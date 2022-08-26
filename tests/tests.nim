# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import unittest

import nimQOI
import nimQOI/[encode]
import binstreams

suite "nimQOI Encoder":

  test "Test 1: uniform green square (100px, 100px)":
    func fillTestArray(): seq[byte] =
      for i in countup(1, 10_000):
        result.add(0.byte)
        result.add(190.byte)
        result.add(0.byte)
        result.add(255.byte)
    
    let 
      inputHeader = Header(width: 100, height: 100, channels: RGBA, colorspace: sRGB)
      inputData = newMemStream(fillTestArray(), bigEndian)
    
    let outputData = encode(inputHeader, inputData)
    var outputFile = newFileStream("out.qoi", bigEndian, fmWrite)
    
    for i in outputData.data:
      outputFile.write(i)
    
    outputData.close()
    outputFile.close()

