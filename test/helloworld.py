
import sys
import os

# 添加父目录到 sys.path，以便导入 functions.py
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from time import sleep
import argparse

from functions import *


def parse_args():
    p = argparse.ArgumentParser(description='Test EPD functionality')
    p.add_argument('-v', '--virtual', action='store_true',
                   help='display using a Tkinter window instead of the '
                        'actual e-paper device (for testing without a '
                        'physical device)')
    p.add_argument('-r', '--rotate', default=None, choices=['CW', 'CCW', 'flip'],
                   help='run the tests with the display rotated by the specified value')
    return p.parse_args()


def main():

    args = parse_args()

    todos = []

    if not args.virtual:
        from IT8951.display import AutoEPDDisplay

        print('Initializing EPD...')

        # here, spi_hz controls the rate of data transfer to the device, so a higher
        # value means faster display refreshes. the documentation for the IT8951 device
        # says the max is 24 MHz (24000000), but my device seems to still work as high as
        # 80 MHz (80000000)
        display = AutoEPDDisplay(
            vcom=-2.36, rotate=args.rotate, spi_hz=24000000)

        print('VCOM set to', display.epd.get_vcom())

        todos += [print_system_info]

    else:
        from IT8951.display import VirtualEPDDisplay
        display = VirtualEPDDisplay(dims=(800, 600), rotate=args.rotate)

    todos += [
        clear_display,
        display_gradient,
        partial_update,
        display_image_8bpp,
    ]

    for t in todos:
        t(display)
        sleep(1)

    print('Done!')


if __name__ == '__main__':
    main()
