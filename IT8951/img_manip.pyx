# cython: language_level=3
# cython: profile=True

'''
This file contains functions for efficiently manipulating image data, in ways that
aren't directly achievable in Python with Pillow.
'''

cimport cython
from libc.string cimport memcpy

@cython.boundscheck(False)
def make_changes_bw(prev_frame, new_frame):
    '''
    Take any pixels that have changed and map them from grayscale to black/white.
    '''

    if prev_frame.size != new_frame.size:
        raise ValueError('dimensions of images do not match')

    if any(x.mode != "L" for x in (prev_frame, new_frame)):
        raise ValueError('image mode must be "L"')

    # Get image data as bytes
    cdef const unsigned char [:] prev_buf = prev_frame.tobytes()

    # For new_frame, we need to modify it, so get a mutable copy
    new_data = bytearray(new_frame.tobytes())
    cdef unsigned char [:] new_buf = new_data

    cdef int i
    for i in range(len(prev_buf)):
        if prev_buf[i] != new_buf[i]:
            new_buf[i] = 0xF0 if new_buf[i] > 0xB0 else 0x00

    # Put modified data back into the image
    new_frame.frombytes(bytes(new_data))
