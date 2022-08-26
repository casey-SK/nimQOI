import nimQOI/[encode]
import binstreams

proc writeQoiFile*(file: string, header: Header, stream: MemStream) =
  ## Desciption
  let outputData = encode(header, stream)
  var outputFile = newFileStream(file, bigEndian, fmWrite)
    
  for i in outputData.data:
    outputFile.write(i)
    
  outputData.close()
  outputFile.close()
