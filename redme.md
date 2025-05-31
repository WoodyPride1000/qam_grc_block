# QAM Mapper GNU Radio Block

This repository contains a custom QAM Mapper GNU Radio block implemented as an Embedded Python Block in a `.grc` file.

## Features

- Supports 64-QAM and 128-QAM constellation generation
- Gray mapping enable/disable option
- Constellation points are normalized to unit average power
- Parameters configurable from GNU Radio Companion GUI

## Usage

1. Open `qam_mapper.grc` in GNU Radio Companion.
2. Configure parameters like QAM size and Gray mapping.
3. Connect inputs and outputs as needed.

## Structure

- `qam_mapper.grc`: The GRC file with the embedded Python block code.
- `utils.py`: Utility Python module for constellation generation (imported by embedded block).

## License

MIT License
