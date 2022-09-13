import nimQOI/[encode, decode, common]
import binstreams

proc writeQoiFile*(file: string, header: Header, stream: MemStream) =
  ## Desciption
  let outputData = encode(header, stream)
  var outputFile = newFileStream(file, bigEndian, fmWrite)
    
  for i in outputData.data:
    outputFile.write(i)
    
  outputData.close()
  outputFile.close()


proc readQoiFile(file: string): QoiFile =
  ## Description
  ##
  
  var stream = newFileStream(file, bigEndian, fmRead)
  result = decode(stream)
  stream.close()
  

