# nimQOI Test Suite

nimQOI tests are broken up into 4 Suites:
  1. Black Box Basic Tests
  2. Grey Box Advanced Tests
  3. Edge Case Testing
  4. Reference Image Matching


## Black Box Basic Tests

There is an encoding test and decoding test, but 8 checks are made in each test:
  - Checks `1 .. 4` : Checks the image `header` data (with different combinations of input values) 
    as well as the image `end` marker. The image data itself is not looked at in any way. 
  - Check `5` : Checks an image where only the `opRGB` chunk type is used.
  - Check `6` : Checks an image where only the `opRGBA` chunk type is used.
  - Check `7` : Checks an image where the first chunk is an `opRGBA` type, and all other chunks are an `opRUN` type
  - Check `8` : Checks an image where the first chunk is an `opRGBA` type, and all other chunks are an `opINDEX` type
  - Check `9` : Checks an image where the first chunk is an `opRGBA` type, and all other chunks are an `opDIFF` type
  - Check `10` : Checks an image where the first chunk is an `opRGBA` type, and all other chunks are an `opLUMA` type


## Grey Box Advanced Tests

The purpose of these tests is to cover all possible permutations of the chunk type ordering within a QOI file.
This is to ensure there is no logical errors in the main `for` loop that writes/reads the image data. I call it
grey box because I am aware of this loop mechanism, but I did not seek to cover each possible path through the code.

To try all possible permutations of chunk types, it might be helpful to look at just one first:

| `QOI HEADER` | `opRGBA` | `opRUN` | `opRGBA` | `opINDEX` | `opRGBA` | `opDIFF` | `opRGBA` | `opLUMA` |

Note that a file must always start with a QOI HEADER and `opRGB`/`opRGBA` chunk. So if we consider `opRGB`/`opRGBA`
to be the same, and ignore them for determining possible permutations, we have 4 chunk types that we do not wish
to repeat, so we have 4! (factorial) cases to cover, which is 24. But perhaps we want to cover all 24 cases for both
RGB and RGBA inputs, making 48 test cases. As well, our tests to cover the cases where perhaps an `opRGB`/`opRGBA`
is the last chunk type in the file. So we will add (2 * 4) more test cases manually to cover that as well. Bringing
the total number of Grey Box checks to 56. This is done for both encoding and decoding.


## Edge Case Testing

There are subtleties in the QOI specification the needs to be addressed on a case-by-case basis. These tests
belong in this test suite. Some of the immediate checks include:
  - A blank image where each pixel is as follows: `{r: 0, g: 0, b: 0, a: 255}`
  - An image where at least the first 64 pixels are blank, and then at some point a single pixel is different,
    and then all proceeding pixels are blank again. Checks that the `seenWindow` works correctly
  - An image that checks that 2 or more consecutive `opINDEX` chunks are not issued to the same index, that
    `opRUN` is used instead.
  - more to follow?


## Reference Image Matching

The order of operations for using provided reference images for testing is as follows:

**Test 1:** PNG -> RAW -> QOI
  - Tests the nimQOI encoding functions
  - for each image, does the PNG_TO_QOI image match the REF_QOI image?

**Test 2:** QOI -> RAW
  - Tests the nimQOI decoding functions
  - for each image, does the QOI_TO_RAW image match the PNG_TO_RAW image?

**Test 3:** PNG -> RAW -> QOI -> RAW -> PNG
  - Tests both the nimQOI encoding/decoding functions
  - for each image, does the PNG image match the PNG image?

