#!/bin/bash

# Build the project
echo "Building spendo..."
dune build

# Copy the binary to a location in PATH
echo "Installing spendo..."
sudo cp _build/default/bin/spendo.exe /usr/local/bin/spendo

echo "Installation complete! You can now use 'spendo' from anywhere."
echo ""
echo "Usage examples:"
echo "  spendo 25.4"
echo "  spendo 25.4 -m \"food\""
echo "  spendo -l" 