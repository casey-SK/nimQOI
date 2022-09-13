## nimQOI - common QOI types, constants, and functions for encoding/decoding

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

  Pixel* = object
    r*: byte
    g*: byte
    b*: byte
    a*: byte
    
  QoiFile* = object
    header*: Header
    data*: seq[byte]


const
  QOI_MAGIC* = ['q', 'o', 'i', 'f']
  QOI_HEADER_SIZE* = 14

  QOI_2BIT_MASK*      = 0b11000000.byte
  QOI_RUN_TAG_MASK*   = 0b11000000.byte
  QOI_INDEX_TAG_MASK* = 0b00000000.byte
  QOI_DIFF_TAG_MASK*  = 0b01000000.byte
  QOI_LUMA_TAG_MASK*  = 0b10000000.byte
  
  QOI_RGB_TAG*        = 0b11111110.byte
  QOI_RGBA_TAG*       = 0b11111111.byte

  QOI_RUN_VAL_MASK*   = 0b00111111.byte
  QOI_INDEX_VAL_MASK* = 0b00111111.byte
  
  QOI_LUMA_DIFF_GREEN_MASK* = 0b00111111.byte
  QOI_LUMA_DR_DG_MASK* = 0b11110000.byte
  QOI_LUMA_DB_DG_MASK* = 0b00001111.byte


  QOI_END* = [0.byte, 0.byte, 0.byte, 0.byte, 0.byte, 0.byte, 0.byte, 1.byte]
  QOI_END_SIZE* = 8


func init*(w, h: uint32; channels: Channels, colorspace: Colorspace): Header =
  result.width = w
  result.height = h
  result.channels = channels
  result.colorspace = colorspace


func set*(r, g, b, a: byte): Pixel = 
  result.r = r
  result.g = g
  result.b = b
  result.a = a


func init*(header: Header, data: seq[byte]): QoiFile =
  result.header = header
  result.data = data

func hash*(pixel: Pixel): byte =
  return (pixel.r * 3 + pixel.g * 5 + pixel.b * 7 + pixel.a * 11) mod 64